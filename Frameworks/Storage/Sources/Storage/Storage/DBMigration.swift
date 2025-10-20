//
//  DBMigration.swift
//  Storage
//
//  Created by KK on 2025/10/9.
//

import Foundation
import OSLog
import WCDBSwift

protocol DBMigration {
    var fromVersion: DBVersion { get }
    var toVersion: DBVersion { get }
    var requiresDataMigration: Bool { get }
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
    let requiresDataMigration: Bool = false

    func migrate(db: Database) throws {
        try db.run(transaction: {
            Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) begin")

            try $0.create(table: AttachmentV1.tableName, of: AttachmentV1.self)
            try $0.create(table: MessageV1.tableName, of: MessageV1.self)
            try $0.create(table: ConversationV1.tableName, of: ConversationV1.self)

            try $0.create(table: CloudModelV1.tableName, of: CloudModelV1.self)
            try $0.create(table: ModelContextServerV1.tableName, of: ModelContextServerV1.self)
            try $0.create(table: MemoryV1.tableName, of: MemoryV1.self)

            try $0.exec(StatementPragma().pragma(.userVersion).to(toVersion.rawValue))

            Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) end")
        })
    }
}

struct MigrationV1ToV2: DBMigration {
    let fromVersion: DBVersion = .Version1
    let toVersion: DBVersion = .Version2
    let deviceId: String
    let requiresDataMigration: Bool

