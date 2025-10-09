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

    public let databaseDir: URL
    public let databaseLocation: URL

    private let migrations: [DBMigration] = [
        MigrationV0ToV1(),
    ]

    init() throws {
        databaseDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Objects.db")
        databaseLocation = databaseDir
            .appendingPathComponent("database")
            .appendingPathExtension("db")
        db = Database(at: databaseLocation.path)

        db.setAutoBackup(enable: true)
        db.setAutoMigration(enable: true)
        db.enableAutoCompression(true)

        print("[*] database location: \(databaseLocation)")

        checkMigration()

        try setup(db: db)
    }

    func setup(db: Database) throws {
        var version = try currentVersion()
        while let migration = migrations.first(where: { $0.fromVersion == version }) {
            try migration.migrate(db: db)
            version = migration.toVersion
        }
    }

    public func reset() {
        try? db.run { handler in
            try handler.drop(table: CloudModel.table)
            try handler.drop(table: Attachment.table)
            try handler.drop(table: Message.table)
            try handler.drop(table: Conversation.table)
            try handler.drop(table: ModelContextServer.table)
            try handler.drop(table: Memory.table)
            return ()
        }
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
        // 初始化版本
        let initVersion: DBVersion = .Version0

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
