//
//  CloudModel.swift
//  Objects
//
//  Created by 秋星桥 on 1/23/25.
//

import Foundation
import WCDBSwift

public final class CloudModel: Identifiable, Codable, Equatable, Hashable, TableCodable {
    static var table: String = "CloudModelV2"

    public var id: String {
        objectId
    }

    public var objectId: String = UUID().uuidString
    public var model_identifier: String = ""
    public var model_list_endpoint: String = ""
    public var creation: Date = .now
    public var endpoint: String = ""
    public var token: String = ""
    public var headers: [String: String] = [:] // additional headers
    public var capabilities: Set<ModelCapabilities> = []
    public var context: ModelContextLength = .short_8k
    public var temperature_preference: ModelTemperaturePreference = .inherit
    public var temperature_override: Double?

    // can be used when loading model from our server
    // present to user on the top of the editor page
    public var comment: String = ""

    public var removed: Bool = false
    public var modified: Date = .now

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = CloudModel
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(objectId, isPrimary: true, isNotNull: true, isUnique: true)

            BindColumnConstraint(creation, isNotNull: true)
            BindColumnConstraint(modified, isNotNull: true)
            BindColumnConstraint(removed, isNotNull: false, defaultTo: false)

            BindColumnConstraint(model_identifier, isNotNull: true, defaultTo: "")
            BindColumnConstraint(model_list_endpoint, isNotNull: true, defaultTo: "")
            BindColumnConstraint(endpoint, isNotNull: true, defaultTo: "")
            BindColumnConstraint(token, isNotNull: true, defaultTo: "")
            BindColumnConstraint(headers, isNotNull: true, defaultTo: [String: String]())
            BindColumnConstraint(capabilities, isNotNull: true, defaultTo: Set<ModelCapabilities>())
            BindColumnConstraint(context, isNotNull: true, defaultTo: ModelContextLength.short_8k)
            BindColumnConstraint(comment, isNotNull: true, defaultTo: "")
            BindColumnConstraint(temperature_preference, isNotNull: true, defaultTo: ModelTemperaturePreference.inherit)
            BindColumnConstraint(temperature_override, isNotNull: false)

            BindIndex(creation, namedWith: "_creationIndex")
            BindIndex(modified, namedWith: "_modifiedIndex")
        }

        case objectId
        case model_identifier
        case model_list_endpoint
        case creation
        case endpoint
        case token
        case headers
        case capabilities
        case context
        case comment
        case temperature_preference
        case temperature_override

        case removed
        case modified
    }

    public init(
        objectId: String = UUID().uuidString,
        model_identifier: String = "",
        model_list_endpoint: String = "$INFERENCE_ENDPOINT$/../../models",
        creation: Date = .init(),
        endpoint: String = "",
        token: String = "",
        headers: [String: String] = [:],
        context _: ModelContextLength = .medium_64k,
        capabilities: Set<ModelCapabilities> = [],
        comment: String = "",
        temperature_preference: ModelTemperaturePreference = .inherit,
        temperature_override: Double? = nil
    ) {
        self.objectId = objectId
        self.model_identifier = model_identifier
        self.model_list_endpoint = model_list_endpoint
        self.creation = creation
        modified = creation
        self.endpoint = endpoint
        self.token = token
        self.headers = headers
        self.capabilities = capabilities
        self.comment = comment
        self.temperature_preference = temperature_preference
        self.temperature_override = temperature_override
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objectId = try container.decodeIfPresent(String.self, forKey: .objectId) ?? UUID().uuidString
        model_identifier = try container.decodeIfPresent(String.self, forKey: .model_identifier) ?? ""
        model_list_endpoint = try container.decodeIfPresent(String.self, forKey: .model_list_endpoint) ?? ""
        creation = try container.decodeIfPresent(Date.self, forKey: .creation) ?? Date()
        modified = try container.decodeIfPresent(Date.self, forKey: .modified) ?? Date()
        endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint) ?? ""
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        capabilities = try container.decodeIfPresent(Set<ModelCapabilities>.self, forKey: .capabilities) ?? []
        context = try container.decodeIfPresent(ModelContextLength.self, forKey: .context) ?? .short_8k
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        temperature_preference = try container.decodeIfPresent(ModelTemperaturePreference.self, forKey: .temperature_preference) ?? .inherit
        temperature_override = try container.decodeIfPresent(Double.self, forKey: .temperature_override)

        removed = try container.decodeIfPresent(Bool.self, forKey: .removed) ?? false
    }

    func markModified() {
        modified = .now
    }

    public static func == (lhs: CloudModel, rhs: CloudModel) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectId)
        hasher.combine(model_identifier)
        hasher.combine(model_list_endpoint)
        hasher.combine(creation)
        hasher.combine(modified)
        hasher.combine(endpoint)
        hasher.combine(token)
        hasher.combine(headers)
        hasher.combine(capabilities)
        hasher.combine(context)
        hasher.combine(comment)
        hasher.combine(temperature_preference)
        hasher.combine(temperature_override)
        hasher.combine(removed)
    }
}

extension ModelTemperaturePreference: ColumnCodable {
    public init?(with value: WCDBSwift.Value) {
        let text = value.stringValue
        self = ModelTemperaturePreference(rawValue: text) ?? .inherit
    }

    public func archivedValue() -> WCDBSwift.Value {
        .init(rawValue)
    }

    public static var columnType: ColumnType {
        .text
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