    func migrate(db: Database) throws {
        try db.run(transaction: {
            Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) begin")

            if requiresDataMigration {
                try performDataMigration(handle: $0)
            } else {
                try performSchemaMigration(handle: $0)
            }

            try $0.exec(StatementPragma().pragma(.userVersion).to(toVersion.rawValue))

            Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) end")
        })
    }

    private func performSchemaMigration(handle: Handle) throws {
        try handle.create(table: Attachment.tableName, of: Attachment.self)
        try handle.create(table: Message.tableName, of: Message.self)
        try handle.create(table: Conversation.tableName, of: Conversation.self)

        try handle.create(table: CloudModel.tableName, of: CloudModel.self)
        try handle.create(table: ModelContextServer.tableName, of: ModelContextServer.self)
        try handle.create(table: Memory.tableName, of: Memory.self)

        try handle.create(table: SyncMetadata.tableName, of: SyncMetadata.self)
        try handle.create(table: UploadQueue.tableName, of: UploadQueue.self)
    }

    private func performDataMigration(handle: Handle) throws {
        // 重命名旧表
        let oldTableSuffix = "_old"
        let oldTables: [TableNamed.Type] = [
            CloudModelV1.self,
            ModelContextServerV1.self,
            MemoryV1.self,
            ConversationV1.self,
            MessageV1.self,
            AttachmentV1.self,
        ]

        var tableExists: [String: String] = [:]
        for table in oldTables {
            if try handle.isTableExists(table.tableName) {
                let oldTableName = "\(table.tableName)\(oldTableSuffix)"
                let alter = StatementAlterTable().alter(table: table.tableName).rename(to: oldTableName)
                try handle.exec(alter)
                Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) rename \(table.tableName) -> \(oldTableName)")
                tableExists[table.tableName] = oldTableName
            }
        }

        // 创建新表
        try performSchemaMigration(handle: handle)

        if let oldTableName = tableExists[CloudModelV1.tableName] {
            let cloudModelCount = try migrateCloudModels(handle: handle, oldTableName: oldTableName)
            Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) cloudModels \(cloudModelCount)")
        }

        if let oldTableName = tableExists[ModelContextServerV1.tableName] {
            let modelContextServerCount = try migrateModelContextServers(handle: handle, oldTableName: oldTableName)
            Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) modelContextServers \(modelContextServerCount)")
        }

        if let oldTableName = tableExists[MemoryV1.tableName] {
            let memoryCount = try migrateMemorys(handle: handle, oldTableName: oldTableName)
            Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) memorys \(memoryCount)")
        }

        while true {
            var conversationsMap: [ConversationV1.ID: Conversation] = [:]
            var messagesMap: [MessageV1.ID: Message] = [:]

            // 迁移会话
            if let oldTableName = tableExists[ConversationV1.tableName] {
                conversationsMap = try migrateConversations(handle: handle, oldTableName: oldTableName)
                guard !conversationsMap.isEmpty else {
                    break
                }
                Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) conversations \(conversationsMap.count)")
            }

            // 迁移消息
            if let oldTableName = tableExists[MessageV1.tableName] {
                messagesMap = try migrateMessages(handle: handle, conversationsMap: conversationsMap, oldTableName: oldTableName)
                guard !messagesMap.isEmpty else {
                    break
                }
                Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) messages \(messagesMap.count)")
            }

            // 迁移附件
            if let oldTableName = tableExists[AttachmentV1.tableName] {
                let attachments = try migrateAttachments(handle: handle, messagesMap: messagesMap, oldTableName: oldTableName)
                guard !attachments.isEmpty else {
                    break
                }
                Logger.database.info("[*] migrate version \(fromVersion.rawValue) -> \(toVersion.rawValue) attachments \(attachments.count)")
            }

            break
        }

        // 删除旧表
        for (_, oldTable) in tableExists {
            try handle.drop(table: oldTable)
        }
    }

    private func migrateCloudModels(handle: Handle, oldTableName: String) throws -> Int {
        let cloudModels: [CloudModelV1] = try handle.getObjects(fromTable: oldTableName)
        guard !cloudModels.isEmpty else {
            return 0
        }

        var migrateCloudModels: [CloudModel] = []

        for cloudModel in cloudModels {
            let update = CloudModel(deviceId: deviceId)
            update.objectId = cloudModel.id
            update.model_identifier = cloudModel.model_identifier
            update.model_list_endpoint = cloudModel.model_list_endpoint
            update.creation = cloudModel.creation
            update.modified = cloudModel.creation
            update.endpoint = cloudModel.endpoint
            update.token = cloudModel.token
            update.headers = cloudModel.headers
            update.capabilities = cloudModel.capabilities
            update.context = cloudModel.context
            update.temperature_preference = cloudModel.temperature_preference
            update.temperature_override = cloudModel.temperature_override
            update.comment = cloudModel.comment

            migrateCloudModels.append(update)
        }

        guard !migrateCloudModels.isEmpty else {
            return 0
        }

        try handle.insertOrReplace(migrateCloudModels, intoTable: CloudModel.tableName)
        return migrateCloudModels.count
    }

    private func migrateModelContextServers(handle: Handle, oldTableName: String) throws -> Int {
        let mcss: [ModelContextServerV1] = try handle.getObjects(fromTable: oldTableName)
        guard !mcss.isEmpty else {
            return 0
        }

        var migrateMCSs: [ModelContextServer] = []
        for mcs in mcss {
            let update = ModelContextServer(deviceId: deviceId)
            update.objectId = mcs.id
            update.name = mcs.name
            update.comment = mcs.comment
            update.type = mcs.type
            update.endpoint = mcs.endpoint
            update.header = mcs.header
            update.timeout = mcs.timeout
            update.isEnabled = mcs.isEnabled
            update.toolsEnabled = mcs.toolsEnabled
            update.resourcesEnabled = mcs.resourcesEnabled
            update.templateEnabled = mcs.templateEnabled
            update.lastConnected = mcs.lastConnected
            update.connectionStatus = mcs.connectionStatus
            update.capabilities = mcs.capabilities

            migrateMCSs.append(update)
        }

        guard !migrateMCSs.isEmpty else {
            return 0
        }

        try handle.insertOrReplace(migrateMCSs, intoTable: ModelContextServer.tableName)
        return migrateMCSs.count
    }

    private func migrateMemorys(handle: Handle, oldTableName: String) throws -> Int {
        let memorys: [MemoryV1] = try handle.getObjects(fromTable: oldTableName)
        guard !memorys.isEmpty else {
            return 0
        }

        var migrateMemorys: [Memory] = []
        for memory in memorys {
            let update = Memory(deviceId: deviceId, content: memory.content, conversationId: memory.conversationId)
            update.objectId = memory.id
            update.creation = memory.timestamp
            update.modified = memory.timestamp

            migrateMemorys.append(update)
        }

        guard !migrateMemorys.isEmpty else {
            return 0
        }

        try handle.insertOrReplace(migrateMemorys, intoTable: Memory.tableName)
        return migrateMemorys.count
    }

    private func migrateConversations(handle: Handle, oldTableName: String) throws -> [ConversationV1.ID: Conversation] {
        let conversations: [ConversationV1] = try handle.getObjects(fromTable: oldTableName)
        guard !conversations.isEmpty else {
            return [:]
        }

        var migrateConversations: [Conversation] = []
        var migrateConversationsMap: [ConversationV1.ID: Conversation] = [:]
        for conversation in conversations {
            let update = Conversation(deviceId: deviceId)
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
        try handle.insertOrReplace(migrateConversations, intoTable: Conversation.tableName)
        return migrateConversationsMap
    }

    private func migrateMessages(handle: Handle, conversationsMap: [ConversationV1.ID: Conversation], oldTableName: String) throws -> [MessageV1.ID: Message] {
        let messages: [MessageV1] = try handle.getObjects(fromTable: oldTableName)

        guard !messages.isEmpty else {
            return [:]
        }

        var migrateMessagess: [Message] = []
        var migrateMessagessMap: [MessageV1.ID: Message] = [:]

        for message in messages {
            guard let conv = conversationsMap[message.conversationId] else { continue }

            let update = Message(deviceId: deviceId)
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

        try handle.insertOrReplace(migrateMessagess, intoTable: Message.tableName)
        return migrateMessagessMap
    }

    private func migrateAttachments(handle: Handle, messagesMap: [MessageV1.ID: Message], oldTableName: String) throws -> [Attachment] {
        let attachments: [AttachmentV1] = try handle.getObjects(fromTable: oldTableName)
        guard !attachments.isEmpty else {
            return []
        }

        let groupedAttachments = Dictionary(grouping: attachments, by: { $0.messageId })
            .mapValues { $0.sorted(by: { $0.id < $1.id }) }

        var migrateAttachment: [Attachment] = []
        for (messageId, sortedAttachments) in groupedAttachments {
            guard let message = messagesMap[messageId] else { continue }

            var createat = message.creation
            for attachment in sortedAttachments {
                let update = Attachment(deviceId: deviceId)
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
            return []
        }

        try handle.insertOrReplace(migrateAttachment, intoTable: Attachment.tableName)

        return migrateAttachment
    }
}
