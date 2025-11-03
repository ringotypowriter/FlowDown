//
//  CloudModelThinkingMode+Display.swift
//  FlowDown
//
//  Created by Willow Zhang on 11/2/25.
//

import Foundation
import Storage

extension CloudModelThinkingMode {
    var displayTitle: String {
        switch self {
        case .disabled:
            return String(localized: "Disabled")
        case let .alternateModel(name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return String(localized: "Alternate Model")
            }
            return String(format: String(localized: "Alternate Model · %@"), trimmed)
        case let .extraField(key, _):
            switch key {
            case "enable_thinking":
                return String(localized: "Enable Thinking Flag")
            case "thinking_mode":
                return String(localized: "Thinking Mode Payload")
            case "reasoning":
                return String(localized: "Reasoning Payload")
            default:
                return key
            }
        }
    }

    var menuIconSystemName: String? {
        switch self {
        case .disabled:
            "xmark.circle"
        case .alternateModel:
            "1.circle"
        case .extraField(key: "enable_thinking", value: .bool):
            "2.circle"
        case .extraField(key: "thinking_mode", value: .dictionary):
            "3.circle"
        case .extraField(key: "reasoning", value: .dictionary):
            "4.circle"
        case .extraField:
            "questionmark.circle"
        }
    }
}
