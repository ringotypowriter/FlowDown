// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import WCDBSwift

public final class ConversationV1: Identifiable, Codable, TableCodable {
    static let table: String = "Conversation"

    public var id: Int64 = .init()
    public var title: String = ""
    public var creation: Date = .init()
    public var icon: Data = .init()
    public var isFavorite: Bool = false
    public var shouldAutoRename: Bool = true
    public var modelId: String? = nil

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = ConversationV1
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true, isAutoIncrement: true, isUnique: true)
            BindColumnConstraint(title, isNotNull: true, defaultTo: "")
            BindColumnConstraint(creation, isNotNull: true, defaultTo: Date(timeIntervalSince1970: 0))
            BindColumnConstraint(icon, isNotNull: true, defaultTo: Data())
            BindColumnConstraint(isFavorite, isNotNull: true, defaultTo: false)
            BindColumnConstraint(shouldAutoRename, isNotNull: true, defaultTo: true)
            BindColumnConstraint(modelId, isNotNull: false, defaultTo: nil)
        }

        case id
        case title
        case creation
        case icon
        case isFavorite
        case shouldAutoRename
        case modelId
    }

    public var isAutoIncrement: Bool = false // 用于定义是否使用自增的方式插入
    public var lastInsertedRowID: Int64 = 0 // 用于获取自增插入后的主键值
}

extension ConversationV1: Equatable {
    public static func == (lhs: ConversationV1, rhs: ConversationV1) -> Bool {
        lhs.id == rhs.id &&
            lhs.title == rhs.title &&
            lhs.creation == rhs.creation &&
            lhs.icon == rhs.icon &&
            lhs.isFavorite == rhs.isFavorite &&
            lhs.shouldAutoRename == rhs.shouldAutoRename &&
            lhs.modelId == rhs.modelId
    }
}

extension ConversationV1: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(creation)
        hasher.combine(icon)
        hasher.combine(isFavorite)
        hasher.combine(shouldAutoRename)
        hasher.combine(modelId)
    }
}
