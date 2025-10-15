//
//  MockSyncEngine.swift
//  Storage
//
//  Created by king on 2025/10/15.
//

import CloudKit
import OrderedCollections

package final class MockSyncEngine: SyncEngineProtocol {
    package let database: MockCloudDatabase
    package let parentSyncEngine: SyncEngine
    package let _state: LockIsolated<MockSyncEngineState>
    package let _fetchChangesScopes = LockIsolated<[CKSyncEngine.FetchChangesOptions.Scope]>([])

    package var description: String {
        "\(type(of: self))"
    }

    package var scope: CKDatabase.Scope {
        database.databaseScope
    }

    package var state: MockSyncEngineState {
        _state.withValue(\.self)
    }

    package init(database: MockCloudDatabase, parentSyncEngine: SyncEngine, state: MockSyncEngineState) {
        self.database = database
        self.parentSyncEngine = parentSyncEngine
        _state = LockIsolated(state)
    }

    package func cancelOperations() async {
        fatalError("TODO:")
    }

    package func fetchChanges(_: CKSyncEngine.FetchChangesOptions) async throws {
        fatalError("TODO:")
    }

    package func nextRecordZoneChangeBatch(recordsToSave _: [CKRecord], recordIDsToDelete _: [CKRecord.ID], atomicByZone _: Bool, syncEngine _: any SyncEngineProtocol) async -> CKSyncEngine.RecordZoneChangeBatch? {
        fatalError("TODO:")
    }

    package func sendChanges(_: CKSyncEngine.SendChangesOptions) async throws {
        fatalError("TODO:")
    }
}

package final class MockSyncEngineState: CKSyncEngineStateProtocol {
    package let _pendingRecordZoneChanges = LockIsolated<
        OrderedSet<CKSyncEngine.PendingRecordZoneChange>
    >([]
    )
    package let _pendingDatabaseChanges = LockIsolated<
        OrderedSet<CKSyncEngine.PendingDatabaseChange>
    >([])

    package var pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange] {
        _pendingRecordZoneChanges.withValue { Array($0) }
    }

    package var pendingDatabaseChanges: [CKSyncEngine.PendingDatabaseChange] {
        _pendingDatabaseChanges.withValue { Array($0) }
    }

    package func removePendingChanges() {
        _pendingDatabaseChanges.withValue { $0.removeAll() }
        _pendingRecordZoneChanges.withValue { $0.removeAll() }
    }

    package func add(pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange]) {
        _pendingRecordZoneChanges.withValue {
            $0.append(contentsOf: pendingRecordZoneChanges)
        }
    }

    package func remove(pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange]) {
        _pendingRecordZoneChanges.withValue {
            $0.subtract(pendingRecordZoneChanges)
        }
    }

    package func add(pendingDatabaseChanges: [CKSyncEngine.PendingDatabaseChange]) {
        _pendingDatabaseChanges.withValue {
            $0.append(contentsOf: pendingDatabaseChanges)
        }
    }

    package func remove(pendingDatabaseChanges: [CKSyncEngine.PendingDatabaseChange]) {
        _pendingDatabaseChanges.withValue {
            $0.subtract(pendingDatabaseChanges)
        }
    }
}
