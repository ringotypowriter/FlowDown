//
//  SyncEngine.swift
//  Storage
//
//  Created by king on 2025/10/14.
//

import CloudKit
import Foundation
import os.log

public final class ConversationNotificationInfo: Sendable {
    public let modifications: [Conversation.ID]
    public let deletions: [Conversation.ID]
    public var isEmpty: Bool {
        modifications.isEmpty && deletions.isEmpty
    }

    public init(modifications: [Conversation.ID], deletions: [Conversation.ID]) {
        self.modifications = modifications
        self.deletions = deletions
    }
}

public final class CloudModelNotificationInfo: Sendable {
    public let modifications: [CloudModel.ID]
    public let deletions: [CloudModel.ID]
    public var isEmpty: Bool {
        modifications.isEmpty && deletions.isEmpty
    }

    public init(modifications: [CloudModel.ID], deletions: [CloudModel.ID]) {
        self.modifications = modifications
        self.deletions = deletions
    }
}

public final class MessageNotificationInfo: Sendable {
    public let modifications: [Conversation.ID: [Message.ID]]
    public let deletions: [Conversation.ID: [Message.ID]]
    public var isEmpty: Bool {
        modifications.isEmpty && deletions.isEmpty
    }

    public init(modifications: [Conversation.ID: [Message.ID]], deletions: [Conversation.ID: [Message.ID]]) {
        self.modifications = modifications
        self.deletions = deletions
    }
}

public final actor SyncEngine: Sendable, ObservableObject {
    public static let ConversationChanged: Notification.Name = .init("wiki.qaq.flowdown.SyncEngine.ConversationChanged")
    public static let MessageChanged: Notification.Name = .init("wiki.qaq.flowdown.SyncEngine.MessageChanged")
    public static let CloudModelChanged: Notification.Name = .init("wiki.qaq.flowdown.SyncEngine.CloudModelChanged")
    public static let LocalDataDeleted: Notification.Name = .init("wiki.qaq.flowdown.SyncEngine.LocalDataDeleted")
    public static let ServerDataDeleted: Notification.Name = .init("wiki.qaq.flowdown.SyncEngine.ServerDataDeleted")
    public static let ConversationNotificationKey: String = " Conversation"
    public static let MessageNotificationKey: String = " Conversation"
    public static let CloudModelNotificationKey: String = " CloudModel"

    public nonisolated static let syncEnabledDefaultsKey = "com.flowdown.storage.sync.manually.enabled"

    public nonisolated static var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: syncEnabledDefaultsKey)
    }

    public nonisolated static func setSyncEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: syncEnabledDefaultsKey)
    }

    public nonisolated static func resetCachedState() {
        stateSerialization = nil
    }

    public enum Mode {
        case live
        case mock
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
                UserDefaults.standard.synchronize()
                return
            }

            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: SyncEngine.SyncEngineStateKey)
                UserDefaults.standard.synchronize()
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
                let mockSyncEngine = MockSyncEngine(database: privateDatabase, parentSyncEngine: syncEngine, state: MockSyncEngineState(), delegate: syncEngine)
                mockSyncEngine.automaticallySync = syncEngine.automaticallySync
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

        storage.uploadQueueEnqueueHandler = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.onUploadQueueEnqueue()
            }
        }

        Task {
            await createCustomZoneIfNeeded()
        }
    }
}

public extension SyncEngine {
    /// 停止同步
    func stopSyncIfNeeded() async throws {
        if _syncEngine == nil {
            return
        }

        await syncEngine.cancelOperations()
        _syncEngine = nil
        Logger.syncEngine.info("stopSyncIfNeeded")
    }

    /// 恢复同步
    func resumeSyncIfNeeded() async throws {
        Logger.syncEngine.info("resumeSyncIfNeeded")
        try await fetchChanges()
    }

