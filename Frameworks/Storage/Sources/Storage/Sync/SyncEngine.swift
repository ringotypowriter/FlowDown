//
//  SyncEngine.swift
//  Storage
//
//  Created by king on 2025/10/14.
//

import CloudKit
import Foundation
import os.log
import WCDBSwift

public final actor SyncEngine: ObservableObject {
    private static let configurationLock = NSLock()
    private static var sharedInstance: SyncEngine?

    @discardableResult
    public nonisolated static func configure(
        storage: Storage,
        containerIdentifier: String,
        automaticallySync: Bool = true
    ) -> SyncEngine {
        configurationLock.lock()
        defer { configurationLock.unlock() }

        precondition(
            sharedInstance == nil,
            "SyncEngine.configure(_) called multiple times"
        )

        let engine = SyncEngine(
            storage: storage,
            containerIdentifier: containerIdentifier,
            automaticallySync: automaticallySync
        )
        sharedInstance = engine
        Logger.syncEngine.debug(
            "Configured SyncEngine for container: \(containerIdentifier) autoSync=\(automaticallySync)"
        )
        return engine
    }

    package nonisolated static func configure(
        storage: Storage,
        container: any CloudContainer,
        automaticallySync: Bool,
        createSyncEngine: @escaping (SyncEngine) -> any SyncEngineProtocol
    ) -> SyncEngine {
        configurationLock.lock()
        defer { configurationLock.unlock() }

        precondition(
            sharedInstance == nil,
            "SyncEngine.configure(_) called multiple times"
        )

        let engine = SyncEngine(
            storage: storage,
            container: container,
            automaticallySync: automaticallySync,
            createSyncEngine: createSyncEngine
        )
        sharedInstance = engine
        Logger.syncEngine.debug(
            "Configured SyncEngine with custom container autoSync=\(automaticallySync)"
        )
        return engine
    }

    public nonisolated static var shared: SyncEngine {
        configurationLock.lock()
        defer { configurationLock.unlock() }

        guard let sharedInstance else {
            fatalError("SyncEngine shared instance is not configured. Call SyncEngine.configure first.")
        }
        return sharedInstance
    }

    package nonisolated static func resetForTesting() {
        configurationLock.lock()
        sharedInstance = nil
        configurationLock.unlock()
    }

    private static let zoneID: CKRecordZone.ID = .init(zoneName: "FlowDownSync", ownerName: CKCurrentUserDefaultName)
    private static let recordType: CKRecord.RecordType = "SyncObject"

    private static let SyncEngineStateKey: String = "FlowDownSyncEngineState"
    package static let CKRecordSentQueueIdSeparator: String = "##"

    /// The sync engine being used to sync.
    /// This is lazily initialized. You can re-initialize the sync engine by setting `_syncEngine` to nil then calling `self.syncEngine`.
    private var syncEngine: any SyncEngineProtocol {
        if _syncEngine == nil {
            initializeSyncEngine()
        }
        return _syncEngine!
    }

    private let createSyncEngine: (SyncEngine) -> any SyncEngineProtocol
    private var _syncEngine: (any SyncEngineProtocol)?

    private let storage: Storage
    package let container: any CloudContainer
    private let automaticallySync: Bool

    private var debounceEnqueueTask: Task<Void, Error>?

    private static var stateSerialization: CKSyncEngine.State.Serialization? {
        get {
            guard let data = UserDefaults.standard.data(forKey: SyncEngine.SyncEngineStateKey) else { return nil }
            do {
                let state = try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
                return state
            } catch {
                Logger.syncEngine.fault("Failed to decode CKSyncEngine state: \(error)")
                return nil
            }
        }

        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: SyncEngine.SyncEngineStateKey)
                return
            }

            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: SyncEngine.SyncEngineStateKey)
            } catch {
                Logger.syncEngine.fault("Failed to encode CKSyncEngine state: \(error)")
            }
        }
    }

    private init(storage: Storage, containerIdentifier: String, automaticallySync: Bool = true) {
        let container = CKContainer(identifier: containerIdentifier)
        self.init(
            storage: storage,
            container: container,
            automaticallySync: automaticallySync
        ) { syncEngine in
            var configuration = CKSyncEngine.Configuration(
                database: container.privateCloudDatabase,
                stateSerialization: SyncEngine.stateSerialization,
                delegate: syncEngine
            )
            configuration.automaticallySync = syncEngine.automaticallySync
            let ckSyncEngine = CKSyncEngine(configuration)
            return ckSyncEngine
        }
    }

    private init(storage: Storage, container: any CloudContainer, automaticallySync: Bool, createSyncEngine: @escaping (SyncEngine) -> any SyncEngineProtocol) {
        self.storage = storage
        self.container = container
        self.automaticallySync = automaticallySync
        self.createSyncEngine = createSyncEngine

        storage.uploadQueueEnqueueHandler = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.onUploadQueueEnqueue()
            }
        }

        Task {
            await createCustomZoneIfNeeded()
            try await scheduleUploadIfNeeded()
        }
    }
}

