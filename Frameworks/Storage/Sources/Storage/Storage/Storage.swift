//
//  Storage.swift
//  Conversation
//
//  Created by 秋星桥 on 1/21/25.
//

import Foundation
import OSLog
import WCDBSwift
import ZIPFoundation

public class Storage {
    private static let DeviceIDKey = "FlowdownStorageDeviceId"
    private static let SyncFirstSetupKey = "FlowdownSyncFirstSetup"

    let db: Database
    let initVersion: DBVersion
    /// 标记为删除的数据在多长时间后，执行物理删除， 默认为： 30天
    let deleteAfterDuration: TimeInterval = 60 * 60 * 24 * 30

    public let databaseDir: URL
    public let databaseLocation: URL

    /// UploadQueue enqueue 事件回调类型
    package typealias UploadQueueEnqueueHandler = (_ queues: [UploadQueue]) -> Void
    package var uploadQueueEnqueueHandler: UploadQueueEnqueueHandler?

    /// 是否已经执行过首次同步初始化
    public package(set) var hasPerformedFirstSync: Bool {
        get { UserDefaults.standard.bool(forKey: Self.SyncFirstSetupKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.SyncFirstSetupKey) }
    }

    private let existsDatabaseFile: Bool
    private let migrations: [DBMigration]
    private static var _deviceId: String?

    /// 设备ID，应用卸载重置
    public static var deviceId: String {
        if let _deviceId {
            return _deviceId
        }

        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: DeviceIDKey) {
            _deviceId = id
            return id
        }

