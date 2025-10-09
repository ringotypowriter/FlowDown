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
            try $0.create(table: CloudModel.table, of: CloudModel.self)
            try $0.create(table: Attachment.table, of: Attachment.self)
            try $0.create(table: Message.table, of: Message.self)
            try $0.create(table: Conversation.table, of: Conversation.self)
            try $0.create(table: ModelContextServer.table, of: ModelContextServer.self)
            try $0.create(table: Memory.table, of: Memory.self)

            try $0.exec(StatementPragma().pragma(.userVersion).to(toVersion.rawValue))
        })
    }
}
