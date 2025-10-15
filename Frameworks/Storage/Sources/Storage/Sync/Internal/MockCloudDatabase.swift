//
//  MockCloudDatabase.swift
//  Storage
//
//  Created by king on 2025/10/15.
//

import CloudKit

package final class MockCloudDatabase: CloudDatabase {
    package let databaseScope: CKDatabase.Scope

    let _container = IsolatedWeakVar<MockCloudContainer>()

    package init(databaseScope: CKDatabase.Scope) {
        self.databaseScope = databaseScope
    }

    package func set(container: MockCloudContainer) {
        _container.set(container)
    }

    package var container: MockCloudContainer {
        _container.value!
    }

    package func allRecordZones() async throws -> [CKRecordZone] {
        fatalError("TODO:")
    }

    package func record(for _: CKRecord.ID) throws -> CKRecord {
        fatalError("TODO:")
    }

    package func records(
        for _: [CKRecord.ID],
        desiredKeys _: [CKRecord.FieldKey]?
    ) throws -> [CKRecord.ID: Result<CKRecord, any Error>] {
        fatalError("TODO:")
    }

    package func modifyRecords(
        saving _: [CKRecord] = [],
        deleting _: [CKRecord.ID] = [],
        savePolicy _: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged,
        atomically _: Bool = true
    ) throws -> (
        saveResults: [CKRecord.ID: Result<CKRecord, any Error>],
        deleteResults: [CKRecord.ID: Result<Void, any Error>]
    ) {
        fatalError("TODO:")
    }

    package func modifyRecordZones(
        saving _: [CKRecordZone] = [],
        deleting _: [CKRecordZone.ID] = []
    ) throws -> (
        saveResults: [CKRecordZone.ID: Result<CKRecordZone, any Error>],
        deleteResults: [CKRecordZone.ID: Result<Void, any Error>]
    ) {
        fatalError("TODO:")
    }

    package nonisolated static func == (lhs: MockCloudDatabase, rhs: MockCloudDatabase) -> Bool {
        lhs === rhs
    }

    package nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
