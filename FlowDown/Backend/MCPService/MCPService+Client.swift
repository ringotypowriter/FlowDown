//
//  MCPService+Client.swift
//  FlowDown
//
//  Created by LiBr on 6/30/25.
//

import MCP
import Storage

class MCPClient {
    private var client: Client?
    private var properties: ModelContextClient?
    public var id: ModelContextClient.ID {
        properties?.id ?? .init()
    }

    init(properties: ModelContextClient) {
        self.properties = properties
        client = Client(
            name: properties.name,
            version: "1.0.0",
        )
    }
}
