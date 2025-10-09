//
//  Storage+Message.swift
//  Storage
//
//  Created by 秋星桥 on 1/31/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    func makeMessage(with conversationID: Conversation.ID) -> Message {
        let message = Message()
        message.conversationId = conversationID
        try? db.insert([message], intoTable: Message.table)
        return message
    }

    func listMessages() -> [Message] {
        (
            try? db.getObjects(
                fromTable: Message.table,
                where: Message.Properties.removed == false,
                orderBy: [
                    Message.Properties.creation
                        .order(.ascending),
                ]
            )
        ) ?? []
    }

    func listMessages(within conv: Conversation.ID) -> [Message] {
        (
            try? db.getObjects(
                fromTable: Message.table,
                where: Message.Properties.conversationId == conv && Message.Properties.removed == false,
                orderBy: [
                    Message.Properties.creation
                        .order(.ascending),
                ]
            )
        ) ?? []
    }

    func insertOrReplace(object: Message) {
        object.markModified()
        try? db.insertOrReplace(
            [object],
            intoTable: Message.table
        )
    }

    func insertOrReplace(messages: [Message]) {
        messages.forEach { $0.markModified() }
        try? db.insertOrReplace(messages, intoTable: Message.table)
    }

    func insertOrReplace(identifier: Message.ID, _ block: @escaping (inout Message) -> Void) {
        let read: Message? = try? db.getObject(
            fromTable: Message.table,
            where: Message.Properties.objectId == identifier
        )
        guard var object = read else { return }
        block(&object)
        object.markModified()
        try? db.insertOrReplace(
            [object],
            intoTable: Message.table
        )
    }

    func conversationIdentifierLookup(identifier: Message.ID) -> Conversation.ID? {
        guard !identifier.isEmpty else {
            return nil
        }

        let message: Message? = try? db.getObject(
            fromTable: Message.table,
            where: Message.Properties.objectId == identifier && Message.Properties.removed == false
        )
        guard let identifier = message?.conversationId else {
            assertionFailure()
            return nil
        }
        return identifier
    }

    // rollback forward to delete cell kind WebSearchState and AttachmentHint
    func deleteSupplementMessage(nextTo messageIdentifier: Message.ID) {
        guard !messageIdentifier.isEmpty else {
            return
        }

        // list all messages in the same conversation
        guard let message: Message = try? db.getObject(
            fromTable: Message.table,
            where: Message.Properties.objectId == messageIdentifier
        ) else {
            assertionFailure()
            return
        }

        guard let messages: [Message] = try? db.getObjects(
            fromTable: Message.table,
            where: Message.Properties.objectId != messageIdentifier && Message.Properties.creation <= message.creation,
            orderBy: [
                Message.Properties.creation.order(.ascending),
            ]
        ), !messages.isEmpty else {
            return
        }

        let deletetMessages = messages.filter { $0.conversationId == message.conversationId && $0.role.isSupplementKind }
        guard !deletetMessages.isEmpty else {
            return
        }

        try? messageMarkDelete(messageIds: deletetMessages.compactMap(\.objectId))
    }

    func delete(messageIdentifier: Message.ID) {
        try? messageMarkDelete(messageId: messageIdentifier)
    }

    func deleteAfter(messageIdentifier: Message.ID) {
        try? messageMarkDeleteAfter(messageId: messageIdentifier)
    }

    func messageMarkDelete(messageId: Message.ID, handle: Handle? = nil) throws {
        guard !messageId.isEmpty else {
            return
        }

        let update = StatementUpdate().update(table: Message.table)
            .set(Message.Properties.version)
            .to(Message.Properties.version + 1)
            .set(Message.Properties.removed)
            .to(true)
            .set(Message.Properties.modified)
            .to(Date.now)
            .where(Message.Properties.objectId == messageId)

        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }

    func messageMarkDelete(messageIds: [Message.ID], handle: Handle? = nil) throws {
        guard !messageIds.isEmpty else {
            return
        }

        let update = StatementUpdate().update(table: Message.table)
            .set(Message.Properties.version)
            .to(Message.Properties.version + 1)
            .set(Message.Properties.removed)
            .to(true)
            .set(Message.Properties.modified)
            .to(Date.now)
            .where(Message.Properties.objectId.in(messageIds))

        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }

    func messageMarkDeleteAfter(messageId: Message.ID, handle: Handle? = nil) throws {
        guard !messageId.isEmpty else {
            return
        }

        guard let message: Message = try? db.getObject(
            fromTable: Message.table,
            where: Message.Properties.objectId == messageId
        ) else {
            assertionFailure()
            return
        }

        let update = StatementUpdate().update(table: Message.table)
            .set(Message.Properties.version)
            .to(Message.Properties.version + 1)
            .set(Message.Properties.removed)
            .to(true)
            .set(Message.Properties.modified)
            .to(Date.now)
            .where(Message.Properties.objectId != messageId &&
                Message.Properties.creation >= message.creation &&
                Message.Properties.conversationId == message.conversationId)

        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }

    func messageMarkDelete(handle: Handle? = nil) throws {
        let update = StatementUpdate().update(table: Message.table)
            .set(Message.Properties.version)
            .to(Message.Properties.version + 1)
            .set(Message.Properties.removed)
            .to(true)
            .set(Message.Properties.modified)
            .to(Date.now)
            .where(Message.Properties.removed == false)

        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }
}
