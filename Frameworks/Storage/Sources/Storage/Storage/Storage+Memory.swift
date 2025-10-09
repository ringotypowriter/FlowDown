//
//  Storage+Memory.swift
//  Storage
//
//  Created by Alan Ye on 8/14/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    enum MemoryError: Error, LocalizedError {
        case insertFailed(String)
        case retrieveFailed(String)
        case deleteFailed(String)
        case memoryNotFound(String)
        case databaseError(String)

        var localizedDescription: String {
            switch self {
            case let .insertFailed(message):
                "Failed to insert memory: \(message)"
            case let .retrieveFailed(message):
                "Failed to retrieve memories: \(message)"
            case let .deleteFailed(message):
                "Failed to delete memory: \(message)"
            case let .memoryNotFound(id):
                "Memory with ID \(id) not found"
            case let .databaseError(message):
                "Database error: \(message)"
            }
        }
    }

    func insertMemory(_ memory: Memory) throws {
        do {
            memory.markModified()
            try db.insertOrReplace([memory], intoTable: Memory.table)
        } catch {
            throw MemoryError.insertFailed(error.localizedDescription)
        }
    }

    func getAllMemories() throws -> [Memory] {
        do {
            return try db.getObjects(
                fromTable: Memory.table,
                where: Memory.Properties.removed == false,
                orderBy: [
                    Memory.Properties.timestamp.order(.descending),
                ]
            )
        } catch {
            throw MemoryError.retrieveFailed(error.localizedDescription)
        }
    }

    func getMemoriesWithLimit(_ limit: Int) throws -> [Memory] {
        do {
            return try db.getObjects(
                fromTable: Memory.table,
                where: Memory.Properties.removed == false,
                orderBy: [
                    Memory.Properties.timestamp.order(.descending),
                ],
                limit: limit
            )
        } catch {
            throw MemoryError.retrieveFailed(error.localizedDescription)
        }
    }

    func getMemory(id: String) throws -> Memory? {
        do {
            return try db.getObject(
                fromTable: Memory.table,
                where: Memory.Properties.id == id && Memory.Properties.removed == false
            )
        } catch {
            throw MemoryError.retrieveFailed(error.localizedDescription)
        }
    }

    func searchMemories(query: String, limit: Int = 20) throws -> [Memory] {
        do {
            return try db.getObjects(
                fromTable: Memory.table,
                where: Memory.Properties.removed == false && Memory.Properties.content.like("%\(query)%"),
                orderBy: [
                    Memory.Properties.timestamp.order(.descending),
                ],
                limit: limit
            )
        } catch {
            throw MemoryError.retrieveFailed(error.localizedDescription)
        }
    }

    func getMemoryCount() throws -> Int {
        do {
            let objects: [Memory] = try db.getObjects(fromTable: Memory.table, where: Memory.Properties.removed == false)
            return objects.count
        } catch {
            throw MemoryError.retrieveFailed(error.localizedDescription)
        }
    }

    func updateMemory(_ memory: Memory) throws {
        do {
            let existingMemory = try db.getObject(
                fromTable: Memory.table,
                where: Memory.Properties.id == memory.id
            ) as Memory?

            guard existingMemory != nil else {
                throw MemoryError.memoryNotFound(memory.id)
            }

            memory.markModified()
            try db.insertOrReplace([memory], intoTable: Memory.table)
        } catch let error as MemoryError {
            throw error
        } catch {
            throw MemoryError.insertFailed(error.localizedDescription)
        }
    }

    func deleteMemory(id: String, handle: Handle? = nil) throws {
        do {
            let existingMemory = if let handle {
                try handle.getObject(
                    fromTable: Memory.table,
                    where: Memory.Properties.id == id
                ) as Memory?
            } else {
                try db.getObject(
                    fromTable: Memory.table,
                    where: Memory.Properties.id == id
                ) as Memory?
            }

            guard existingMemory != nil else {
                throw MemoryError.memoryNotFound(id)
            }

            let update = StatementUpdate().update(table: Memory.table)
                .set(Memory.Properties.version)
                .to(Memory.Properties.version + 1)
                .set(Memory.Properties.removed)
                .to(true)
                .set(Memory.Properties.modified)
                .to(Date.now)
                .where(Memory.Properties.id == id)

            if let handle {
                try handle.exec(update)
            } else {
                try db.exec(update)
            }
        } catch let error as MemoryError {
            throw error
        } catch {
            throw MemoryError.deleteFailed(error.localizedDescription)
        }
    }

    func deleteAllMemories(handle: Handle? = nil) throws {
        do {
            let update = StatementUpdate().update(table: Memory.table)
                .set(Memory.Properties.version)
                .to(Memory.Properties.version + 1)
                .set(Memory.Properties.removed)
                .to(true)
                .set(Memory.Properties.modified)
                .to(Date.now)

            if let handle {
                try handle.exec(update)
            } else {
                try db.exec(update)
            }
        } catch {
            throw MemoryError.deleteFailed(error.localizedDescription)
        }
    }

    func deleteOldMemories(keepCount: Int) throws {
        do {
            let allMemories: [Memory] = try db.getObjects(fromTable: Memory.table, where: Memory.Properties.removed == false)

            let totalCount = allMemories.count
            guard totalCount > keepCount else { return }

            let memoriesToDelete = try db.getObjects(
                fromTable: Memory.table,
                where: Memory.Properties.removed == false,
                orderBy: [
                    Memory.Properties.timestamp.order(.ascending),
                ],
                limit: totalCount - keepCount
            ) as [Memory]

            guard !memoriesToDelete.isEmpty else {
                return
            }

            let idsToDelete = memoriesToDelete.map(\.id)

            let update = StatementUpdate().update(table: Memory.table)
                .set(Memory.Properties.version)
                .to(Memory.Properties.version + 1)
                .set(Memory.Properties.removed)
                .to(true)
                .set(Memory.Properties.modified)
                .to(Date.now)
                .where(Memory.Properties.id.in(idsToDelete))

            try db.exec(update)
        } catch {
            throw MemoryError.deleteFailed(error.localizedDescription)
        }
    }
}
