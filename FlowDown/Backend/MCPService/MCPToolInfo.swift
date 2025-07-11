//
//  MCPToolInfo.swift
//  FlowDown
//
//  Created by 秋星桥 on 7/10/25.
//

import Foundation
import MCP
import Storage

struct MCPToolInfo {
    let tool: Tool
    let serverID: ModelContextServer.ID

    var name: String { tool.name }
    var description: String? { tool.description }
    var inputSchema: Value? { tool.inputSchema }
}
