//
//  Storage+UploadQueue.swift
//  Storage
//
//  Created by king on 2025/10/12.
//

import Foundation
import os.log
import WCDBSwift

// MARK: - Sync

extension CloudModel: Syncable, SyncQueryable {
    public static let SyncQuery: SyncQueryProperties = .init(objectId: CloudModel.Properties.objectId.asProperty(), modified: CloudModel.Properties.modified.asProperty(), removed: CloudModel.Properties.removed.asProperty())
    public func encodePayload() throws -> Data {
        Data()
    }

    public static func decodePayload(_: Data) throws -> Self {
        fatalError("TODO")
    }
}

extension ModelContextServer: Syncable, SyncQueryable {
    public static let SyncQuery: SyncQueryProperties = .init(objectId: ModelContextServer.Properties.objectId.asProperty(), modified: ModelContextServer.Properties.modified.asProperty(), removed: ModelContextServer.Properties.removed.asProperty())
    public func encodePayload() throws -> Data {
        Data()
    }

    public static func decodePayload(_: Data) throws -> Self {
        fatalError("TODO")
    }
}

extension Memory: Syncable, SyncQueryable {
    public static let SyncQuery: SyncQueryProperties = .init(objectId: Memory.Properties.objectId.asProperty(), modified: Memory.Properties.modified.asProperty(), removed: Memory.Properties.removed.asProperty())
    public func encodePayload() throws -> Data {
        Data()
    }

    public static func decodePayload(_: Data) throws -> Self {
        fatalError("TODO")
    }
}

extension Conversation: Syncable, SyncQueryable {
    public static let SyncQuery: SyncQueryProperties = .init(objectId: Conversation.Properties.objectId.asProperty(), modified: Conversation.Properties.modified.asProperty(), removed: Conversation.Properties.removed.asProperty())
    public func encodePayload() throws -> Data {
        Data()
    }

    public static func decodePayload(_: Data) throws -> Self {
        fatalError("TODO")
    }
}

extension Message: Syncable, SyncQueryable {
    public static let SyncQuery: SyncQueryProperties = .init(objectId: Message.Properties.objectId.asProperty(), modified: Message.Properties.modified.asProperty(), removed: Message.Properties.removed.asProperty())
    public func encodePayload() throws -> Data {
        Data()
    }

    public static func decodePayload(_: Data) throws -> Self {
        fatalError("TODO")
    }
}

extension Attachment: Syncable, SyncQueryable {
    public static let SyncQuery: SyncQueryProperties = .init(objectId: Attachment.Properties.objectId.asProperty(), modified: Attachment.Properties.modified.asProperty(), removed: Attachment.Properties.removed.asProperty())
    public func encodePayload() throws -> Data {
        Data()
    }

    public static func decodePayload(_: Data) throws -> Self {
        fatalError("TODO")
    }
}

public extension Storage {
    struct DiffSyncableResult<T: Syncable> {
        /// 新增的
        public let insert: [T]
        /// 更新的
        public let updated: [T]
        /// 删除度
        public let deleted: [T]

        public var isEmpty: Bool {
            insert.isEmpty && updated.isEmpty && deleted.isEmpty
        }

        public init(insert: [T] = [], updated: [T] = [], deleted: [T] = []) {
            self.insert = insert
            self.updated = updated
            self.deleted = deleted
        }

        public func insertOrReplace() -> [T] {
            insert + updated
        }
    }

    /// 根据本地数据库现有数据，区分新增/更新/删除对象
    /// - Parameters:
    ///   - objects: 需要处理的对象数组
    ///   - handle: 可选 WCDB Handle
    /// - Returns: 三个数组：新增、更新、删除
    func diffSyncable<T: Syncable & SyncQueryable>(
        objects: [T],
        handle: Handle? = nil
    ) throws -> DiffSyncableResult<T> {
        guard !objects.isEmpty else {
            return DiffSyncableResult()
        }

        // 1️⃣ 获取所有 objectId
        let objectIds = objects.map(\.objectId)

        // 2️⃣ 查询本地对应的对象
        let existsObjects: [T] = if let handle {
            try handle.getObjects(fromTable: T.tableName, where: T.SyncQuery.objectId.in(objectIds))
        } else {
            try db.getObjects(fromTable: T.tableName, where: T.SyncQuery.objectId.in(objectIds))
        }

        // 构建本地字典：objectId -> 本地对象
        var localDict: [String: T] = [:]
        for obj in existsObjects {
            localDict[obj.objectId] = obj
        }

        // 3️⃣ 遍历传入对象，分类
        var newObjects: [T] = []
        var updatedObjects: [T] = []
        var deletedObjects: [T] = []

        for obj in objects {
            if let local = localDict[obj.objectId] {
                // 本地存在
                if obj.removed {
                    deletedObjects.append(obj)
                } else if obj.modified > local.modified {
                    updatedObjects.append(obj)
                }
            } else {
                // 本地不存在 → 新增
                newObjects.append(obj)
            }
        }

        return DiffSyncableResult(insert: newObjects, updated: updatedObjects, deleted: deletedObjects)
    }

