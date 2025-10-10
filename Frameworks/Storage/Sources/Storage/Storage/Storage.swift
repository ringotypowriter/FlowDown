//
//  Storage.swift
//  Conversation
//
//  Created by 秋星桥 on 1/21/25.
//

import Foundation
import WCDBSwift

public class Storage {
    let db: Database
    let initVersion: DBVersion

    // 标记为删除的数据在多长时间后，执行物理删除， 默认为： 30天
    let deleteAfterDuration: TimeInterval = 60 * 60 * 24 * 30

    public let databaseDir: URL
    public let databaseLocation: URL

    private let migrations: [DBMigration] = [
        MigrationV0ToV1(),
        MigrationV1ToV2(),
    ]

    init() throws {
        databaseDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Objects.db")
        databaseLocation = databaseDir
            .appendingPathComponent("database")
            .appendingPathExtension("db")

        initVersion = if FileManager.default.fileExists(atPath: databaseLocation.path) {
            .Version0
        } else {
            .Version1
        }

        db = Database(at: databaseLocation.path)

        db.setAutoBackup(enable: true)
        db.setAutoMigration(enable: true)
        db.enableAutoCompression(true)

        print("[*] database location: \(databaseLocation)")

        checkMigration()

        #if DEBUG
            db.traceSQL { _, _, _, sql, _ in
                print("[sql]: \(sql)")
            }
        #endif

        try setup(db: db)
        try clearDeletedRecords(db: db)
    }

    func setup(db: Database) throws {
        var version = try currentVersion()
        while let migration = migrations.first(where: { $0.fromVersion == version }) {
            try migration.migrate(db: db)
            version = migration.toVersion
        }
    }

    public func reset() {
        // 这里不需要执行 drop 吧？
//        try? db.run { handler in
//            try handler.drop(table: CloudModel.table)
//            try handler.drop(table: Attachment.table)
//            try handler.drop(table: Message.table)
//            try handler.drop(table: Conversation.table)
//            try handler.drop(table: ModelContextServer.table)
//            try handler.drop(table: Memory.table)
//            return ()
//        }
        db.blockade()
        db.close()
        try? FileManager.default.removeItem(at: databaseDir)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }
}

private extension Storage {
    func checkMigration() {
        for migration in migrations {
            guard migration.validate(allowedVersions: DBVersion.allCases) else {
                fatalError("Invalid migration: \(migration) crosses multiple versions or uses unknown version")
            }
        }
    }

    func currentVersion() throws -> DBVersion {
        let statement = StatementPragma().pragma(.userVersion)
        let result = try db.getValue(from: statement)
        if let result {
            return DBVersion(rawValue: result.intValue) ?? initVersion
        }
        return initVersion
    }

    func setVersion(_ version: DBVersion) throws {
        let statement = StatementPragma().pragma(.userVersion).to(version.rawValue)
        try db.exec(statement)
    }

    func clearDeletedRecords(db: Database) throws {
        let deleteAt = Date.now.addingTimeInterval(-deleteAfterDuration)
        try db.delete(fromTable: Attachment.table, where: Attachment.Properties.modified <= deleteAt && Attachment.Properties.removed == true)
        try db.delete(fromTable: Message.table, where: Message.Properties.modified <= deleteAt && Message.Properties.removed == true)
        try db.delete(fromTable: Conversation.table, where: Conversation.Properties.modified <= deleteAt && Conversation.Properties.removed == true)
        try db.delete(fromTable: CloudModel.table, where: CloudModel.Properties.modified <= deleteAt && CloudModel.Properties.removed == true)
        try db.delete(fromTable: Memory.table, where: Memory.Properties.modified <= deleteAt && Memory.Properties.removed == true)
        try db.delete(fromTable: ModelContextServer.table, where: ModelContextServer.Properties.modified <= deleteAt && ModelContextServer.Properties.removed == true)
    }
}

public extension Storage {
    func exportDatabase() -> Result<URL, Error> {
        let exportDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: exportDir,
            withIntermediateDirectories: true
        )
        let exportFile = exportDir.appendingPathComponent("database.db")
        let exportDatabase = Database(at: exportFile.path)

        do {
            try setup(db: exportDatabase)

            var getError: Error?
            try exportDatabase.run { [self] expdb in
                do {
                    let mods: [CloudModel] = try db.getObjects(fromTable: CloudModel.table)
                    try expdb.insert(mods, intoTable: CloudModel.table)
                    let cons: [Conversation] = try db.getObjects(fromTable: Conversation.table)
                    try expdb.insert(cons, intoTable: Conversation.table)
                    let msgs: [Message] = try db.getObjects(fromTable: Message.table)
                    try expdb.insert(msgs, intoTable: Message.table)
                    let atts: [Attachment] = try db.getObjects(fromTable: Attachment.table)
                    try expdb.insert(atts, intoTable: Attachment.table)
                    let mems: [Memory] = try db.getObjects(fromTable: Memory.table)
                    try expdb.insert(mems, intoTable: Memory.table)
                    return true
                } catch {
                    getError = error
                    return false
                }
            }
            if let error = getError { throw error }

            let sem = DispatchSemaphore(value: 0)
            try exportDatabase.close {
                sem.signal()
            }
            sem.wait()
        } catch {
            try? FileManager.default.removeItem(at: exportDir)
            return .failure(error)
        }

        return .success(exportDir)
    }
}
