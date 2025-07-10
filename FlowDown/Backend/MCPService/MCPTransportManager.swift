//
//  MCPTransportManager.swift
//  FlowDown
//
//  Created by Alan Ye on 7/10/25.
//

import Foundation
import MCP
import Storage

class MCPTransportManager {
    static func createTransport(from client: ModelContextClient) throws -> HTTPClientTransport {
        guard let url = URL(string: client.endpoint) else {
            throw MCPError.invalidEndpoint
        }

        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            throw MCPError.invalidHTTPScheme
        }

        return HTTPClientTransport(endpoint: url)
    }
}
