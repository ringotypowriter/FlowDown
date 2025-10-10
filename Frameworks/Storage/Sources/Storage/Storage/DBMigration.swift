//
//  DBMigration.swift
//  Storage
//
//  Created by KK on 2025/10/9.
//

import Foundation
import WCDBSwift

protocol DBMigration {
    var fromVersion: DBVersion { get }
    var toVersion: DBVersion { get }
    func migrate(db: Database) throws
}

extension DBMigration {
    /// 检查迁移是否合法：不允许跨多个版本
    func validate(allowedVersions: [DBVersion]) -> Bool {
        // 1. fromVersion 和 toVersion 都必须在允许的版本范围内
        guard allowedVersions.contains(fromVersion),
              allowedVersions.contains(toVersion)
        else {
            return false
        }

        // 2. 只允许跨单个版本
        if let fromIndex = allowedVersions.firstIndex(of: fromVersion),
           let toIndex = allowedVersions.firstIndex(of: toVersion)
        {
            return (toIndex - fromIndex) == 1
        }
        return false
    }
}

struct MigrationV0ToV1: DBMigration {
    let fromVersion: DBVersion = .Version0
    let toVersion: DBVersion = .Version1

    func migrate(db: Database) throws {
        try db.run(transaction: {
            print("[*] migrate \(fromVersion) -> \(toVersion) begin")

            try $0.create(table: AttachmentV1.table, of: AttachmentV1.self)
            try $0.create(table: MessageV1.table, of: MessageV1.self)
            try $0.create(table: ConversationV1.table, of: ConversationV1.self)

            try $0.create(table: CloudModel.table, of: CloudModel.self)
            try $0.create(table: ModelContextServer.table, of: ModelContextServer.self)
            try $0.create(table: Memory.table, of: Memory.self)

            try $0.exec(StatementPragma().pragma(.userVersion).to(toVersion.rawValue))

            print("[*] migrate \(fromVersion) -> \(toVersion) end")
        })
    }
}

struct MigrationV1ToV2: DBMigration {
    let fromVersion: DBVersion = .Version1
    let toVersion: DBVersion = .Version2

    func migrate(db: Database) throws {
        try db.run(transaction: {
            print("[*] migrate \(fromVersion) -> \(toVersion) begin")
            try $0.create(table: Attachment.table, of: Attachment.self)
            try $0.create(table: Message.table, of: Message.self)
            try $0.create(table: Conversation.table, of: Conversation.self)

            // 这里需要保留，因为有可能是是首次安装或者主动清除后。会直接从当前版本开始
            try $0.create(table: CloudModel.table, of: CloudModel.self)
            try $0.create(table: ModelContextServer.table, of: ModelContextServer.self)
            try $0.create(table: Memory.table, of: Memory.self)

            // 需要按顺序迁移表数据
            let conversationsMap = try migrateConversations(handle: $0)

            if !conversationsMap.isEmpty {
                print("[*] migrate \(fromVersion) -> \(toVersion) conversations \(conversationsMap.count)")
                let messagesMap = try migrateMessages(handle: $0, conversationsMap: conversationsMap)

                if !messagesMap.isEmpty {
                    print("[*] migrate \(fromVersion) -> \(toVersion) messages \(messagesMap.count)")
                    let attachmentCount = try migrateAttachments(handle: $0, messagesMap: messagesMap)
                    print("[*] migrate \(fromVersion) -> \(toVersion) attachments \(attachmentCount)")
                }
            }

            // 不在需要了
            try $0.drop(table: AttachmentV1.table)
            try $0.drop(table: MessageV1.table)
            try $0.drop(table: ConversationV1.table)

            try $0.exec(StatementPragma().pragma(.userVersion).to(toVersion.rawValue))

            print("[*] migrate \(fromVersion) -> \(toVersion) end")
        })
    }

    private func migrateConversations(handle: Handle) throws -> [ConversationV1.ID: Conversation] {
        let hasTable = try handle.isTableExists(ConversationV1.table)
        guard hasTable else {
            return [:]
        }

        let conversations: [ConversationV1] = try handle.getObjects(fromTable: ConversationV1.table)
        guard !conversations.isEmpty else {
            return [:]
        }

        var migrateConversations: [Conversation] = []
        var migrateConversationsMap: [ConversationV1.ID: Conversation] = [:]
        for conversation in conversations {
            let update = Conversation()
            update.title = conversation.title
            update.creation = conversation.creation
            update.modified = conversation.creation
            update.icon = conversation.icon
            update.isFavorite = conversation.isFavorite
            update.shouldAutoRename = conversation.shouldAutoRename
            update.modelId = conversation.modelId

            migrateConversations.append(update)
            migrateConversationsMap[conversation.id] = update
        }
        try handle.insertOrReplace(migrateConversations, intoTable: Conversation.table)
        return migrateConversationsMap
    }

    private func migrateMessages(handle: Handle, conversationsMap: [ConversationV1.ID: Conversation]) throws -> [MessageV1.ID: Message] {
        let hasTable = try handle.isTableExists(MessageV1.table)
        guard hasTable else {
            return [:]
        }

        let messages: [MessageV1] = try handle.getObjects(fromTable: MessageV1.table)

        guard !messages.isEmpty else {
            return [:]
        }

        var migrateMessagess: [Message] = []
        var migrateMessagessMap: [MessageV1.ID: Message] = [:]

        for message in messages {
            guard let conv = conversationsMap[message.conversationId] else { continue }

            let update = Message()
            update.conversationId = conv.objectId
            update.creation = message.creation
            update.modified = message.creation
            update.role = message.role
            update.thinkingDuration = message.thinkingDuration
            update.reasoningContent = message.reasoningContent
            update.isThinkingFold = message.isThinkingFold
            update.document = message.document
            update.documentNodes = message.documentNodes
            update.webSearchStatus = message.webSearchStatus
            update.toolStatus = message.toolStatus

            migrateMessagess.append(update)
            migrateMessagessMap[message.id] = update
        }

        try handle.insertOrReplace(migrateMessagess, intoTable: Message.table)
        return migrateMessagessMap
    }

    private func migrateAttachments(handle: Handle, messagesMap: [MessageV1.ID: Message]) throws -> Int {
        let hasTable = try handle.isTableExists(AttachmentV1.table)
        guard hasTable else {
            return 0
        }

        let attachments: [AttachmentV1] = try handle.getObjects(fromTable: AttachmentV1.table)
        guard !attachments.isEmpty else {
            return 0
        }

        let groupedAttachments = Dictionary(grouping: attachments, by: { $0.messageId })
            .mapValues { $0.sorted(by: { $0.id < $1.id }) }

        var migrateAttachment: [Attachment] = []
        for (messageId, sortedAttachments) in groupedAttachments {
            guard let message = messagesMap[messageId] else { continue }

            var createat = message.creation
            for attachment in sortedAttachments {
                let update = Attachment()
                update.messageId = message.objectId
                update.creation = createat
                update.modified = createat
                update.data = attachment.data
                update.previewImageData = attachment.previewImageData
                update.imageRepresentation = attachment.imageRepresentation
                update.representedDocument = attachment.representedDocument
                update.type = attachment.type
                update.name = attachment.name

                migrateAttachment.append(update)
                createat.addTimeInterval(0.1)
            }
        }

        guard !migrateAttachment.isEmpty else {
            return 0
        }

        try handle.insertOrReplace(migrateAttachment, intoTable: Attachment.table)

        return migrateAttachment.count
    }
}
