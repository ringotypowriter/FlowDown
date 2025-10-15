//
//  CKRecord+Extension.swift
//  Storage
//
//  Created by king on 2025/10/15.
//

import CloudKit

package extension CKRecord.FieldKey {
    static let sentQueueId = "sentQueueId"
    static let tableName = "tableName"
    static let payload = "payload"
}

package extension CKRecord {
    var _recordChangeTag: String? {
        get { self[#function] }
        set { self[#function] = newValue }
    }

    var sentQueueId: String? {
        get { self[.sentQueueId] as? String }
        set { self[.sentQueueId] = newValue }
    }
}

package extension UploadQueue {
    static let CKRecordIDSeparator: String = ":"

    var ckRecordID: String {
        "\(objectId)\(UploadQueue.CKRecordIDSeparator)\(tableName)"
    }

    static func parseCKRecordID(_ value: String) -> (objectId: String, tableName: String)? {
        let splits = value.split(separator: UploadQueue.CKRecordIDSeparator)
        guard splits.count == 2 else {
            return nil
        }
        return (String(splits[0]), String(splits[1]))
    }
}
