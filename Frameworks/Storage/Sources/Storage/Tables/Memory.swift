//
//  Memory.swift
//  Storage
//
//  Created by Alan Ye on 8/14/25.
//

import Foundation
import WCDBSwift

public final class Memory: Identifiable, Codable, TableCodable {
    static var table: String { String(describing: self) }

    public var id: String = UUID().uuidString
    public var content: String = ""
    public var timestamp: Date = .init()
    public var conversationId: String? = nil

    public var version: Int = 0
    public var removed: Bool = false
    public var modified: Date = .now

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = Memory
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true, isNotNull: true, isUnique: true, defaultTo: UUID().uuidString)
            BindColumnConstraint(content, isNotNull: true, defaultTo: "")
            BindColumnConstraint(timestamp, isNotNull: true, defaultTo: Date.now)
            BindColumnConstraint(modified, isNotNull: true, defaultTo: Date.now)
            BindColumnConstraint(conversationId, isNotNull: false, defaultTo: nil)

            BindColumnConstraint(version, isNotNull: false, defaultTo: 0)
            BindColumnConstraint(removed, isNotNull: false, defaultTo: false)

            BindIndex(timestamp, namedWith: "_timestampIndex")
            BindIndex(modified, namedWith: "_modifiedIndex")
            BindIndex(conversationId, namedWith: "_conversationIdIndex")
        }

        case id
        case content
        case timestamp
        case conversationId

        case version
        case removed
        case modified
    }

    public init() {}

    public init(content: String, conversationId: String? = nil) {
        self.content = content
        self.conversationId = conversationId
        timestamp = Date()
    }

    func markModified() {
        version += 1
        modified = .now
    }
}

extension Memory: Equatable {
    public static func == (lhs: Memory, rhs: Memory) -> Bool {
        lhs.id == rhs.id &&
            lhs.content == rhs.content &&
            lhs.timestamp == rhs.timestamp &&
            lhs.modified == rhs.modified &&
            lhs.conversationId == rhs.conversationId &&
            lhs.version == rhs.version &&
            lhs.removed == rhs.removed
    }
}

extension Memory: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(content)
        hasher.combine(timestamp)
        hasher.combine(modified)
        hasher.combine(conversationId)
        hasher.combine(version)
        hasher.combine(removed)
    }
}