    func pendingUploadEnqueue(sources: [(source: any Syncable, changes: UploadQueue.Changes)], handle: Handle? = nil) throws {
        guard !sources.isEmpty else {
            return
        }

        let row = if let handle {
            try handle.getRow(on: UploadQueue.Properties.id.max(), fromTable: UploadQueue.tableName)
        } else {
            try db.getRow(on: UploadQueue.Properties.id.max(), fromTable: UploadQueue.tableName)
        }

        var maxId = row[0].int64Value + 1

        let queues = try sources.map {
            let value = try UploadQueue(source: $0.source, changes: $0.changes)
            value.id = maxId
            maxId += 1
            return value
        }

        if let handle {
            try handle.insert(queues, intoTable: UploadQueue.tableName)
        } else {
            try db.insert(queues, intoTable: UploadQueue.tableName)
        }

        uploadQueueEnqueueHandler?(queues)
    }

    /// 从上传队列中删除记录，内部采用软删除。在空闲时执行物理删除
    /// - Parameters:
    ///   - deleting: 待删除集合
    ///   - handle: 数据库句柄，传入 nil 时使用主句柄
    func pendingUploadDequeue(by deleting: [(queueId: UploadQueue.ID, objectId: String)], handle: Handle? = nil) throws {
        guard !deleting.isEmpty else {
            return
        }

        try runTransaction(handle: handle) {
            for item in deleting {
                try $0.update(
                    table: UploadQueue.tableName,
                    on: [UploadQueue.Properties.state],
                    with: [UploadQueue.State.finish],
                    where: UploadQueue.Properties.id <= item.queueId
                        && UploadQueue.Properties.objectId == item.objectId
                )
            }
        }
    }

    /// 从上传队列中删除记录，内部采用软删除。在空闲时执行物理删除
    /// - Parameters:
    ///   - deleting: 待删除集合
    ///   - handle: 数据库句柄，传入 nil 时使用主句柄
    func pendingUploadDequeueDeleted(by deleting: [(objectId: String, tableName: String)], handle: Handle? = nil) throws {
        guard !deleting.isEmpty else {
            return
        }

        try runTransaction(handle: handle) {
            for item in deleting {
                try $0.update(
                    table: UploadQueue.tableName,
                    on: [UploadQueue.Properties.state],
                    with: [UploadQueue.State.finish],
                    where: UploadQueue.Properties.objectId == item.objectId
                        && UploadQueue.Properties.tableName == item.tableName
                )
            }
        }
    }

    /// 批量更新状态
    /// - Parameters:
    ///   - changes: 待更新集合
    ///   - handle: 数据库句柄，传入 nil 时使用主句柄
    func pendingUploadChangeState(by changes: [(queueId: UploadQueue.ID, state: UploadQueue.State)], handle: Handle? = nil) throws {
        guard !changes.isEmpty else {
            return
        }

        try runTransaction(handle: handle) {
            let grouped = Dictionary(grouping: changes, by: { $0.state })

            for (state, group) in grouped {
                let queueIds = group.map(\.queueId)

                let update = StatementUpdate().update(table: UploadQueue.tableName)
                if case .failed = state {
                    update.set(UploadQueue.Properties.failCount)
                        .to(UploadQueue.Properties.failCount + 1)
                        .where(UploadQueue.Properties.id.in(queueIds))
                } else {
                    update.set(UploadQueue.Properties.state)
                        .to(state)
                        .where(UploadQueue.Properties.id.in(queueIds))
                }

                try $0.exec(update)
            }
        }
    }

    /// 将状态为failed的记录更为状态为pending
    /// - Parameter handle: 数据库句柄，传入 nil 时使用主句柄
    func pendingUploadRestToPendingState(handle: Handle? = nil) throws {
        try runTransaction(handle: handle) {
            let update = StatementUpdate().update(table: UploadQueue.tableName)
            update.set(UploadQueue.Properties.state)
                .to(UploadQueue.State.pending)
                .where(UploadQueue.Properties.state == UploadQueue.State.failed)

            try $0.exec(update)
        }
    }

