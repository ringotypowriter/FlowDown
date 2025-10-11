//
//  MemoryV1.swift
//  Storage
//
//  Created by Alan Ye on 8/14/25.
//

import Foundation
import WCDBSwift

public final class MemoryV1: Identifiable, Codable, TableCodable {
    static var table: String = "Memory"

    public var id: String = UUID().uuidString
    public var content: String = ""
    public var timestamp: Date = .init()
    public var conversationId: String? = nil

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = MemoryV1
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true, isUnique: true)
            BindColumnConstraint(content, isNotNull: true, defaultTo: "")
            BindColumnConstraint(timestamp, isNotNull: true, defaultTo: Date(timeIntervalSince1970: 0))
            BindColumnConstraint(conversationId, isNotNull: false, defaultTo: nil)
        }

        case id
        case content
        case timestamp
        case conversationId
    }

    public var isAutoIncrement: Bool = false
    public var lastInsertedRowID: Int64 = 0

    public init() {}

    public init(content: String, conversationId: String? = nil) {
        self.content = content
        self.conversationId = conversationId
        timestamp = Date()
    }
}

extension MemoryV1: Equatable {
    public static func == (lhs: MemoryV1, rhs: MemoryV1) -> Bool {
        lhs.id == rhs.id &&
            lhs.content == rhs.content &&
            lhs.timestamp == rhs.timestamp &&
            lhs.conversationId == rhs.conversationId
    }
}

extension MemoryV1: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(content)
        hasher.combine(timestamp)
        hasher.combine(conversationId)
    }
}
