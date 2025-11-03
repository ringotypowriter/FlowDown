//
//  CloudModelReasoningEffortLevel+Display.swift
//  FlowDown
//
//  Created by Willow Zhang on 11/2/25.
//

import Foundation
import Storage

extension CloudModelReasoningEffortLevel {
    var displayTitle: String {
        switch self {
        case .low:
            String(localized: "Low")
        case .medium:
            String(localized: "Medium")
        case .high:
            String(localized: "High")
        }
    }

    var menuIconSystemName: String {
        switch self {
        case .low:
            "sparkle"
        case .medium:
            "sparkles.2"
        case .high:
            "sparkles"
        }
    }
}