public extension SyncEngine {
    func start() {}
}

private extension SyncEngine {
    func initializeSyncEngine() {
        let syncEngine = createSyncEngine(self)
        _syncEngine = syncEngine
        Logger.syncEngine.log("Initialized sync engine: \(syncEngine.description)")
    }

    func createCustomZoneIfNeeded() async {
        do {
            let existingZones = try await container.privateCloudDatabase.allRecordZones()
            if existingZones.contains(where: { $0.zoneID == SyncEngine.zoneID }) {
                Logger.syncEngine.info("zone already exists")
            } else {
                let zone = CKRecordZone(zoneID: SyncEngine.zoneID)
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
                if !automaticallySync {
                    try await syncEngine.performingSendChanges()
                }
            }
        } catch {
            Logger.syncEngine.fault("Failed to createCustomZoneIfNeeded: \(error)")
        }
    }

    func onUploadQueueEnqueue() async {
        debounceEnqueueTask?.cancel()

        debounceEnqueueTask = Task { [weak self] in
            guard let self else { return }

            try await Task.sleep(nanoseconds: 5_000_000_000)

            try Task.checkCancellation()

            try await scheduleUploadIfNeeded()
        }
    }

    func scheduleUploadIfNeeded() async throws {
        try Task.checkCancellation()

        // 查出UploadQueue 队列中的数据 构建 CKSyncEngine Changes
        guard let handle = try? storage.getHandle() else {
            return
        }

        let batchSize = 100
        while true {
            try Task.checkCancellation()

            let objects = storage.pendingUploadList(batchSize: batchSize, handle: handle)
            guard !objects.isEmpty else {
                break
            }

            var pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange] = []

            let deviceId = Storage.deviceId
            /// CKSyncEngine 需要的是数据对应的ID。
            /// UploadQueue 中是记录了所有的历史操作
            /// 所以这里对于recordName 额外处理
            /// 始终按照本地的历史操作时序进行同步
            for object in objects {
                if case .delete = object.changes {
                    pendingRecordZoneChanges.append(.deleteRecord(CKRecord.ID(recordName: object.ckRecordID, zoneID: SyncEngine.zoneID)))
                } else {
                    let sentQueueId = SyncEngine.makeCKRecordSentQueueId(queueId: object.id, objectId: object.objectId, deviceId: deviceId)
                    pendingRecordZoneChanges.append(.saveRecord(CKRecord.ID(recordName: sentQueueId, zoneID: SyncEngine.zoneID)))
                }
            }

            try Task.checkCancellation()

            if !pendingRecordZoneChanges.isEmpty {
                syncEngine.state.add(pendingRecordZoneChanges: pendingRecordZoneChanges)

                if !automaticallySync {
                    try await syncEngine.performingSendChanges()
                }
            }

            if objects.count < batchSize {
                break
            }
        }
    }

    // MARK: - SyncEngine Events

    func handleAccountChange(changeType _: CKSyncEngine.Event.AccountChange.ChangeType,
                             syncEngine _: any SyncEngineProtocol) async {}

    func handleStateUpdate(
        stateSerialization: CKSyncEngine.State.Serialization,
        syncEngine _: any SyncEngineProtocol
    ) async {
        SyncEngine.stateSerialization = stateSerialization
    }

    func handleFetchedRecordZoneChanges(modifications: [CKRecord] = [],
                                        deletions: [(recordID: CKRecord.ID, recordType: CKRecord.RecordType)] = [],
                                        syncEngine _: any SyncEngineProtocol) async
    {
        guard !modifications.isEmpty || !deletions.isEmpty else {
            return
        }

        guard let handle = try? storage.getHandle() else {
            Logger.database.error("Failed to get storage handle during sync apply.")
            return
        }

        var queueCompletionKeys = Set<String>()
        var queueCompletions: [(UploadQueue.ID, String)] = []
        var queueDeletionKeys = Set<String>()
        var queueDeletionPairs: [(objectId: String, tableName: String)] = []

        do {
            try storage.runTransaction(handle: handle) { [self] transactionHandle in
                var recordsByTable: [String: [CKRecord]] = [:]
                for record in modifications {
                    guard let tableName = record[.tableName] as? String ?? UploadQueue.parseCKRecordID(record.recordID.recordName)?.tableName else {
                        Logger.database.error("Fetched record missing tableName: \(record.recordID.recordName)")
                        continue
                    }
                    recordsByTable[tableName, default: []].append(record)
                }

                for (tableName, records) in recordsByTable {
                    switch tableName {
                    case CloudModel.tableName:
                        try processFetched(records, as: CloudModel.self, tableName: tableName, handle: transactionHandle, queueCompletions: &queueCompletions, queueCompletionKeys: &queueCompletionKeys, queueDeletionPairs: &queueDeletionPairs, queueDeletionKeys: &queueDeletionKeys)
                    case ModelContextServer.tableName:
                        try processFetched(records, as: ModelContextServer.self, tableName: tableName, handle: transactionHandle, queueCompletions: &queueCompletions, queueCompletionKeys: &queueCompletionKeys, queueDeletionPairs: &queueDeletionPairs, queueDeletionKeys: &queueDeletionKeys)
                    case Conversation.tableName:
                        try processFetched(records, as: Conversation.self, tableName: tableName, handle: transactionHandle, queueCompletions: &queueCompletions, queueCompletionKeys: &queueCompletionKeys, queueDeletionPairs: &queueDeletionPairs, queueDeletionKeys: &queueDeletionKeys)
                    case Message.tableName:
                        try processFetched(records, as: Message.self, tableName: tableName, handle: transactionHandle, queueCompletions: &queueCompletions, queueCompletionKeys: &queueCompletionKeys, queueDeletionPairs: &queueDeletionPairs, queueDeletionKeys: &queueDeletionKeys)
                    case Attachment.tableName:
                        try processFetched(records, as: Attachment.self, tableName: tableName, handle: transactionHandle, queueCompletions: &queueCompletions, queueCompletionKeys: &queueCompletionKeys, queueDeletionPairs: &queueDeletionPairs, queueDeletionKeys: &queueDeletionKeys)
                    case Memory.tableName:
                        try processFetched(records, as: Memory.self, tableName: tableName, handle: transactionHandle, queueCompletions: &queueCompletions, queueCompletionKeys: &queueCompletionKeys, queueDeletionPairs: &queueDeletionPairs, queueDeletionKeys: &queueDeletionKeys)
                    default:
                        Logger.database.error("Received modification for unknown table: \(tableName)")
                    }
                }

                if !deletions.isEmpty {
                    var deletionGroups: [String: [String]] = [:]

                    for deletion in deletions where deletion.recordType == SyncEngine.recordType {
                        guard let parsed = UploadQueue.parseCKRecordID(deletion.recordID.recordName) else {
                            Logger.database.error("Unable to parse deletion recordID: \(deletion.recordID.recordName)")
                            continue
                        }

                        deletionGroups[parsed.tableName, default: []].append(parsed.objectId)

                        let key = "\(parsed.objectId)#\(parsed.tableName)"
                        if queueDeletionKeys.insert(key).inserted {
                            queueDeletionPairs.append((objectId: parsed.objectId, tableName: parsed.tableName))
                        }
                    }

                    for (tableName, objectIds) in deletionGroups {
                        do {
                            try storage.reconcileRemoteDeletions(tableName: tableName, objectIds: objectIds, handle: transactionHandle)
                        } catch {
                            Logger.database.fault("Failed to reconcile deletions for \(tableName): \(error)")
                        }
                    }
                }
            }

            if !queueCompletions.isEmpty {
                try storage.pendingUploadDequeue(by: queueCompletions, handle: handle)
            }

            if !queueDeletionPairs.isEmpty {
                try storage.pendingUploadDequeueDeleted(by: queueDeletionPairs, handle: handle)
            }
        } catch {
            Logger.database.fault("Failed to apply fetched record zone changes: \(error)")
        }
    }

    func handleFetchedDatabaseChanges(modifications _: [CKRecordZone.ID],
                                      deletions: [(zoneID: CKRecordZone.ID, reason: CKDatabase.DatabaseChange.Deletion.Reason)],
                                      syncEngine _: any SyncEngineProtocol) async
    {
        var resetLocalData = false
        for deletion in deletions {
            switch deletion.zoneID.zoneName {
            case SyncEngine.zoneID.zoneName:
                resetLocalData = true
            default:
                Logger.database.info("Received deletion for unknown zone: \(deletion.zoneID)")
            }
        }

        if resetLocalData {
            /// 当云端 Zone 被删除时，当前设备应该同步清除本地所有数据
            try? storage.clearLocalData()
        }
    }

    func handleSentDatabaseChanges(savedRecordZones: [CKRecordZone] = [],
                                   failedRecordZoneSaves _: [(zone: CKRecordZone, error: CKError)] = [],
                                   deletedRecordZoneIDs _: [CKRecordZone.ID] = [],
                                   failedRecordZoneDeletes _: [CKRecordZone.ID: CKError] = [:],
                                   syncEngine _: any SyncEngineProtocol) async
    {
        for savedRecordZone in savedRecordZones {
            Logger.syncEngine.info("savedRecordZone: \(savedRecordZone.zoneID)")
        }
    }

    func handleSentRecordZoneChanges(savedRecords: [CKRecord] = [],
                                     failedRecordSaves: [(record: CKRecord, error: CKError)] = [],
                                     deletedRecordIDs: [CKRecord.ID] = [],
                                     failedRecordDeletes _: [CKRecord.ID: CKError] = [:],
                                     syncEngine: any SyncEngineProtocol) async
    {
        guard let handle = try? storage.getHandle() else {
            return
        }

        var newPendingRecordZoneChanges = [CKSyncEngine.PendingRecordZoneChange]()
        var newPendingDatabaseChanges = [CKSyncEngine.PendingDatabaseChange]()

        let deviceId = Storage.deviceId
        // 发送成功的，需要更新本地UploadQueue 状态
        if !savedRecords.isEmpty {
            var savedLocalQueueIds: [(UploadQueue.ID, String)] = []
            for savedRecord in savedRecords {
                guard let value = savedRecord.sentQueueId, let (localQueueId, _, sentDeviceId) = SyncEngine.parseCKRecordSentQueueId(value) else { continue }
                if sentDeviceId == deviceId {
                    savedLocalQueueIds.append((localQueueId, savedRecord.recordID.recordName))
                }
            }

            Logger.syncEngine.info("Sent save success record zone: \(savedLocalQueueIds)")
            try? storage.pendingUploadDequeue(by: savedLocalQueueIds, handle: handle)
        }

        //  发送失败
        for failedRecordSave in failedRecordSaves {
            let failedRecord = failedRecordSave.record
            switch failedRecordSave.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failedRecordSave.error.serverRecord else {
                    Logger.database.error("No server record for conflict \(failedRecordSave.error)")
                    continue
                }
                // 处理冲突
//                if let sentQueueId = failedRecord.sentQueueId {
//                    newPendingRecordZoneChanges.append(.saveRecord(CKRecord.ID(recordName: sentQueueId, zoneID: failedRecord.recordID.zoneID)))
//                }

            case .zoneNotFound:
                let zone = CKRecordZone(zoneID: failedRecord.recordID.zoneID)
                newPendingDatabaseChanges.append(.saveZone(zone))
                if let sentQueueId = failedRecord.sentQueueId {
                    newPendingRecordZoneChanges.append(.saveRecord(CKRecord.ID(recordName: sentQueueId, zoneID: failedRecord.recordID.zoneID)))
                }

            case .unknownItem:
                if let sentQueueId = failedRecord.sentQueueId {
                    newPendingRecordZoneChanges.append(.saveRecord(CKRecord.ID(recordName: sentQueueId, zoneID: failedRecord.recordID.zoneID)))
                }

            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated, .operationCancelled:
                Logger.database.debug("Retryable error saving \(failedRecord.recordID): \(failedRecordSave.error)")

            default:
                Logger.database.fault("Unknown error saving record \(failedRecord.recordID): \(failedRecordSave.error)")
            }
        }

        // 删除成功的
        if !deletedRecordIDs.isEmpty {
            let deletedQueueObjectIds = deletedRecordIDs.compactMap { UploadQueue.parseCKRecordID($0.recordName) }
            Logger.syncEngine.info("Sent deleted success record zone: \(deletedQueueObjectIds)")
            try? storage.pendingUploadDequeueDeleted(by: deletedQueueObjectIds, handle: handle)
        }

        syncEngine.state.add(pendingDatabaseChanges: newPendingDatabaseChanges)
        syncEngine.state.add(pendingRecordZoneChanges: newPendingRecordZoneChanges)
    }
}

