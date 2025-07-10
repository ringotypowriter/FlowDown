//
//  MCPService+Tools.swift
//  FlowDown
//
//  Created by Alan Ye on 7/10/25.
//

import AlertController
import ChatClientKit
import ConfigurableKit
import Foundation
import MCP
import UIKit

// MARK: - MCPService Tools

extension MCPService {
    func listTools(from clientName: String) async throws -> [Tool] {
        guard let client = activeServer[clientName] else {
            throw MCPError.serverDisabled
        }

        guard let config = clients.value.first(where: { $0.name == clientName }),
              config.capabilities.array.contains("tools")
        else {
            throw MCPError.capabilityNotSupported
        }

        let (tools, _) = try await client.listTools()
        return tools
    }

    func callTool(name: String, arguments: [String: Value]? = nil, from clientName: String) async throws -> (content: [Tool.Content], isError: Bool?) {
        guard let client = activeServer[clientName] else {
            throw MCPError.serverDisabled
        }

        return try await client.callTool(name: name, arguments: arguments)
    }

    func getAllTools() async -> [MCPToolInfo] {
        var allTools: [MCPToolInfo] = []

        for (clientName, _) in activeServer {
            do {
                let tools = try await listTools(from: clientName)
                let toolInfos = tools.map { tool in
                    MCPToolInfo(
                        tool: tool,
                        clientName: clientName
                    )
                }
                allTools.append(contentsOf: toolInfos)
            } catch {
                // Failed to list tools from client
            }
        }

        return allTools
    }
}
