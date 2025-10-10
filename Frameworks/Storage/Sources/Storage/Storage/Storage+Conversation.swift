//
//  Storage+Conversation.swift
//  Storage
//
//  Created by 秋星桥 on 1/31/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    func conversationList() -> [Conversation] {
        (
            try? db.getObjects(
                fromTable: Conversation.table,
                where: Conversation.Properties.removed == false,
                orderBy: [
                    Conversation.Properties.creation
                        .order(.descending),
                ]
            )
        ) ?? []
    }

    func conversationListAllIdentifiers() -> Set<Conversation.ID> {
        let identifiers = try? db.getColumn(
            on: Conversation.Properties.objectId,
            fromTable: Conversation.table,
            where: Conversation.Properties.removed == false
        )
        let items = identifiers?.map(\.stringValue) ?? []
        return .init(items)
    }

    func conversationMake() -> Conversation {
        let object = Conversation()
        try? db.insert([object], intoTable: Conversation.table)
        return object
    }

    func conversationUpdate(object: Conversation) {
        object.markModified()
        try? db.insertOrReplace(
            [object],
            intoTable: Conversation.table
        )
    }

    func conversationWith(identifier: Conversation.ID) -> Conversation? {
        try? db.getObject(
            fromTable: Conversation.table,
            where: Conversation.Properties.objectId == identifier && Conversation.Properties.removed == false
        )
    }

    func conversationEdit(identifier: Conversation.ID, _ block: @escaping (inout Conversation) -> Void) {
        let read: Conversation? = try? db.getObject(
            fromTable: Conversation.table,
            where: Conversation.Properties.objectId == identifier && Conversation.Properties.removed == false
        )
        guard var object = read else { return }
        block(&object)
        object.markModified()
        try? db.insertOrReplace(
            [object],
            intoTable: Conversation.table
        )
    }

    func conversationRemove(conversationWith identifier: Conversation.ID) {
        guard !identifier.isEmpty else {
            return
        }

        try? db.run(transaction: { [weak self] in
            guard let self else { return }
            let messages = listMessages(within: identifier)
            let messagesIds = messages.compactMap(\.objectId)

            try attachmentsMarkDelete(messageIds: messagesIds, handle: $0)
            try messageMarkDelete(messageIds: messagesIds, handle: $0)
            try conversationMarkDelete(conversationId: identifier, handle: $0)
        })
    }

    @discardableResult
    func conversationDuplicate(identifier: Conversation.ID, customize: @escaping (Conversation) -> Void) -> Conversation.ID? {
        guard !identifier.isEmpty else {
            return nil
        }

        var ans: Conversation.ID?
        try? db.run { handler -> Bool in
            do {
                let ret = try self.executeDuplicationTransaction(
                    identifier: identifier,
                    db: handler,
                    customize: customize
                )
                ans = ret
                return true
            } catch {
                assertionFailure(error.localizedDescription)
                return false
            }
        }
        return ans
    }

    private func executeDuplicationTransaction(
        identifier: Conversation.ID,
        db: Handle,
        customize: (Conversation) -> Void
    ) throws -> Conversation.ID {
        let conv: Conversation? = try db.getObject(
            fromTable: Conversation.table,
            where: Conversation.Properties.objectId == identifier
        )
        guard let conv else { throw NSError() }

        // new objectId
        conv.objectId = UUID().uuidString
        conv.creation = .now
        conv.modified = .now

        customize(conv)
        try db.insert([conv], intoTable: Conversation.table)

        let newIdentifier = conv.objectId
        guard newIdentifier != identifier else {
            assertionFailure()
            throw NSError()
        }

        let messages: [Message] = try db.getObjects(
            fromTable: Message.table,
            where: Message.Properties.conversationId == identifier,
            orderBy: [
                Message.Properties.creation.order(.ascending),
            ]
        )

        var oldMessageIdentifierSet = Set<String>()
        for message in messages {
            let oldMessageId = message.objectId
            oldMessageIdentifierSet.insert(oldMessageId)

            // new objectId
            message.objectId = UUID().uuidString
            message.conversationId = newIdentifier

            try db.insert(message, intoTable: Message.table)
            let newMessageId = message.objectId

            var oldAttachmentIdentifierSet = Set<String>()
            let attachments: [Attachment] = try db.getObjects(
                fromTable: Attachment.table,
                where: Attachment.Properties.messageId == oldMessageId
            )
            for attachment in attachments {
                oldAttachmentIdentifierSet.insert(attachment.id)

                // new objectId
                attachment.objectId = UUID().uuidString
                attachment.messageId = message.objectId
                try db.insert(attachment, intoTable: Attachment.table)
            }
            let newAttachments: [Attachment] = try db.getObjects(
                fromTable: Attachment.table,
                where: Attachment.Properties.messageId == newMessageId
            )

            for attachment in newAttachments {
                guard !oldAttachmentIdentifierSet.contains(attachment.id) else {
                    assertionFailure()
                    throw NSError()
                }
            }
        }

        let newMessages: [Message] = try db.getObjects(
            fromTable: Message.table,
            where: Message.Properties.conversationId == newIdentifier,
            orderBy: [
                Message.Properties.creation.order(.ascending),
            ]
        )
        for message in newMessages {
            guard !oldMessageIdentifierSet.contains(message.objectId) else {
                assertionFailure()
                throw NSError()
            }
        }

        return newIdentifier
    }

    func conversationsDrop() {
        try? db.run { handle -> Bool in
            do {
                try self.executeEraseAllConversations(handle: handle)
                return true
            } catch {
                assertionFailure(error.localizedDescription)
                return false
            }
        }
    }

    func conversationMarkDelete(conversationId: Conversation.ID, handle: Handle? = nil) throws {
        guard !conversationId.isEmpty else {
            return
        }

        let update = StatementUpdate().update(table: Conversation.table)
            .set(Conversation.Properties.version)
            .to(Conversation.Properties.version + 1)
            .set(Conversation.Properties.removed)
            .to(true)
            .set(Conversation.Properties.modified)
            .to(Date.now)
            .where(Conversation.Properties.objectId == conversationId)
        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }

    func conversationMarkDelete(handle: Handle? = nil) throws {
        let update = StatementUpdate().update(table: Conversation.table)
            .set(Conversation.Properties.version)
            .to(Conversation.Properties.version + 1)
            .set(Conversation.Properties.removed)
            .to(true)
            .set(Conversation.Properties.modified)
            .to(Date.now)
            .where(Conversation.Properties.removed == false)

        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }

    private func executeEraseAllConversations(handle: Handle) throws {
        try conversationMarkDelete(handle: handle)
        try messageMarkDelete(handle: handle)
        try attachmentsMarkDelete(handle: handle)
    }
}
