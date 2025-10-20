//
//  SyncQueryable.swift
//  Storage
//
//  Created by king on 2025/10/13.
//

import Foundation
import WCDBSwift

package struct SyncQueryProperties {
    let objectId: WCDBSwift.Property
    let modified: WCDBSwift.Property
    let removed: WCDBSwift.Property

    static func objectIdColumn(for tableName: String) -> WCDBSwift.Property {
        switch tableName {
        case CloudModel.tableName:
            CloudModel.SyncQuery.objectId
        case ModelContextServer.tableName:
            ModelContextServer.SyncQuery.objectId
        case Memory.tableName:
            Memory.SyncQuery.objectId
        case Conversation.tableName:
            Conversation.SyncQuery.objectId
        case Message.tableName:
            Message.SyncQuery.objectId
        case Attachment.tableName:
            Attachment.SyncQuery.objectId
        default:
            WCDBSwift.Property(named: "objectId", with: nil)
        }
    }

    static func modifiedColumn(for tableName: String) -> WCDBSwift.Property {
        switch tableName {
        case CloudModel.tableName:
            CloudModel.SyncQuery.modified
        case ModelContextServer.tableName:
            ModelContextServer.SyncQuery.modified
        case Memory.tableName:
            Memory.SyncQuery.modified
        case Conversation.tableName:
            Conversation.SyncQuery.modified
        case Message.tableName:
            Message.SyncQuery.modified
        case Attachment.tableName:
            Attachment.SyncQuery.modified
        default:
            WCDBSwift.Property(named: "modified", with: nil)
        }
    }

    static func removedColumn(for tableName: String) -> WCDBSwift.Property {
        switch tableName {
        case CloudModel.tableName:
            CloudModel.SyncQuery.removed
        case ModelContextServer.tableName:
            ModelContextServer.SyncQuery.removed
        case Memory.tableName:
            Memory.SyncQuery.removed
        case Conversation.tableName:
            Conversation.SyncQuery.removed
        case Message.tableName:
            Message.SyncQuery.removed
        case Attachment.tableName:
            Attachment.SyncQuery.removed
        default:
            WCDBSwift.Property(named: "removed", with: nil)
        }
    }
}

package protocol SyncQueryable {
    static var SyncQuery: SyncQueryProperties { get }
}
