//
//  CloudModelThinkingMode.swift
//  Storage
//
//  Created by Willow Zhang on 11/2/25.
//

import Foundation
import WCDBSwift

public enum CloudModelThinkingMode: Equatable, Hashable, Codable {
    case disabled
    case alternateModel(name: String)
    case extraField(key: String, value: Value)

    public enum Value: Equatable, Hashable, Codable {
        case bool(Bool)
        case string(String)
        case dictionary([String: Value])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
            } else if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let dictValue = try? container.decode([String: Value].self) {
                self = .dictionary(dictValue)
            } else {
                self = .dictionary([:])
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .bool(value):
                try container.encode(value)
            case let .string(value):
                try container.encode(value)
            case let .dictionary(value):
                try container.encode(value)
            }
        }
    }
}

public extension CloudModelThinkingMode {
    static var disabledMode: CloudModelThinkingMode { .disabled }

    static var enableThinkingFlag: CloudModelThinkingMode {
        .extraField(key: "enable_thinking", value: .bool(true))
    }

    static var thinkingModeDictionary: CloudModelThinkingMode {
        .extraField(key: "thinking_mode", value: .dictionary(["type": .string("enabled")]))
    }

    static var reasoningDictionary: CloudModelThinkingMode {
        .extraField(key: "reasoning", value: .dictionary(["enabled": .bool(true)]))
    }

    func mergedPayload() -> (overrideModel: String?, body: [String: Any]) {
        switch self {
        case .disabled:
            return (nil, [:])
        case let .alternateModel(name):
            let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return (sanitized.isEmpty ? nil : sanitized, [:])
        case let .extraField(key, value):
            return (nil, [key: value.toJSONObject()])
        }
    }

    var isConfigurable: Bool {
        switch self {
        case .disabled: false
        default: true
        }
    }

    var detailDescription: String.LocalizationValue {
        switch self {
        case .disabled:
            "When disabled, no additional reasoning parameters are sent with the request."
        case .alternateModel:
            "Replace the request model identifier with the alternate name. Recommended for endpoints such as DeepSeek that expect a dedicated model slug."
        case .extraField(key: "enable_thinking", value: .bool):
            "Append 'enable_thinking': true to the body. Works for platforms like Alibaba Bailian that require an explicit reasoning flag."
        case .extraField(key: "thinking_mode", value: .dictionary):
            "Add \"thinking_mode\":{\"type\":\"enabled\"} to enable reasoning on services such as Volcano Engine."
        case .extraField(key: "reasoning", value: .dictionary):
            "Attach \"reasoning\":{\"enabled\":true} for providers that expect a reasoning object in the payload."
        case .extraField:
            "This preset appends custom fields required by the target provider to activate reasoning features."
        }
    }
}

extension CloudModelThinkingMode.Value {
    func toJSONObject() -> Any {
        switch self {
        case let .bool(value):
            return value
        case let .string(value):
            return value
        case let .dictionary(dict):
            var json: [String: Any] = [:]
            for (key, value) in dict {
                json[key] = value.toJSONObject()
            }
            return json
        }
    }
}

extension CloudModelThinkingMode: ColumnCodable {
    public init?(with value: WCDBSwift.Value) {
        let text = value.stringValue
        guard let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(CloudModelThinkingMode.self, from: data)
        else {
            self = .disabled
            return
        }
        self = decoded
    }

    public func archivedValue() -> WCDBSwift.Value {
        guard let data = try? JSONEncoder().encode(self),
              let text = String(data: data, encoding: .utf8)
        else {
            return .init("")
        }
        return .init(text)
    }

    public static var columnType: ColumnType {
        .text
    }
}