private extension SyncEngine {
    func processFetched<T: Syncable & SyncQueryable>(
        _ records: [CKRecord],
        as _: T.Type,
        tableName: String,
        handle: Handle,
        queueCompletions: inout [(UploadQueue.ID, String)],
        queueCompletionKeys: inout Set<String>,
        queueDeletionPairs: inout [(objectId: String, tableName: String)],
        queueDeletionKeys: inout Set<String>
    ) throws {
        let objects = decodeRecords(records, as: T.self, tableName: tableName, queueCompletions: &queueCompletions, queueCompletionKeys: &queueCompletionKeys)
        guard !objects.isEmpty else {
            return
        }

        let diff = try storage.applyRemoteSyncables(objects, handle: handle)

        if !diff.deleted.isEmpty {
            let deletedIds = diff.deleted.map(\.objectId)
            try storage.reconcileRemoteDeletions(tableName: tableName, objectIds: deletedIds, handle: handle)

            for objectId in deletedIds {
                let key = "\(objectId)#\(tableName)"
                if queueDeletionKeys.insert(key).inserted {
                    queueDeletionPairs.append((objectId: objectId, tableName: tableName))
                }
            }
        }
    }

    func decodeRecords<T: Syncable>(
        _ records: [CKRecord],
        as _: T.Type,
        tableName: String,
        queueCompletions: inout [(UploadQueue.ID, String)],
        queueCompletionKeys: inout Set<String>
    ) -> [T] {
        var objects: [T] = []

        for record in records {
            guard let data = payloadData(from: record) else {
                Logger.database.error("Missing payload for record \(record.recordID.recordName)")
                continue
            }

            do {
                var object = try T.decodePayload(data)
                if let parsed = UploadQueue.parseCKRecordID(record.recordID.recordName), object.objectId != parsed.objectId {
                    object.objectId = parsed.objectId
                }

                if object.deviceId.isEmpty, let creator = record.createByDeviceId {
                    object.deviceId = creator
                }

                if let modifiedDate = record.modificationDate, object.modified < modifiedDate {
                    object.modified = modifiedDate
                }

                objects.append(object)

                if let sentQueueId = record.sentQueueId,
                   let (queueId, objectId, deviceId) = SyncEngine.parseCKRecordSentQueueId(sentQueueId),
                   deviceId == Storage.deviceId
                {
                    let key = "\(queueId)#\(objectId)"
                    if queueCompletionKeys.insert(key).inserted {
                        queueCompletions.append((queueId, objectId))
                    }
                }
            } catch {
                Logger.database.error("Failed to decode payload for \(tableName): \(error)")
            }
        }

        return objects
    }

