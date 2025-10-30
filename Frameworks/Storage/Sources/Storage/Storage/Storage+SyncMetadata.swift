//
//  Storage+SyncMetadata.swift
//  Storage
//
//  Created by king on 2025/10/17.
//

import Foundation
import WCDBSwift

package extension Storage {
    func syncMetadataUpdate(_ metadatas: [SyncMetadata], handle: Handle? = nil) throws {
        guard !metadatas.isEmpty else {
            return
        }
        if let handle {
            try handle.insertOrReplace(metadatas, intoTable: SyncMetadata.tableName)
        } else {
            try db.insertOrReplace(metadatas, intoTable: SyncMetadata.tableName)
        }
    }

    func syncMetadataRemoveAll(handle: Handle? = nil) throws {
        if let handle {
            try handle.delete(fromTable: SyncMetadata.tableName)
        } else {
            try db.delete(fromTable: SyncMetadata.tableName)
        }
    }

    func syncMetadataRemove(zoneName: String, ownerName: String, recordName: String, handle: Handle? = nil) throws {
        if let handle {
            try handle.delete(
                fromTable: SyncMetadata.tableName,
                where: SyncMetadata.Properties.recordName == recordName
                    && SyncMetadata.Properties.zoneName == zoneName
                    && SyncMetadata.Properties.ownerName == ownerName
            )
        } else {
            try db.delete(
                fromTable: SyncMetadata.tableName,
                where: SyncMetadata.Properties.recordName == recordName
                    && SyncMetadata.Properties.zoneName == zoneName
                    && SyncMetadata.Properties.ownerName == ownerName
            )
        }
    }

    func findSyncMetadata(zoneName: String, ownerName: String, recordName: String, handle: Handle? = nil) throws -> SyncMetadata? {
        let object: SyncMetadata? = if let handle {
            try handle.getObject(
                fromTable: SyncMetadata.tableName,
                where: SyncMetadata.Properties.recordName == recordName
                    && SyncMetadata.Properties.zoneName == zoneName
                    && SyncMetadata.Properties.ownerName == ownerName
            )
        } else {
            try db.getObject(
                fromTable: SyncMetadata.tableName,
                where: SyncMetadata.Properties.recordName == recordName
                    && SyncMetadata.Properties.zoneName == zoneName
                    && SyncMetadata.Properties.ownerName == ownerName
            )
        }

        return object
    }
}