    /// 查询状态为pending 的集合
    /// - Parameters:
    ///   - batchSize: 批次大小
    ///   - handle: 数据库句柄，传入 nil 时使用主句柄
    /// - Returns: 队列信息， 已按ID进行ascending排序
    func pendingUploadList(batchSize: Int = 0, handle: Handle? = nil) -> [UploadQueue] {
        guard let select = if let handle {
            try? handle.prepareSelect(of: UploadQueue.self, fromTable: UploadQueue.tableName)
        } else {
            try? db.prepareSelect(of: UploadQueue.self, fromTable: UploadQueue.tableName)
        } else {
            return []
        }

        // UploadQueue 是本地的修改历史，理论上只取最新的修改记录为准
        let subSelect = StatementSelect()
            .select(UploadQueue.Properties.id.max())
            .from(UploadQueue.tableName)
            .where(UploadQueue.Properties.state == UploadQueue.State.pending)
            .group(by: UploadQueue.Properties.objectId)
            .order(by: UploadQueue.Properties.creation.order(.ascending))

        if batchSize > 0 {
            subSelect.limit(batchSize)
        }

        guard let rows = if let handle {
            try? handle.getRows(from: subSelect)
        } else {
            try? db.getRows(from: subSelect)
        } else {
            return []
        }

        guard !rows.isEmpty else {
            return []
        }

        let ids = rows.map { $0[0].int64Value }

        select.where(
            //            UploadQueue.Properties.id.in(subSelect.asExpression())
            UploadQueue.Properties.id.in(ids)
        )
        .order(by: [
            UploadQueue.Properties.id.order(.ascending),
        ])

        do {
            let objects = try select.allObjects()
            return objects as! [UploadQueue]
        } catch {
            Logger.database.error("query pending upload error: \(error)")
            return []
        }
    }

    /// 查询状态为pending的指定队列ID集合
    /// - Parameters:
    ///   - queueIds: 队列ID
    ///   - handle: 数据库句柄，传入 nil 时使用主句柄
    /// - Returns: 队列信息， 已按ID进行ascending排序
    func pendingUploadList(queueIds: [UploadQueue.ID], handle: Handle? = nil) -> [UploadQueue] {
        guard let select = if let handle {
            try? handle.prepareSelect(of: UploadQueue.self, fromTable: UploadQueue.tableName)
        } else {
            try? db.prepareSelect(of: UploadQueue.self, fromTable: UploadQueue.tableName)
        } else {
            return []
        }

        select.where(
            UploadQueue.Properties.id.in(queueIds)
                && UploadQueue.Properties.state == UploadQueue.State.pending
        )
        .order(by: [
            UploadQueue.Properties.id.order(.ascending),
        ])

        guard let objects = try? select.allObjects() as? [UploadQueue] else { return [] }
        return objects
    }

    func performSyncFirstTimeSetup() async throws {
        guard !hasPerformedFirstSync else { return }

        let handle = try getHandle()

        try handle.run(transaction: { [weak self] in
            guard let self else { return }

            Logger.database.info("[*] performSyncFirstTimeSetup begin")
            let tables: [any Syncable.Type] = [
                CloudModel.self,
                ModelContextServer.self,
                Conversation.self,
                Message.self,
                Attachment.self,
                Memory.self,
            ]

            var startId: Int64 = -1
            for table in tables {
                startId = try firstMigrationUploadQueue(table: table, handle: $0, startId: startId + 1)
            }

        })

        hasPerformedFirstSync = true

        Logger.database.info("[*] performSyncFirstTimeSetup end")

        uploadQueueEnqueueHandler?([])
    }

    private func firstMigrationUploadQueue<T: Syncable>(table _: T.Type, handle: Handle, startId: Int64) throws -> Int64 {
        var objects: [T] = try handle.getObjects(fromTable: T.tableName)

        guard !objects.isEmpty else {
            return startId
        }

        objects = objects.sorted(by: { $0.modified < $1.modified })

        var queues: [UploadQueue] = []
        var id = startId
        for object in objects {
            let queue = try UploadQueue(source: object, changes: .insert)
            queue.id = id
            id += 1
            queues.append(queue)
        }

        guard !queues.isEmpty else {
            return startId
        }

        try handle.insert(queues, intoTable: UploadQueue.tableName)
        let lastInsertedRowID = handle.lastInsertedRowID

        Logger.database.info("[*] firstMigrationUploadQueue \(T.tableName) -> \(queues.count)")

        return lastInsertedRowID
    }
}