    func payloadData(from record: CKRecord) -> Data? {
        if let data = record.encryptedValues[.payload] as? Data {
            return data
        }
        if let value = record.encryptedValues[.payload],
           let data = value as? Data
        {
            return data
        }
        if let data = record[.payload] as? Data {
            return data
        }
        if let asset = record[.payload] as? CKAsset,
           let url = asset.fileURL,
           let data = try? Data(contentsOf: url)
        {
            return data
        }
        return nil
    }
}

private extension SyncEngine {
    static func makeCKRecordSentQueueId(queueId: UploadQueue.ID, objectId: String, deviceId: String) -> String {
        "\(queueId)\(SyncEngine.CKRecordSentQueueIdSeparator)\(objectId)\(SyncEngine.CKRecordSentQueueIdSeparator)\(deviceId)"
    }

    static func parseCKRecordSentQueueId(_ value: String) -> (queueId: UploadQueue.ID, objectId: String, deviceId: String)? {
        let splits = value.split(separator: SyncEngine.CKRecordSentQueueIdSeparator)
        guard splits.count == 3, let queueId = UploadQueue.ID(splits[0]) else {
            return nil
        }
        return (queueId, String(splits[1]), String(splits[2]))
    }
}

private extension UploadQueue {
    func populateRecord(_ record: CKRecord) {
        record[.tableName] = tableName
        record[.createByDeviceId] = deviceId
        // 设置无效
//        record[CKRecord.SystemFieldKey.creationDate] = creation
//        record[CKRecord.SystemFieldKey.modificationDate] = modified
        record.encryptedValues[.payload] = payload
    }
}