    /// 拉取变化
    func fetchChanges() async throws {
        guard SyncEngine.isSyncEnabled else { return }

        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else { return }

        var needDelay = false
        if _syncEngine == nil {
            initializeSyncEngine()
            needDelay = true
        }
        Logger.syncEngine.info("fetchChanges")
        if needDelay {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        try await syncEngine.performingFetchChanges()
    }

    /// 删除本地数据
    /// - Parameter resetSyncEngine: 是否需要重置同步引擎
    func deleteLocalData(_ resetSyncEngine: Bool = true) async throws {
        Logger.syncEngine.info("deleting local data")

        try storage.clearLocalData()

        if resetSyncEngine {
            SyncEngine.stateSerialization = nil
            initializeSyncEngine()
        }

        await MainActor.run {
            NotificationCenter.default.post(
                name: SyncEngine.LocalDataDeleted,
                object: nil
            )
        }
    }

    /// 删除云端数据
    func deleteServerData() async throws {
        var needDelay = false
        if _syncEngine == nil {
            initializeSyncEngine()
            needDelay = true
        }

        Logger.syncEngine.info("deleting server data")
        if needDelay {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        syncEngine.state.add(pendingDatabaseChanges: [.deleteZone(SyncEngine.zoneID)])
        try await syncEngine.performingSendChanges()
    }

    /// 强制重新从云端获取
    func reloadDataForcefully() async throws {
        guard SyncEngine.isSyncEnabled else { return }

        Logger.syncEngine.info("reload data force fully")
        SyncEngine.stateSerialization = nil
        initializeSyncEngine()
        try await syncEngine.performingFetchChanges()
    }
}

private extension SyncEngine {
    func initializeSyncEngine() {
        let syncEngine = createSyncEngine(self)
        _syncEngine = syncEngine
        Logger.syncEngine.log("Initialized sync engine: \(syncEngine.description)")
    }

    /// 创建CKRecordZone
    /// - Parameter immediateSendChanges: 是否立即发送变化，仅在 automaticallySync = false 有效
    func createCustomZoneIfNeeded(_ immediateSendChanges: Bool = false) async {
        guard SyncEngine.isSyncEnabled else { return }
        do {
            let existingZones = try await container.privateCloudDatabase.allRecordZones()
            if existingZones.contains(where: { $0.zoneID == SyncEngine.zoneID }) {
                Logger.syncEngine.info("zone already exists")
            } else {
                let zone = CKRecordZone(zoneID: SyncEngine.zoneID)
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
                if !automaticallySync, immediateSendChanges {
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

            try await Task.sleep(nanoseconds: 1_000_000_000)

            try Task.checkCancellation()

            try await scheduleUploadIfNeeded()
        }
    }

    /// 调度上传队列
    /// - Parameter immediateSendChanges: 是否立即发送变化，仅在 automaticallySync = false 有效
    func scheduleUploadIfNeeded(_ immediateSendChanges: Bool = false) async throws {
        try Task.checkCancellation()

        guard SyncEngine.isSyncEnabled else { return }

        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else { return }

        // 查出UploadQueue 队列中的数据 构建 CKSyncEngine Changes
        // 每次最多发送100条
        let batchSize = 100
        let objects = storage.pendingUploadList(batchSize: batchSize)
        guard !objects.isEmpty else {
            return
        }

        if _syncEngine == nil {
            return
        }

        var pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange] = []

        let deviceId = Storage.deviceId
        /// CKSyncEngine 需要的是数据对应的ID。
        /// UploadQueue 中是记录了所有的历史操作
        /// 所以这里对于recordName 额外处理
        for object in objects {
            if case .delete = object.changes {
                pendingRecordZoneChanges.append(.deleteRecord(CKRecord.ID(recordName: object.ckRecordID, zoneID: SyncEngine.zoneID)))
            } else {
                let sentQueueId = SyncEngine.makeCKRecordSentQueueId(queueId: object.id, objectId: object.objectId, deviceId: deviceId)
                pendingRecordZoneChanges.append(.saveRecord(CKRecord.ID(recordName: sentQueueId, zoneID: SyncEngine.zoneID)))
            }
        }

        try Task.checkCancellation()

        if _syncEngine == nil {
            return
        }

        if !pendingRecordZoneChanges.isEmpty {
            syncEngine.state.add(pendingRecordZoneChanges: pendingRecordZoneChanges)

            if !automaticallySync, immediateSendChanges {
                try await syncEngine.performingSendChanges()
            }
        }
    }

    // MARK: - SyncEngine Events

    func handleAccountChange(
        changeType: CKSyncEngine.Event.AccountChange.ChangeType,
        syncEngine _: any SyncEngineProtocol
    ) async {
        let shouldDeleteLocalData: Bool
        let shouldReUploadLocalData: Bool

        switch changeType {
        case .signIn:
            shouldDeleteLocalData = false
            shouldReUploadLocalData = true

        case .switchAccounts:
            shouldDeleteLocalData = true
            shouldReUploadLocalData = false

        case .signOut:
            shouldDeleteLocalData = true
            shouldReUploadLocalData = false

        @unknown default:
            Logger.syncEngine.log("Unknown account change type: \(type(of: changeType))")
            shouldDeleteLocalData = false
            shouldReUploadLocalData = false
        }

        if shouldDeleteLocalData {
            try? await deleteLocalData()
        }

        if shouldReUploadLocalData {
            await createCustomZoneIfNeeded()
        }
    }

    func handleStateUpdate(
        stateSerialization: CKSyncEngine.State.Serialization,
        syncEngine _: any SyncEngineProtocol
    ) async {
        SyncEngine.stateSerialization = stateSerialization
    }

    func handleFetchedDatabaseChanges(
        modifications: [CKRecordZone.ID],
        deletions: [(zoneID: CKRecordZone.ID, reason: CKDatabase.DatabaseChange.Deletion.Reason)],
        syncEngine _: any SyncEngineProtocol
    ) async {
        Logger.syncEngine.log("Received DatabaseChanges modifications: \(modifications.count) deletions: \(deletions.count)")

        var resetLocalData = false
        for deletion in deletions {
            switch deletion.zoneID.zoneName {
            case SyncEngine.zoneID.zoneName:
                resetLocalData = true
                Logger.syncEngine.info("Received deletion zone \(deletion.zoneID)")
            default:
                Logger.syncEngine.info("Received deletion for unknown zone: \(deletion.zoneID)")
            }
        }

        if resetLocalData {
            /// 当云端 Zone 被删除时，当前设备应该同步清除本地所有数据
            try? await deleteLocalData(false)
        }
    }

    func handleFetchedRecordZoneChanges(
        modifications: [CKRecord] = [],
        deletions: [(recordID: CKRecord.ID, recordType: CKRecord.RecordType)] = [],
        syncEngine _: any SyncEngineProtocol
    ) async {
        Logger.syncEngine.log("Received RecordZoneChanges modifications: \(modifications.count) deletions: \(deletions.count)")

        do {
            try storage.handleRemoteUpsert(modifications: modifications)
        } catch {
            Logger.syncEngine.error("handleRemoteUpsert error \(error)")
        }

        do {
            try storage.handleRemoteDeleted(deletions: deletions)
        } catch {
            Logger.syncEngine.error("handleRemoteDeleted error \(error)")
        }

        // 收集变化
        var modificationConversations: [Conversation.ID] = []
        var modificationMessages: [Message.ID] = []
        var modificationCloudModels: [CloudModel.ID] = []

        for modification in modifications {
            let recordID = modification.recordID
            guard let (objectId, tableName) = UploadQueue.parseCKRecordID(recordID.recordName) else { continue }
            if tableName == Conversation.tableName {
                modificationConversations.append(objectId)
            } else if tableName == Message.tableName {
                modificationMessages.append(objectId)
            } else if tableName == CloudModel.tableName {
                modificationCloudModels.append(objectId)
            }
        }

        var deletedConversations: [Conversation.ID] = []
        var deletedMessages: [Message.ID] = []
        var deletedCloudModels: [CloudModel.ID] = []
        for deletion in deletions {
            let recordID = deletion.recordID
            guard let (objectId, tableName) = UploadQueue.parseCKRecordID(recordID.recordName) else { continue }
            if tableName == Conversation.tableName {
                deletedConversations.append(objectId)
            } else if tableName == Message.tableName {
                deletedMessages.append(objectId)
            } else if tableName == CloudModel.tableName {
                deletedCloudModels.append(objectId)
            }
        }

        var modificationMessageMap: [Conversation.ID: [Message.ID]] = [:]
        var deletionMessageMap: [Conversation.ID: [Message.ID]] = [:]
        if !modificationMessages.isEmpty {
            modificationMessageMap = storage.conversationIds(by: modificationMessages)
        }

        if !deletedMessages.isEmpty {
            deletionMessageMap = storage.conversationIds(by: deletedMessages)
        }

        let conversationNotificationInfo = ConversationNotificationInfo(modifications: modificationConversations, deletions: deletedConversations)
        let messageNotificationInfo = MessageNotificationInfo(modifications: modificationMessageMap, deletions: deletionMessageMap)
        let cloudModelNotificationInfo = CloudModelNotificationInfo(modifications: modificationCloudModels, deletions: deletedCloudModels)
        await MainActor.run {
            if !conversationNotificationInfo.isEmpty {
                NotificationCenter.default.post(
                    name: SyncEngine.ConversationChanged,
                    object: nil,
                    userInfo: [
                        SyncEngine.ConversationNotificationKey: conversationNotificationInfo,
                    ]
                )
            }

            if !messageNotificationInfo.isEmpty {
                NotificationCenter.default.post(
                    name: SyncEngine.MessageChanged,
                    object: nil,
                    userInfo: [
                        SyncEngine.MessageNotificationKey: messageNotificationInfo,
                    ]
                )
            }

            if !cloudModelNotificationInfo.isEmpty {
                NotificationCenter.default.post(
                    name: SyncEngine.CloudModelChanged,
                    object: nil,
                    userInfo: [
                        SyncEngine.CloudModelNotificationKey: cloudModelNotificationInfo,
                    ]
                )
            }
        }
    }

    func handleSentDatabaseChanges(
        savedRecordZones: [CKRecordZone] = [],
        failedRecordZoneSaves: [(zone: CKRecordZone, error: CKError)] = [],
        deletedRecordZoneIDs: [CKRecordZone.ID] = [],
        failedRecordZoneDeletes: [CKRecordZone.ID: CKError] = [:],
        syncEngine _: any SyncEngineProtocol
    ) async {
        for savedRecordZone in savedRecordZones {
            Logger.syncEngine.info("savedRecordZone: \(savedRecordZone.zoneID)")
        }

        for (zoneId, error) in failedRecordZoneSaves {
            Logger.syncEngine.error("failedRecordZoneSave: \(zoneId) \(error)")
        }

        for deletedRecordZoneId in deletedRecordZoneIDs {
            Logger.syncEngine.info("deletedRecordZone: \(deletedRecordZoneId)")
            if deletedRecordZoneId == SyncEngine.zoneID {
                // 云端删除zone成功后，需要将本地保存的云端记录元数据删除
                try? storage.syncMetadataRemoveAll()

                await MainActor.run {
                    NotificationCenter.default.post(
                        name: SyncEngine.ServerDataDeleted,
                        object: nil
                    )
                }
            }
        }

        for (zoneId, error) in failedRecordZoneDeletes {
            Logger.syncEngine.error("failedRecordZoneDelete: \(zoneId) \(error)")
        }
    }

    func handleSentRecordZoneChanges(
        savedRecords: [CKRecord] = [],
        failedRecordSaves: [(record: CKRecord, error: CKError)] = [],
        deletedRecordIDs: [CKRecord.ID] = [],
        failedRecordDeletes: [CKRecord.ID: CKError] = [:],
        syncEngine: any SyncEngineProtocol
    ) async {
        var newPendingDatabaseChanges = [CKSyncEngine.PendingDatabaseChange]()
        var removePendingRecordZoneChanges = [CKSyncEngine.PendingRecordZoneChange]()
        let deviceId = Storage.deviceId
        // 发送成功的，需要更新本地UploadQueue 状态
        if !savedRecords.isEmpty {
            var savedLocalQueueIds: [(queueId: UploadQueue.ID, objectId: String, tableName: String)] = []
            var metadatas: [SyncMetadata] = []
            for savedRecord in savedRecords {
                guard let (_, tableName) = UploadQueue.parseCKRecordID(savedRecord.recordID.recordName) else { continue }
                guard let value = savedRecord.sentQueueId, let (localQueueId, objectId, sentDeviceId) = SyncEngine.parseCKRecordSentQueueId(value) else { continue }
                if sentDeviceId == deviceId {
                    savedLocalQueueIds.append((localQueueId, objectId, tableName))
                    metadatas.append(SyncMetadata(record: savedRecord))
                }
            }

            Logger.syncEngine.info("Sent save success record zone: \(savedLocalQueueIds)")
            try? storage.runTransaction {
                try self.storage.syncMetadataUpdate(metadatas, handle: $0)
                try self.storage.pendingUploadDequeue(by: savedLocalQueueIds, handle: $0)
            }
        }

        var pendingUploadChangeStates: [(queueId: UploadQueue.ID, state: UploadQueue.State)] = []

        //  发送失败
        for failedRecordSave in failedRecordSaves {
            let failedRecord = failedRecordSave.record
            switch failedRecordSave.error.code {
            case .serverRecordChanged:
                removePendingRecordZoneChanges.append(.saveRecord(failedRecord.recordID))

                guard let sentQueueId = failedRecord.sentQueueId, let (localQueueId, _, _) = SyncEngine.parseCKRecordSentQueueId(sentQueueId) else { continue }

                guard let serverRecord = failedRecordSave.error.serverRecord else {
                    Logger.syncEngine.error("No server record for conflict \(failedRecordSave.error)")

                    pendingUploadChangeStates.append((localQueueId, .failed))
                    continue
                }

                // 处理冲突
                try? storage.syncMetadataUpdate([SyncMetadata(record: serverRecord)])
                pendingUploadChangeStates.append((localQueueId, .pending))

            case .zoneNotFound:
                let zone = CKRecordZone(zoneID: failedRecord.recordID.zoneID)
                if failedRecordSave.error.userInfo[CKErrorUserDidResetEncryptedDataKey] != nil {
                    // CloudKit is unable to decrypt previously encrypted data. This occurs when a user
                    // resets their iCloud Keychain and thus deletes the key material previously used
                    // to encrypt and decrypt their encrypted fields stored via CloudKit.
                    // In this case, it is recommended to delete the associated zone and re-upload any
                    // locally cached data, which will be encrypted with the new key.

                    newPendingDatabaseChanges.append(.deleteZone(zone.zoneID))
                } else {
                    newPendingDatabaseChanges.append(.saveZone(zone))
                }

                guard let sentQueueId = failedRecord.sentQueueId, let (localQueueId, _, _) = SyncEngine.parseCKRecordSentQueueId(sentQueueId) else { continue }
                pendingUploadChangeStates.append((localQueueId, .pending))

            case .unknownItem:
                // 删除本地记录的云端记录
                let recordID = failedRecord.recordID
                let zoneID = recordID.zoneID
                try? storage.syncMetadataRemove(zoneName: zoneID.zoneName, ownerName: zoneID.ownerName, recordName: recordID.recordName)

                removePendingRecordZoneChanges.append(.saveRecord(recordID))

                guard let sentQueueId = failedRecord.sentQueueId, let (localQueueId, _, _) = SyncEngine.parseCKRecordSentQueueId(sentQueueId) else { continue }
                pendingUploadChangeStates.append((localQueueId, .failed))

            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated, .operationCancelled:
                // 可重试错误也直接从state中删除，由后续的调度策略再次自动加入
                removePendingRecordZoneChanges.append(.saveRecord(failedRecord.recordID))
                Logger.syncEngine.debug("Retryable error saving \(failedRecord.recordID): \(failedRecordSave.error)")

                guard let sentQueueId = failedRecord.sentQueueId, let (localQueueId, _, _) = SyncEngine.parseCKRecordSentQueueId(sentQueueId) else { continue }
                pendingUploadChangeStates.append((localQueueId, .pending))

            default:
                removePendingRecordZoneChanges.append(.saveRecord(failedRecord.recordID))
                Logger.syncEngine.fault("Unknown error saving record \(failedRecord.recordID): \(failedRecordSave.error)")

                guard let sentQueueId = failedRecord.sentQueueId, let (localQueueId, _, _) = SyncEngine.parseCKRecordSentQueueId(sentQueueId) else { continue }
                pendingUploadChangeStates.append((localQueueId, .failed))
            }
        }

        try? storage.pendingUploadChangeState(by: pendingUploadChangeStates)

        var finalDeletedRecordIDs = deletedRecordIDs

        for (recordID, error) in failedRecordDeletes {
            switch error.code {
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated, .operationCancelled:
                // There are several errors that the sync engine will automatically retry, let's just log and move on.
                Logger.database.debug("Retryable error deleting \(recordID): \(error)")

            default:
                finalDeletedRecordIDs.append(recordID)
                Logger.syncEngine.fault("Unknown error deleting record \(recordID): \(error)")
            }
        }

        if !finalDeletedRecordIDs.isEmpty {
            let deletedQueueObjectIds = deletedRecordIDs.compactMap { UploadQueue.parseCKRecordID($0.recordName) }
            Logger.syncEngine.info("Sent deleted success record zone: \(deletedQueueObjectIds)")
            try? storage.pendingUploadDequeueDeleted(by: deletedQueueObjectIds)
        }

        syncEngine.state.remove(pendingRecordZoneChanges: removePendingRecordZoneChanges)
        syncEngine.state.add(pendingDatabaseChanges: newPendingDatabaseChanges)
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
        record[.createByDeviceId] = deviceId
        record.lastModifiedMilliseconds = modified.millisecondsSince1970
        if changes != UploadQueue.Changes.delete {
            record.encryptedValues[.payload] = payload
        }
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
        Logger.syncEngine.info("Next fetch by reason: \(context.reason, privacy: .public)")
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

        case let .fetchedRecordZoneChanges(modifications, deletions):
            await handleFetchedRecordZoneChanges(
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

        case .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges, .willSendChanges:
            break

        case .didFetchChanges, .didSendChanges:
            // 调度下一批
            try? await scheduleUploadIfNeeded()
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
        Logger.syncEngine.info("Next push by reason: \(reason, privacy: .public)")

        let scope = options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }

        // 最终提交的保存记录
        var recordsToSave: [CKRecord] = []

        // 当前 state 中待上传的删除队列项
        var realRecordIDsToDelete: [CKRecord.ID] = []

        // 当前 state 中待上传的保存队列项
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

        // 实际从数据库中查出来的保存队列记录
        let objects = storage.pendingUploadList(queueIds: recordsToSaveQueueIds.map(\.0))

        // 取出现存的 queueId 集合
        let existingQueueIds = Set(objects.map(\.id))

        // ✅ 找出 state 中有但数据库已无的 queueId
        let missingQueueIds = recordsToSaveQueueIds.filter { !existingQueueIds.contains($0.queueId) }

        if !missingQueueIds.isEmpty {
            // 需要从 syncEngine.state 中移除的 pending changes
            let staleChanges: [CKSyncEngine.PendingRecordZoneChange] = missingQueueIds.map {
                .saveRecord($0.recordId)
            }

            Logger.syncEngine.info("Removing \(staleChanges.count) missing UploadQueue pending changes")
            syncEngine.state.remove(pendingRecordZoneChanges: staleChanges)
        }

        let deviceId = Storage.deviceId

        /// 对于同一批次保存记录，不能有重复的，所以这里去重处理
        /// 只用最新的记录
        /// ✅ Step 1: 按 ckRecordID 分组
        let groupedByRecord = Dictionary(grouping: objects, by: { $0.ckRecordID })

        /// ✅ Step 2: 对每组取 id 最大的那一条作为最终对象
        var latestObjects: [UploadQueue] = []
        var staleRecordChanges: [CKSyncEngine.PendingRecordZoneChange] = []

        for (_, group) in groupedByRecord {
            guard let latest = group.max(by: { $0.id < $1.id }) else { continue }
            latestObjects.append(latest)

            /// 旧版本 UploadQueue 的变更应被移除
            let stale = group.filter { $0.id != latest.id }
            for old in stale {
                let staleChange = CKSyncEngine.PendingRecordZoneChange.saveRecord(
                    CKRecord.ID(recordName: SyncEngine.makeCKRecordSentQueueId(
                        queueId: old.id,
                        objectId: old.objectId,
                        deviceId: Storage.deviceId
                    ), zoneID: SyncEngine.zoneID)
                )
                staleRecordChanges.append(staleChange)
            }
        }

        /// ✅ Step 3: 从 SyncEngine state 移除旧的 PendingChanges
        if !staleRecordChanges.isEmpty {
            Logger.syncEngine.info("Removing \(staleRecordChanges.count) stale old record changes")
            syncEngine.state.remove(pendingRecordZoneChanges: staleRecordChanges)
        }

        /// ✅ Step 4: 用最新对象生成 CKRecord
        for object in latestObjects {
            let metadata: SyncMetadata? = try? storage.findSyncMetadata(zoneName: SyncEngine.zoneID.zoneName, ownerName: SyncEngine.zoneID.ownerName, recordName: object.ckRecordID)

            let record = metadata?.lastKnownRecord ?? CKRecord(recordType: SyncEngine.recordType, recordID: CKRecord.ID(recordName: object.ckRecordID, zoneID: SyncEngine.zoneID))

            let sentQueueId = SyncEngine.makeCKRecordSentQueueId(queueId: object.id, objectId: object.objectId, deviceId: deviceId)
            record.sentQueueId = sentQueueId
            record.lastModifiedByDeviceId = deviceId
            object.populateRecord(record)
            recordsToSave.append(record)
        }

        /// 更新为 uploading
        try? storage.pendingUploadChangeState(by: objects.map { ($0.id, .uploading) })

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
        Logger.syncEngine.info("Next fetch by reason: \(reason, privacy: .public)")
        let options = CKSyncEngine.FetchChangesOptions()
        return options
    }
}
