//
//  SyncEngine.swift
//  Storage
//
//  Created by king on 2025/10/14.
//

import CloudKit
import Foundation
import os.log

public final actor SyncEngine: Sendable, ObservableObject {
    public enum Mode {
        case live
        case mock
    }

    private static let zoneID: CKRecordZone.ID = .init(zoneName: "FlowDownSync", ownerName: CKCurrentUserDefaultName)
    private static let recordType: CKRecord.RecordType = "SyncObject"

    private static let SyncEngineStateKey: String = "FlowDownSyncEngineState"
    package static let CKRecordIdSeparator: String = "##"

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

    public init(storage: Storage, containerIdentifier: String, mode: Mode, automaticallySync: Bool = true) {
        guard case .live = mode else {
            let container = MockCloudContainer.createContainer(identifier: containerIdentifier)
            let privateDatabase = container.privateCloudDatabase
            self.init(storage: storage, container: container, automaticallySync: automaticallySync) { syncEngine in
                let mockSyncEngine = MockSyncEngine(database: privateDatabase, parentSyncEngine: syncEngine, state: MockSyncEngineState())
                return mockSyncEngine
            }
            return
        }

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

    package init(storage: Storage, container: any CloudContainer, automaticallySync: Bool, createSyncEngine: @escaping (SyncEngine) -> any SyncEngineProtocol) {
        self.storage = storage
        self.container = container
        self.automaticallySync = automaticallySync
        self.createSyncEngine = createSyncEngine
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
                try await syncEngine.sendChanges(CKSyncEngine.SendChangesOptions())
            }
        } catch {
            Logger.syncEngine.fault("Failed to createCustomZoneIfNeeded: \(error)")
        }
    }

    func scheduleUploadIfNeeded() async throws {
        // 查出UploadQueue 队列中的数据 构建 CKSyncEngine Changes
        guard let handle = try? storage.getHandle() else {
            return
        }

        let batchSize = 100
        while true {
            let objects = storage.pendingUploadList(batchSize: batchSize, handle: handle)
            guard !objects.isEmpty else {
                break
            }

            var pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange] = []

            /// CKSyncEngine 需要的是数据对应的ID。
            /// UploadQueue 中是记录了所有的历史操作
            /// 所以这里对于recordName 额外处理
            /// 始终按照本地的历史操作时序进行同步
            for object in objects {
                if case .delete = object.changes {
                    pendingRecordZoneChanges.append(.deleteRecord(CKRecord.ID(recordName: object.CKRecordName, zoneID: SyncEngine.zoneID)))
                } else {
                    pendingRecordZoneChanges.append(.saveRecord(CKRecord.ID(recordName: object.CKRecordName, zoneID: SyncEngine.zoneID)))
                }
            }

            if !pendingRecordZoneChanges.isEmpty {
                syncEngine.state.add(pendingRecordZoneChanges: pendingRecordZoneChanges)
                /// 更新为 uploading
                try storage.pendingUploadChangeState(by: objects.map { ($0.id, .uploading) }, handle: handle)

                try await syncEngine.sendChanges(CKSyncEngine.SendChangesOptions())
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
        for record in modifications {
            let id = record.recordID.recordName
            Logger.database.log("Received contact modification: \(record.recordID)")

            // TODO: 更新到本地
        }

        for deletion in deletions {
            Logger.database.log("Received contact deletion: \(deletion.recordID)")
            // TODO: 删除本地
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

    func handleSentRecordZoneChanges(savedRecords _: [CKRecord] = [],
                                     failedRecordSaves: [(record: CKRecord, error: CKError)] = [],
                                     deletedRecordIDs _: [CKRecord.ID] = [],
                                     failedRecordDeletes _: [CKRecord.ID: CKError] = [:],
                                     syncEngine: any SyncEngineProtocol) async
    {
        var newPendingRecordZoneChanges = [CKSyncEngine.PendingRecordZoneChange]()
        var newPendingDatabaseChanges = [CKSyncEngine.PendingDatabaseChange]()

        // TODO: 发送成功的，需要更新本地UploadQueue 状态
        //        for savedRecord in savedRecords {
        //
        //        }

        // TODO: 发送失败
        for failedRecordSave in failedRecordSaves {
            let failedRecord = failedRecordSave.record
            switch failedRecordSave.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failedRecordSave.error.serverRecord else {
                    Logger.database.error("No server record for conflict \(failedRecordSave.error)")
                    continue
                }
                // 处理冲突
                newPendingRecordZoneChanges.append(.saveRecord(failedRecord.recordID))

            case .zoneNotFound:
                let zone = CKRecordZone(zoneID: failedRecord.recordID.zoneID)
                newPendingDatabaseChanges.append(.saveZone(zone))
                newPendingRecordZoneChanges.append(.saveRecord(failedRecord.recordID))

            case .unknownItem:
                newPendingRecordZoneChanges.append(.saveRecord(failedRecord.recordID))

            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated, .operationCancelled:
                Logger.database.debug("Retryable error saving \(failedRecord.recordID): \(failedRecordSave.error)")

            default:
                Logger.database.fault("Unknown error saving record \(failedRecord.recordID): \(failedRecordSave.error)")
            }
        }

        syncEngine.state.add(pendingDatabaseChanges: newPendingDatabaseChanges)
        syncEngine.state.add(pendingRecordZoneChanges: newPendingRecordZoneChanges)
    }
}

private extension UploadQueue {
    var CKRecordName: String {
        "\(id)\(SyncEngine.CKRecordIdSeparator)\(objectId)"
    }

    static func parseCKRecordName(_ recordName: String) -> (queueId: UploadQueue.ID, objectId: String)? {
        let splits = recordName.split(separator: SyncEngine.CKRecordIdSeparator)
        guard splits.count == 2, let queueId = UploadQueue.ID(splits[0]) else {
            return nil
        }
        return (queueId, String(splits[1]))
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

        case .sentDatabaseChanges:
            break

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
        var recordsToSaveQueueIds: [(UploadQueue.ID, CKRecord.ID)] = []
        for change in changes {
            switch change {
            case let .saveRecord(recordId):
                guard let (queueId, _) = UploadQueue.parseCKRecordName(recordId.recordName) else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordId)])
                    continue
                }

                recordsToSaveQueueIds.append((queueId, recordId))
            case let .deleteRecord(recordId):
                guard let (_, objectId) = UploadQueue.parseCKRecordName(recordId.recordName) else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [.deleteRecord(recordId)])
                    continue
                }

                realRecordIDsToDelete.append(CKRecord.ID(recordName: objectId, zoneID: SyncEngine.zoneID))
            @unknown default:
                continue
            }
        }

        if recordsToSaveQueueIds.isEmpty, realRecordIDsToDelete.isEmpty {
            return nil
        }

        let objects = storage.pendingUploadList(queueIds: recordsToSaveQueueIds.map(\.0), handle: handle)

        for object in objects {
            let record = CKRecord(recordType: SyncEngine.recordType, recordID: CKRecord.ID(recordName: object.objectId, zoneID: SyncEngine.zoneID))
            recordsToSave.append(record)

            recordsToSaveQueueIds.removeAll(where: { $0.1.recordName == object.CKRecordName })
        }

        if !recordsToSaveQueueIds.isEmpty {
            syncEngine.state.remove(pendingRecordZoneChanges: recordsToSaveQueueIds.map { .saveRecord($0.1) })
        }

        if recordsToSave.isEmpty, realRecordIDsToDelete.isEmpty {
            return nil
        }

        let batch = CKSyncEngine.RecordZoneChangeBatch(recordsToSave: recordsToSave, recordIDsToDelete: realRecordIDsToDelete, atomicByZone: true)
        return batch
    }
}
