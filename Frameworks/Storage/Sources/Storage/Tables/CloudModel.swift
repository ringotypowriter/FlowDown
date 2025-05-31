//
//  CloudModel.swift
//  Objects
//
//  Created by 秋星桥 on 1/23/25.
//

import Foundation
import WCDBSwift

public final class CloudModel: Identifiable, Codable, Equatable, Hashable, TableCodable {
    public var id: String = .init()
    public var model_identifier: String = ""
    public var model_list_endpoint: String = ""
    public var creation: Date = .init()
    public var endpoint: String = ""
    public var token: String = ""
    public var capabilities: Set<ModelCapabilities> = []
    public var context: ModelContextLength = .short_8k

    // can be used when loading model from our server
    // present to user on the top of the editor page
    public var comment: String = ""

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = CloudModel
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true, isUnique: true, defaultTo: "")
            BindColumnConstraint(model_identifier, isNotNull: true, defaultTo: "")
            BindColumnConstraint(model_list_endpoint, isNotNull: true, defaultTo: "")
            BindColumnConstraint(creation, isNotNull: true, defaultTo: Date(timeIntervalSince1970: 0))
            BindColumnConstraint(endpoint, isNotNull: true, defaultTo: "")
            BindColumnConstraint(token, isNotNull: true, defaultTo: "")
            BindColumnConstraint(capabilities, isNotNull: true, defaultTo: Set<ModelCapabilities>())
            BindColumnConstraint(context, isNotNull: true, defaultTo: ModelContextLength.short_8k)
            BindColumnConstraint(comment, isNotNull: true, defaultTo: "")
        }

        case id
        case model_identifier
        case model_list_endpoint
        case creation
        case endpoint
        case token
        case capabilities
        case context
        case comment
    }

    public init(
        id: String = UUID().uuidString,
        model_identifier: String = "",
        model_list_endpoint: String = "$INFERENCE_ENDPOINT$/../../models",
        creation: Date = .init(),
        endpoint: String = "",
        token: String = "",
        context _: ModelContextLength = .medium_64k,
        capabilities: Set<ModelCapabilities> = [],
        comment: String = ""
    ) {
        self.id = id
        self.model_identifier = model_identifier
        self.model_list_endpoint = model_list_endpoint
        self.creation = creation
        self.endpoint = endpoint
        self.token = token
        self.capabilities = capabilities
        self.comment = comment
    }

    public static func == (lhs: CloudModel, rhs: CloudModel) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(model_identifier)
        hasher.combine(model_list_endpoint)
        hasher.combine(creation)
        hasher.combine(endpoint)
        hasher.combine(token)
        hasher.combine(capabilities)
        hasher.combine(context)
        hasher.combine(comment)
    }
}

extension ModelCapabilities: ColumnCodable {
    public init?(with value: WCDBSwift.Value) {
        let text = value.stringValue
        self.init(rawValue: text)
    }

    public func archivedValue() -> WCDBSwift.Value {
        .init(rawValue)
    }

    public static var columnType: ColumnType {
        .text
    }
}

extension ModelContextLength: ColumnCodable {
    public init?(with value: WCDBSwift.Value) {
        self.init(rawValue: value.intValue)
    }

    public func archivedValue() -> WCDBSwift.Value {
        .init(rawValue)
    }

    public static var columnType: ColumnType {
        .integer64
    }
}
