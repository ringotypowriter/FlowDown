//
//  Created by ktiays on 2025/2/24.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Foundation
import WCDBSwift

public extension Storage {
    func attachment(for messageID: String) -> [Attachment] {
        (
            try? db.getObjects(
                fromTable: Attachment.table,
                where: Attachment.Properties.messageId == messageID && Attachment.Properties.removed == false,
                orderBy: [
                    Attachment.Properties.creation
                        .order(.ascending),
                ]
            )
        ) ?? []
    }

    func attachmentMake(with messageID: String) -> Attachment {
        let attachment = Attachment()
        attachment.messageId = messageID
        try? db.insert([attachment], intoTable: Attachment.table)
        return attachment
    }

    func attachmentsUpdate(_ attachments: [Attachment]) {
        attachments.forEach { $0.markModified() }
        try? db.insertOrReplace(attachments, intoTable: Attachment.table)
    }

    func attachmentsMarkDelete(messageId: Message.ID, handle: Handle? = nil) throws {
        guard !messageId.isEmpty else {
            return
        }

        let update = StatementUpdate().update(table: Attachment.table)
            .set(Attachment.Properties.removed)
            .to(true)
            .set(Attachment.Properties.modified)
            .to(Date.now)
            .where(Attachment.Properties.messageId == messageId)

        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }

    func attachmentsMarkDelete(messageIds: [Message.ID], handle: Handle? = nil) throws {
        guard !messageIds.isEmpty else {
            return
        }

        let update = StatementUpdate().update(table: Attachment.table)
            .set(Attachment.Properties.removed)
            .to(true)
            .set(Attachment.Properties.modified)
            .to(Date.now)
            .where(Attachment.Properties.messageId.in(messageIds))

        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }

    func attachmentsMarkDelete(handle: Handle? = nil) throws {
        let update = StatementUpdate().update(table: Attachment.table)
            .set(Attachment.Properties.removed)
            .to(true)
            .set(Attachment.Properties.modified)
            .to(Date.now)
            .where(Attachment.Properties.removed == false)

        if let handle {
            try handle.exec(update)
        } else {
            try db.exec(update)
        }
    }
}