// MARK: - CKSyncEngineDelegate

extension SyncEngine: CKSyncEngineDelegate {
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard let event = SyncEngine.Event(event) else {
            return
        }

        await handleEvent(event, syncEngine: syncEngine)
    }

    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await nextRecordZoneChangeBatch(reason: context.reason, options: context.options, syncEngine: syncEngine)
    }

    public func nextFetchChangesOptions(_ context: CKSyncEngine.FetchChangesContext, syncEngine _: CKSyncEngine) async -> CKSyncEngine.FetchChangesOptions {
        let options = context.options
        Logger.syncEngine.info("Next fetch by reason: \(context.reason)")
        return options
    }
}

// MARK: - SyncEngineDelegate

extension SyncEngine: SyncEngineDelegate {
    package func handleEvent(_ event: SyncEngine.Event, syncEngine _: any SyncEngineProtocol) async {
        Logger.syncEngine.debug("Handling event \(event)")

        switch event {
        case let .accountChange(changeType):
            await handleAccountChange(changeType: changeType, syncEngine: syncEngine)

        case let .stateUpdate(stateSerialization):
            await handleStateUpdate(stateSerialization: stateSerialization, syncEngine: syncEngine)

        case let .fetchedDatabaseChanges(modifications, deletions):
            await handleFetchedDatabaseChanges(
                modifications: modifications,
                deletions: deletions,
                syncEngine: syncEngine
            )

        case let .sentDatabaseChanges(
            savedRecordZones,
            failedRecordZoneSaves,
            deletedRecordZoneIDs,
            failedRecordZoneDeletes
        ):
            await handleSentDatabaseChanges(
                savedRecordZones: savedRecordZones,
                failedRecordZoneSaves: failedRecordZoneSaves,
                deletedRecordZoneIDs: deletedRecordZoneIDs,
                failedRecordZoneDeletes: failedRecordZoneDeletes,
                syncEngine: syncEngine
            )

        case let .fetchedRecordZoneChanges(modifications, deletions):
            await handleFetchedRecordZoneChanges(
                modifications: modifications,
                deletions: deletions,
                syncEngine: syncEngine
            )

        case let .sentRecordZoneChanges(
            savedRecords,
            failedRecordSaves,
            deletedRecordIDs,
            failedRecordDeletes
        ):
            await handleSentRecordZoneChanges(
                savedRecords: savedRecords,
                failedRecordSaves: failedRecordSaves,
                deletedRecordIDs: deletedRecordIDs,
                failedRecordDeletes: failedRecordDeletes,
                syncEngine: syncEngine
            )

        case .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges, .didFetchChanges, .willSendChanges, .didSendChanges:
            break

        @unknown default:
            Logger.syncEngine.info("Received unknown event: \(event)")
        }
    }

