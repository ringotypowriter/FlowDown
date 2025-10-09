// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import WCDBSwift

public final class Conversation: Identifiable, Codable, TableCodable {
    static let table: String = "ConversationV2"

    public var id: String {
        objectId
    }

    public var title: String = ""
    public var creation: Date = .now
    public var icon: Data = .init()
    public var isFavorite: Bool = false
    public var shouldAutoRename: Bool = true
    public var modelId: String? = nil

    public var objectId: String = UUID().uuidString
    public var version: Int = 0
    public var removed: Bool = false
    public var modified: Date = .init()

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = Conversation
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(objectId, isPrimary: true, isNotNull: true, isUnique: true)

            BindColumnConstraint(creation, isNotNull: true, defaultTo: Date.now)
            BindColumnConstraint(modified, isNotNull: true, defaultTo: Date.now)

            BindColumnConstraint(title, isNotNull: true, defaultTo: "")
            BindColumnConstraint(icon, isNotNull: true, defaultTo: Data())
            BindColumnConstraint(isFavorite, isNotNull: true, defaultTo: false)
            BindColumnConstraint(shouldAutoRename, isNotNull: true, defaultTo: true)
            BindColumnConstraint(modelId, isNotNull: false, defaultTo: nil)

            BindColumnConstraint(version, isNotNull: false, defaultTo: 0)
            BindColumnConstraint(removed, isNotNull: false, defaultTo: false)

            BindIndex(creation, namedWith: "_creationIndex")
            BindIndex(modified, namedWith: "_modifiedIndex")
        }

        case objectId
        case title
        case creation
        case icon
        case isFavorite
        case shouldAutoRename
        case modelId

        case version
        case removed
        case modified
    }

    func markModified() {
        version += 1
        modified = .now
    }
}

extension Conversation: Equatable {
    public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.objectId == rhs.objectId &&
            lhs.title == rhs.title &&
            lhs.creation == rhs.creation &&
            lhs.icon == rhs.icon &&
            lhs.isFavorite == rhs.isFavorite &&
            lhs.shouldAutoRename == rhs.shouldAutoRename &&
            lhs.modelId == rhs.modelId &&
            lhs.objectId == rhs.objectId &&
            lhs.version == rhs.version &&
            lhs.removed == rhs.removed &&
            lhs.modified == rhs.modified
    }
}

extension Conversation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectId)
        hasher.combine(title)
        hasher.combine(creation)
        hasher.combine(icon)
        hasher.combine(isFavorite)
        hasher.combine(shouldAutoRename)
        hasher.combine(modelId)

        hasher.combine(version)
        hasher.combine(removed)
        hasher.combine(modified)
    }
}
