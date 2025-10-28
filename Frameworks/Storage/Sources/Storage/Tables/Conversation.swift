// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import WCDBSwift

public final class Conversation: Identifiable, Codable, TableNamed, DeviceOwned, TableCodable {
    public static let tableName: String = "Conversation"

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
    public var deviceId: String = ""
    public var removed: Bool = false
    public var modified: Date = .init()

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = Conversation
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(objectId, isPrimary: true, isNotNull: true, isUnique: true)
            BindColumnConstraint(deviceId, isNotNull: true)

            BindColumnConstraint(creation, isNotNull: true)
            BindColumnConstraint(modified, isNotNull: true)
            BindColumnConstraint(removed, isNotNull: false, defaultTo: false)

            BindColumnConstraint(title, isNotNull: true, defaultTo: "")
            BindColumnConstraint(icon, isNotNull: true, defaultTo: Data())
            BindColumnConstraint(isFavorite, isNotNull: true, defaultTo: false)
            BindColumnConstraint(shouldAutoRename, isNotNull: true, defaultTo: true)
            BindColumnConstraint(modelId, isNotNull: false, defaultTo: nil)

            BindIndex(creation, namedWith: "_creationIndex")
            BindIndex(modified, namedWith: "_modifiedIndex")
        }

        case objectId
        case deviceId
        case title
        case creation
        case icon
        case isFavorite
        case shouldAutoRename
        case modelId

        case removed
        case modified
    }

    public init(deviceId: String) {
        self.deviceId = deviceId
    }

    public func markModified(_ date: Date = .now) {
        modified = date
    }
}

extension Conversation: Updatable {
    @discardableResult
    public func update<Value>(_ keyPath: ReferenceWritableKeyPath<Conversation, Value>, to newValue: Value) -> Bool where Value: Equatable {
        let oldValue = self[keyPath: keyPath]
        guard oldValue != newValue else { return false }
        self[keyPath: keyPath] = newValue
        markModified()
        return true
    }

    public func update(_ block: (Conversation) -> Void) {
        block(self)
        markModified()
    }
}

extension Conversation: Equatable {
    public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.objectId == rhs.objectId &&
            lhs.deviceId == rhs.deviceId &&
            lhs.title == rhs.title &&
            lhs.creation == rhs.creation &&
            lhs.icon == rhs.icon &&
            lhs.isFavorite == rhs.isFavorite &&
            lhs.shouldAutoRename == rhs.shouldAutoRename &&
            lhs.modelId == rhs.modelId &&
            lhs.objectId == rhs.objectId &&
            lhs.removed == rhs.removed &&
            lhs.modified == rhs.modified
    }
}

extension Conversation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectId)
        hasher.combine(deviceId)
        hasher.combine(title)
        hasher.combine(creation)
        hasher.combine(icon)
        hasher.combine(isFavorite)
        hasher.combine(shouldAutoRename)
        hasher.combine(modelId)

        hasher.combine(removed)
        hasher.combine(modified)
    }
}
