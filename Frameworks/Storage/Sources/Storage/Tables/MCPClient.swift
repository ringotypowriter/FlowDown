//
//  MCPClient.swift
//  Storage
//
//  Created by LiBr on 6/29/25.
//
import Foundation
import WCDBSwift

public final class MCPClient: Identifiable, Codable, TableCodable {
    // 字段
    public var id: Int64 = .init()
    public var name: String = ""
    public var description: String = ""
    public var type: ClientType = .http
    public var endpoint: String = ""
    public var header: String = ""
    public var timeout: Int = 60
    public var isEnabled: Bool = true
    public var toolsEnabled: EnableCodable = .init()
    public var resourcesEnabled: EnableCodable = .init()
    public var templateEnabled: EnableCodable = .init()
    
    // increment
    public var isAutoIncrement: Bool = false // 用于定义是否使用自增的方式插入
    public var lastInsertedRowID: Int64 = 0 // 用于获取自增插入后的主键值

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = MCPClient
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true, isAutoIncrement: true, isUnique: true)
            BindColumnConstraint(name, isNotNull: true, defaultTo: "")
            BindColumnConstraint(description, isNotNull: true, defaultTo: "")
            BindColumnConstraint(type, isNotNull: true, defaultTo: ClientType.http.rawValue)
            BindColumnConstraint(endpoint, isNotNull: true, defaultTo: "")
            BindColumnConstraint(header, isNotNull: true, defaultTo: "")
            BindColumnConstraint(timeout, isNotNull: true, defaultTo: 60)
            BindColumnConstraint(isEnabled, isNotNull: true, defaultTo: true)
            BindColumnConstraint(toolsEnabled, isNotNull: true, defaultTo: MCPClient.EnableCodable())
            BindColumnConstraint(resourcesEnabled, isNotNull: true, defaultTo: MCPClient.EnableCodable())
            BindColumnConstraint(templateEnabled, isNotNull: true, defaultTo:
                MCPClient.EnableCodable())
        }

        case id
        case name
        case description
        case type
        case endpoint
        case header
        case timeout
        case isEnabled
        case toolsEnabled
        case templateEnabled
        case resourcesEnabled
    }
    public init(
        id: Int64 = .init(),
        name: String = "",
        description: String = "",
        type: ClientType = .http,
        endpoint: String = "",
        header: String = "",
        timeout: Int = 60,
        isEnabled: Bool = true,
        toolsEnabled: EnableCodable = .init(),
        resourcesEnabled: EnableCodable = .init(),
        templateEnabled: EnableCodable = .init()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.endpoint = endpoint
        self.header = header
        self.timeout = timeout
        self.isEnabled = isEnabled
        self.toolsEnabled = toolsEnabled
        self.resourcesEnabled = resourcesEnabled
        self.templateEnabled = templateEnabled
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(type)
        hasher.combine(endpoint)
        hasher.combine(header)
        hasher.combine(timeout)
        hasher.combine(isEnabled)
        hasher.combine(toolsEnabled)
        hasher.combine(resourcesEnabled)
        hasher.combine(templateEnabled)
    }
}

extension MCPClient: Equatable {
    public static func == (lhs: MCPClient, rhs: MCPClient) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.type == rhs.type &&
        lhs.endpoint == rhs.endpoint &&
        lhs.header == rhs.header &&
        lhs.timeout == rhs.timeout &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.toolsEnabled == rhs.toolsEnabled &&
        lhs.resourcesEnabled == rhs.resourcesEnabled &&
        lhs.templateEnabled == rhs.templateEnabled
    }
}

extension MCPClient: Hashable {}

// ClientType
public extension MCPClient {
    enum ClientType: String, Codable {
        case http
        case sse
    }
}

// Tools Enable
public extension MCPClient {
    struct EnableCodable: Codable, ColumnCodable, Hashable {
        public init?(with value: WCDBSwift.Value) {
            let data = value.dataValue
            guard let object = try? JSONDecoder().decode(EnableCodable.self, from: data) else {
                return nil
            }
            self = object
        }

        public func archivedValue() -> WCDBSwift.Value {
            let data = try! JSONEncoder().encode(self)
            return .init(data)
        }

        public static var columnType: WCDBSwift.ColumnType {
            .BLOB
        }

        public var value: [String: Bool] = [:]

        public init() {}

        public init(value: [String: Bool]) {
            self.value = value
        }
    }
}
