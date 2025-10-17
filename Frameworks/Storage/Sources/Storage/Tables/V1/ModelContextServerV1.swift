//
//  ModelContextServer.swift
//  Storage
//
//  Created by LiBr on 6/29/25.
//
import Foundation
import WCDBSwift

public final class ModelContextServerV1: Identifiable, Codable, TableNamed, TableCodable {
    public static let tableName: String = "ModelContextServer"

    public var id: String = UUID().uuidString
    public var name: String = ""
    public var comment: String = ""
    public var type: ModelContextServer.ServerType = .http
    public var endpoint: String = ""
    public var header: String = ""
    public var timeout: Int = 60
    public var isEnabled: Bool = true
    public var toolsEnabled: ModelContextServer.EnableCodable = .init()
    public var resourcesEnabled: ModelContextServer.EnableCodable = .init()
    public var templateEnabled: ModelContextServer.EnableCodable = .init()
    public var lastConnected: Date?
    public var connectionStatus: ModelContextServer.ConnectionStatus = .disconnected
    public var capabilities: StringArrayCodable = .init([])

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = ModelContextServerV1
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true, defaultTo: UUID().uuidString)
            BindColumnConstraint(name, isNotNull: true, defaultTo: "")
            BindColumnConstraint(comment, isNotNull: true, defaultTo: "")
            BindColumnConstraint(type, isNotNull: true, defaultTo: ModelContextServer.ServerType.http.rawValue)
            BindColumnConstraint(endpoint, isNotNull: true, defaultTo: "")
            BindColumnConstraint(header, isNotNull: true, defaultTo: "")
            BindColumnConstraint(timeout, isNotNull: true, defaultTo: 60)
            BindColumnConstraint(isEnabled, isNotNull: true, defaultTo: true)
            BindColumnConstraint(toolsEnabled, isNotNull: true, defaultTo: ModelContextServer.EnableCodable())
            BindColumnConstraint(resourcesEnabled, isNotNull: true, defaultTo: ModelContextServer.EnableCodable())
            BindColumnConstraint(templateEnabled, isNotNull: true, defaultTo: ModelContextServer.EnableCodable())
            BindColumnConstraint(lastConnected, isNotNull: false)
            BindColumnConstraint(connectionStatus, isNotNull: true, defaultTo: ModelContextServer.ConnectionStatus.disconnected.rawValue)
            BindColumnConstraint(capabilities, isNotNull: true, defaultTo: StringArrayCodable([]))
        }

        case id
        case name
        case comment
        case type
        case endpoint
        case header
        case timeout
        case isEnabled
        case toolsEnabled
        case templateEnabled
        case resourcesEnabled
        case lastConnected
        case connectionStatus
        case capabilities
    }

    public init(
        id: String = UUID().uuidString,
        name: String = "",
        comment: String = "",
        type: ModelContextServer.ServerType = .http,
        endpoint: String = "",
        header: String = "",
        timeout: Int = 60,
        isEnabled: Bool = true,
        toolsEnabled: ModelContextServer.EnableCodable = .init(),
        resourcesEnabled: ModelContextServer.EnableCodable = .init(),
        templateEnabled: ModelContextServer.EnableCodable = .init(),
        lastConnected: Date? = nil,
        connectionStatus: ModelContextServer.ConnectionStatus = .disconnected,
        capabilities: StringArrayCodable = StringArrayCodable([])
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.type = type
        self.endpoint = endpoint
        self.header = header
        self.timeout = timeout
        self.isEnabled = isEnabled
        self.toolsEnabled = toolsEnabled
        self.resourcesEnabled = resourcesEnabled
        self.templateEnabled = templateEnabled
        self.lastConnected = lastConnected
        self.connectionStatus = connectionStatus
        self.capabilities = capabilities
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ModelContextServerV1: Equatable {
    public static func == (lhs: ModelContextServerV1, rhs: ModelContextServerV1) -> Bool {
        lhs.id == rhs.id
    }
}

extension ModelContextServerV1: Hashable {}
