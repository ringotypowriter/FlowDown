//
//  MCPConnectionManager.swift
//  FlowDown
//
//  Created by Alan Ye on 7/10/25.
//

import Foundation
import MCP
import Storage

// MARK: - Connection Manager

class MCPConnectionManager {
    private let config: ModelContextClient
    private var client: MCP.Client?

    init(config: ModelContextClient) {
        self.config = config
    }

    func connect() async throws {
        let client = MCP.Client(name: "FlowDown", version: "1.0.0")
        let transport = try MCPTransportManager.createTransport(from: config)

        try await client.connect(transport: transport)
        self.client = client
    }

    func disconnect() async {
        if let client {
            await client.disconnect()
            self.client = nil
        }
    }

    var connectedClient: MCP.Client? {
        client
    }

    var isConnected: Bool {
        client != nil
    }
}