        let id = UUID().uuidString
        defaults.set(id, forKey: DeviceIDKey)
        _deviceId = id
        return id
    }

    init() throws {
        databaseDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Objects.db")
        databaseLocation = databaseDir
            .appendingPathComponent("database")
            .appendingPathExtension("db")

        existsDatabaseFile = FileManager.default.fileExists(atPath: databaseLocation.path)

        if existsDatabaseFile {
            initVersion = .Version0
            migrations = [
                MigrationV0ToV1(),
                MigrationV1ToV2(deviceId: Storage.deviceId, requiresDataMigration: true),
            ]
        } else {
            initVersion = .Version1
            migrations = [
                MigrationV1ToV2(deviceId: Storage.deviceId, requiresDataMigration: false),
            ]
        }

        db = Database(at: databaseLocation.path)

        db.setAutoBackup(enable: true)
        db.setAutoMigration(enable: true)
        db.enableAutoCompression(true)

        // swiftformat:disable:next redundantSelf
        Logger.database.info("[*] database location: \(self.databaseLocation)")

        checkMigration()

        #if DEBUG
            db.traceSQL { _, _, _, sql, _ in
                print("[sql]: \(sql)")
            }
        #endif

        try setup(db: db)

        // 清除无效数据
        try clearDeletedRecords(db: db)

        // 将上传中/上传失败的同步记录重置为Pending
        try pendingUploadRestToPendingState()
    }

    func setup(db: Database) throws {
        var version = if existsDatabaseFile {
            try currentVersion()
        } else {
            initVersion
        }

        while let migration = migrations.first(where: { $0.fromVersion == version }) {
            try migration.migrate(db: db)
            version = migration.toVersion
        }
    }

    public func reset() {
        db.blockade()
        db.close()
        try? FileManager.default.removeItem(at: databaseDir)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    func getHandle() throws -> Handle {
        try db.getHandle()
    }

    func runTransaction(handle: Handle? = nil, _ transaction: @escaping (Handle) throws -> Void) throws {
        if let handle {
            try handle.run(transaction: transaction)
        } else {
            try db.run(transaction: transaction)
        }
    }

    /// 清除本地所有数据
    func clearLocalData(handle: Handle? = nil) throws {
        let transaction: (Handle) throws -> Void = {
            try $0.delete(fromTable: CloudModel.tableName)
            try $0.delete(fromTable: Attachment.tableName)
            try $0.delete(fromTable: Message.tableName)
            try $0.delete(fromTable: Conversation.tableName)
            try $0.delete(fromTable: ModelContextServer.tableName)
            try $0.delete(fromTable: Memory.tableName)
            try $0.delete(fromTable: SyncMetadata.tableName)
            try $0.delete(fromTable: UploadQueue.tableName)
        }

        if let handle {
            try handle.run(transaction: transaction)
        } else {
            try db.run(transaction: transaction)
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
        try? db.delete(fromTable: Attachment.tableName, where: Attachment.Properties.modified <= deleteAt && Attachment.Properties.removed == true)
        try? db.delete(fromTable: Message.tableName, where: Message.Properties.modified <= deleteAt && Message.Properties.removed == true)
        try? db.delete(fromTable: Conversation.tableName, where: Conversation.Properties.modified <= deleteAt && Conversation.Properties.removed == true)
        try? db.delete(fromTable: CloudModel.tableName, where: CloudModel.Properties.modified <= deleteAt && CloudModel.Properties.removed == true)
        try? db.delete(fromTable: Memory.tableName, where: Memory.Properties.modified <= deleteAt && Memory.Properties.removed == true)
        try? db.delete(fromTable: ModelContextServer.tableName, where: ModelContextServer.Properties.modified <= deleteAt && ModelContextServer.Properties.removed == true)

        cloudModelRemoveInvalid()

        // 上传队列
        // 1. 上传成功的
        // 2. 上传失败次数超过阈值的
        // 3. 时间太过久远的
        try? db.delete(
            fromTable: UploadQueue.tableName,
            where:
            UploadQueue.Properties.state == UploadQueue.State.finish
                || UploadQueue.Properties.failCount >= 100
                || UploadQueue.Properties.modified <= deleteAt
        )
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
                    let mods: [CloudModel] = try db.getObjects(fromTable: CloudModel.tableName)
                    try expdb.insert(mods, intoTable: CloudModel.tableName)
                    let cons: [Conversation] = try db.getObjects(fromTable: Conversation.tableName)
                    try expdb.insert(cons, intoTable: Conversation.tableName)
                    let msgs: [Message] = try db.getObjects(fromTable: Message.tableName)
                    try expdb.insert(msgs, intoTable: Message.tableName)
                    let atts: [Attachment] = try db.getObjects(fromTable: Attachment.tableName)
                    try expdb.insert(atts, intoTable: Attachment.tableName)
                    let mems: [Memory] = try db.getObjects(fromTable: Memory.tableName)
                    try expdb.insert(mems, intoTable: Memory.tableName)
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

    func importDatabase(from url: URL) -> Result<Void, Error> {
        let tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let unzipTarget = tempDir.appendingPathComponent("imported")
        var backupURL: URL?

        do {
            try FileManager.default.createDirectory(at: unzipTarget, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: url, to: unzipTarget)

            let importedDB = unzipTarget.appendingPathComponent("database.db")
            guard FileManager.default.fileExists(atPath: importedDB.path) else {
                throw NSError(domain: "Storage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing database.db in archive"])
            }

            db.blockade()
            db.close()

            let candidateBackup = databaseLocation.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: candidateBackup.path) {
                try FileManager.default.removeItem(at: candidateBackup)
            }

            if FileManager.default.fileExists(atPath: databaseLocation.path) {
                try FileManager.default.moveItem(at: databaseLocation, to: candidateBackup)
                backupURL = candidateBackup
            }

            if FileManager.default.fileExists(atPath: databaseLocation.path) {
                try FileManager.default.removeItem(at: databaseLocation)
            }

            try FileManager.default.moveItem(at: importedDB, to: databaseLocation)

            hasPerformedFirstSync = false

            if let backupURL, FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.removeItem(at: tempDir)
            return .success(())
        } catch {
            if let backupURL, FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.moveItem(at: backupURL, to: databaseLocation)
            }
            try? FileManager.default.removeItem(at: tempDir)
            return .failure(error)
        }
    }
}
