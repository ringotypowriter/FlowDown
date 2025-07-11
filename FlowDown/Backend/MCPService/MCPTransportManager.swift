//
//  MCPTransportManager.swift
//  FlowDown
//
//  Created by Alan Ye on 7/10/25.
//

import Foundation
import MCP
import Storage

extension ModelContextServer {
    func createTransport() throws -> HTTPClientTransport {
        guard let url = URL(string: endpoint) else {
            throw MCPError.invalidConfiguration
        }

        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            throw MCPError.invalidConfiguration
        }

        return HTTPClientTransport(endpoint: url)
    }
}
