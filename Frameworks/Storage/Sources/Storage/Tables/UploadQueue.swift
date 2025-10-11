//
//  UploadQueue.swift
//  Storage
//
//  Created by king on 2025/10/13.
//

import Foundation
import WCDBSwift

public final class UploadQueue: Identifiable, Codable, TableNamed, TableCodable {
    public static let tableName: String = "UploadQueueV1"

    public var id: Int64 = .init()
    public var tableName: String = .init()
    public var objectId: String = .init()
    public var creation: Date = .now
    public var changes: UploadQueue.Changes = .insert
    public var state: UploadQueue.State = .pending
    public var failCount: Int = 0
    public var payload: Data = .init()

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = UploadQueue
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(.id, isPrimary: true, isAutoIncrement: true)

            BindColumnConstraint(tableName, isNotNull: true)
            BindColumnConstraint(objectId, isNotNull: true)
            BindColumnConstraint(creation, isNotNull: true)
            BindColumnConstraint(changes, isNotNull: true)
            BindColumnConstraint(state, isNotNull: true)
            BindColumnConstraint(failCount, isNotNull: true)
            BindColumnConstraint(payload, isNotNull: false)
        }

        case id
        case tableName
        case objectId
        case creation
        case changes
        case state
        case failCount
        case payload
    }

    public var isAutoIncrement: Bool = true
    public var lastInsertedRowID: Int64 = .min
}

public extension UploadQueue {
    enum Changes: Int, Codable, ColumnCodable, ExpressionConvertible {
        case insert = 0
        case update = 1
        case delete = 2

        public init?(with value: WCDBSwift.Value) {
            self.init(rawValue: value.intValue)
        }

        public func archivedValue() -> WCDBSwift.Value {
            Value(Int32(rawValue))
        }

        public static var columnType: WCDBSwift.ColumnType {
            .integer32
        }

        public func asExpression() -> WCDBSwift.Expression {
            WCDBSwift.Expression(integerLiteral: rawValue)
        }
    }
}

public extension UploadQueue {
    enum State: Int, Codable, ColumnCodable, ExpressionConvertible {
        case pending = 0
        case uploading = 1
        case finish = 2
        case failed = 3

        public init?(with value: WCDBSwift.Value) {
            self.init(rawValue: value.intValue)
        }

        public func archivedValue() -> WCDBSwift.Value {
            Value(Int32(rawValue))
        }

        public static var columnType: WCDBSwift.ColumnType {
            .integer32
        }

        public func asExpression() -> WCDBSwift.Expression {
            WCDBSwift.Expression(integerLiteral: rawValue)
        }
    }
}

public extension UploadQueue {
    convenience init<T: Syncable>(source: T, changes: Changes) throws {
        self.init()
        objectId = source.objectId
        tableName = T.tableName
        creation = source.modified
        self.changes = changes
        payload = try source.encodePayload()
    }
}
