//
//  Memory.swift
//  Storage
//
//  Created by Alan Ye on 8/14/25.
//

import Foundation
import WCDBSwift

public final class Memory: Identifiable, Codable, TableCodable {
    static var table: String = "MemoryV2"

    public var id: String {
        objectId
    }

    public var objectId: String = UUID().uuidString
    public var content: String = ""
    public var creation: Date = .now
    public var conversationId: String? = nil

    public var removed: Bool = false
    public var modified: Date = .now

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = Memory
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(objectId, isPrimary: true, isNotNull: true, isUnique: true)

            BindColumnConstraint(creation, isNotNull: true)
            BindColumnConstraint(modified, isNotNull: true)
            BindColumnConstraint(removed, isNotNull: false, defaultTo: false)

            BindColumnConstraint(content, isNotNull: true, defaultTo: "")
            BindColumnConstraint(conversationId, isNotNull: false, defaultTo: nil)

            BindIndex(creation, namedWith: "_creationIndex")
            BindIndex(modified, namedWith: "_modifiedIndex")
            BindIndex(conversationId, namedWith: "_conversationIdIndex")
        }

        case objectId
        case content
        case creation
        case conversationId

        case removed
        case modified
    }

    public init() {}

    public init(content: String, conversationId: String? = nil) {
        self.content = content
        self.conversationId = conversationId
    }

    func markModified() {
        modified = .now
    }
}

extension Memory: Equatable {
    public static func == (lhs: Memory, rhs: Memory) -> Bool {
        lhs.objectId == rhs.objectId &&
            lhs.content == rhs.content &&
            lhs.creation == rhs.creation &&
            lhs.modified == rhs.modified &&
            lhs.conversationId == rhs.conversationId &&
            lhs.removed == rhs.removed
    }
}

extension Memory: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectId)
        hasher.combine(content)
        hasher.combine(creation)
        hasher.combine(modified)
        hasher.combine(conversationId)
        hasher.combine(removed)
    }
}
