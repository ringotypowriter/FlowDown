//
//  MCPService+Client.swift
//  FlowDown
//
//  Created by LiBr on 6/30/25.
//

import MCP
import Storage

class McpClient {
    private var client: Client?
    private var properties: MCPClient?
    public var id: MCPClient.ID {
        properties?.id ?? .init()
    }

    init(properties: MCPClient) {
        self.properties = properties
        client = Client(
            name: properties.name,
            version: "1.0.0",
        )
    }
}
