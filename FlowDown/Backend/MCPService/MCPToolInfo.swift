//
//  MCPToolInfo.swift
//  FlowDown
//
//  Created by 秋星桥 on 7/10/25.
//

import Foundation
import MCP

struct MCPToolInfo {
    let tool: Tool
    let clientName: String

    var name: String { tool.name }
    var description: String? { tool.description }
    var inputSchema: Value? { tool.inputSchema }
}
