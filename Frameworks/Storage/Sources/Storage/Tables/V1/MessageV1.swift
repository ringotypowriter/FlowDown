//
//  MessageV1.swift
//  Objects
//
//  Created by 秋星桥 on 1/23/25.
//

import Foundation
import MarkdownParser
import WCDBSwift

public final class MessageV1: Identifiable, Codable, TableCodable {
    static let table: String = "Message"

    public var id: Int64 = .init()
    public var conversationId: ConversationV1.ID = .init()
    public var creation: Date = .init()
    public var role: Message.Role = .system
    public var thinkingDuration: TimeInterval = 0
    public var reasoningContent: String = ""
    public var isThinkingFold: Bool = false
    public var document: String = ""
    public var documentNodes: [MarkdownBlockNode] = []
    public var webSearchStatus: Message.WebSearchStatus = .init()
    public var toolStatus: Message.ToolStatus = .init()

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = MessageV1
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true, isAutoIncrement: true, isUnique: true)
            BindColumnConstraint(conversationId, isNotNull: true)
            BindColumnConstraint(creation, isNotNull: true, defaultTo: Date(timeIntervalSince1970: 0))
            BindColumnConstraint(role, isNotNull: true, defaultTo: Message.Role.system.rawValue)
            BindColumnConstraint(thinkingDuration, isNotNull: true, defaultTo: 0)
            BindColumnConstraint(reasoningContent, isNotNull: true, defaultTo: "")
            BindColumnConstraint(isThinkingFold, isNotNull: true, defaultTo: false)
            BindColumnConstraint(document, isNotNull: true, defaultTo: "")
            BindColumnConstraint(documentNodes, isNotNull: true, defaultTo: [MarkdownBlockNode]())
            BindColumnConstraint(webSearchStatus, isNotNull: true, defaultTo: Message.WebSearchStatus())
            BindColumnConstraint(toolStatus, isNotNull: true, defaultTo: Message.ToolStatus())

            BindForeginKey(
                conversationId,
                foreignKey: ForeignKey()
                    .references(with: ConversationV1.table)
                    .columns(ConversationV1.CodingKeys.id)
                    .onDelete(.cascade)
            )
        }

        case id
        case conversationId
        case creation
        case role
        case thinkingDuration
        case reasoningContent
        case isThinkingFold
        case document
        case documentNodes
        case webSearchStatus
        case toolStatus
    }

    public var isAutoIncrement: Bool = false // 用于定义是否使用自增的方式插入
    public var lastInsertedRowID: Int64 = 0 // 用于获取自增插入后的主键值
}

extension MessageV1: Equatable {
    public static func == (lhs: MessageV1, rhs: MessageV1) -> Bool {
        lhs.id == rhs.id &&
            lhs.conversationId == rhs.conversationId &&
            lhs.creation == rhs.creation &&
            lhs.role == rhs.role &&
            lhs.thinkingDuration == rhs.thinkingDuration &&
            lhs.reasoningContent == rhs.reasoningContent &&
            lhs.isThinkingFold == rhs.isThinkingFold &&
            lhs.document == rhs.document &&
            lhs.webSearchStatus == rhs.webSearchStatus
    }
}

extension MessageV1: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(conversationId)
        hasher.combine(creation)
        hasher.combine(role)
        hasher.combine(thinkingDuration)
        hasher.combine(reasoningContent)
        hasher.combine(isThinkingFold)
        hasher.combine(document)
        hasher.combine(webSearchStatus)
    }
}