    package func nextRecordZoneChangeBatch(
        reason: CKSyncEngine.SyncReason,
        options: CKSyncEngine.SendChangesOptions,
        syncEngine: any SyncEngineProtocol
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        Logger.syncEngine.info("Next push by reason: \(reason)")
        guard let handle = try? storage.getHandle() else {
            return nil
        }

        let scope = options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }

        // 根据changes 的 CKRecord.ID 从 UploadQueue 中取出数据
        var recordsToSave: [CKRecord] = []
        var realRecordIDsToDelete: [CKRecord.ID] = []
        var recordsToSaveQueueIds: [(queueId: UploadQueue.ID, recordId: CKRecord.ID)] = []
        for change in changes {
            switch change {
            case let .saveRecord(recordId):
                guard let (queueId, _, _) = SyncEngine.parseCKRecordSentQueueId(recordId.recordName) else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordId)])
                    continue
                }

                recordsToSaveQueueIds.append((queueId, recordId))
            case let .deleteRecord(recordId):
                realRecordIDsToDelete.append(recordId)
            @unknown default:
                continue
            }
        }

        if recordsToSaveQueueIds.isEmpty, realRecordIDsToDelete.isEmpty {
            return nil
        }

        let objects = storage.pendingUploadList(queueIds: recordsToSaveQueueIds.map(\.0), handle: handle)

        let deviceId = Storage.deviceId
        for object in objects {
            let record = CKRecord(recordType: SyncEngine.recordType, recordID: CKRecord.ID(recordName: object.ckRecordID, zoneID: SyncEngine.zoneID))
            let sentQueueId = SyncEngine.makeCKRecordSentQueueId(queueId: object.id, objectId: object.objectId, deviceId: deviceId)
            record.sentQueueId = sentQueueId
            record.lastModifiedByDeviceId = deviceId
            object.populateRecord(record)
            recordsToSave.append(record)

            recordsToSaveQueueIds.removeAll(where: { $0.1.recordName == SyncEngine.makeCKRecordSentQueueId(queueId: object.id, objectId: object.objectId, deviceId: deviceId) })
        }

        /// 更新为 uploading
        try? storage.pendingUploadChangeState(by: objects.map { ($0.id, .uploading) }, handle: handle)

        if !recordsToSaveQueueIds.isEmpty {
            // 对于本地找不到的数据，从SyncEngine 中删除
            syncEngine.state.remove(pendingRecordZoneChanges: recordsToSaveQueueIds.map { .saveRecord($0.recordId) })
        }

        if recordsToSave.isEmpty, realRecordIDsToDelete.isEmpty {
            return nil
        }

        let batch = CKSyncEngine.RecordZoneChangeBatch(recordsToSave: recordsToSave, recordIDsToDelete: realRecordIDsToDelete, atomicByZone: true)
        return batch
    }

    package func nextFetchChangesOptions(
        reason: CKSyncEngine.SyncReason,
        options _: CKSyncEngine.FetchChangesOptions,
        syncEngine _: any SyncEngineProtocol
    ) async -> CKSyncEngine.FetchChangesOptions {
        Logger.syncEngine.info("Next fetch by reason: \(reason)")
        let options = CKSyncEngine.FetchChangesOptions()
        return options
    }
}
