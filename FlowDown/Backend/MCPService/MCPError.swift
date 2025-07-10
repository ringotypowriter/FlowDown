//
//  MCPError.swift
//  FlowDown
//
//  Created by Alan Ye on 7/10/25.
//

import Foundation

enum MCPError: Swift.Error, LocalizedError, Equatable {
    case invalidEndpoint
    case clientNotFound
    case connectionFailed
    case capabilityNotSupported(String)
    case samplingDenied
    case noViewController
    case noModelAvailable
    case elicitationDenied
    case invalidHTTPScheme

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "Invalid endpoint URL"
        case .clientNotFound:
            "MCP client not found"
        case .connectionFailed:
            "Failed to connect to MCP server"
        case let .capabilityNotSupported(capability):
            "MCP server doesn't support '\(capability)' capability"
        case .samplingDenied:
            "User denied sampling request"
        case .noViewController:
            "Cannot display user interface"
        case .noModelAvailable:
            "No AI model available for sampling"
        case .elicitationDenied:
            "User denied elicitation request"
        case .invalidHTTPScheme:
            "Invalid HTTP scheme. Use http:// or https://"
        }
    }
}
