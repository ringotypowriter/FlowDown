//
//  MCPBridge.swift
//  FlowDown
//
//  Created by Alan Ye on 7/10/25.
//

import Foundation
import MCP
import Storage

// MARK: - Connection Manager

class MCPConnection {
    private let config: ModelContextServer
    private(set) var client: MCP.Client?

    init(config: ModelContextServer) {
        self.config = config
    }

    func connect() async throws {
        guard client == nil else { return }
        guard let url = URL(string: config.endpoint),
              let host = url.host,
              !host.isEmpty,
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            throw MCPError.invalidConfiguration
        }
        let client = MCP.Client(name: Bundle.main.bundleIdentifier!, version: AnchorVersion.version)
        print("[*] client connecting \(String(describing: client))")
        let transport = try MCPTransportManager.createTransport(from: config)
        try await client.connect(transport: transport)
        self.client = client
    }

    func disconnect() async {
        print("[*] disposing client \(String(describing: client))")
        await client?.disconnect()
        client = nil
    }

    var isConnected: Bool {
        client != nil
    }
}
