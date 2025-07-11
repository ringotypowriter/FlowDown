//
//  MCPService.swift
//  FlowDown
//
//  Created by LiBr on 6/29/25.
//

import Combine
import Foundation
import MCP
import Storage

class MCPService: NSObject {
    static let shared = MCPService()

    // MARK: - Properties

    public let servers: CurrentValueSubject<[ModelContextServer], Never> = .init([])
    private(set) var connections: [ModelContextServer.ID: MCPConnection] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    override private init() {
        super.init()

        updateFromDatabase()

        servers
            .map { $0.filter(\.isEnabled) }
            .removeDuplicates()
            .ensureMainThread()
            .sink { [weak self] enabledServers in
                guard let self else { return }
                Task { await self.updateActiveClients(enabledServers) }
            }
            .store(in: &cancellables)
    }

    @discardableResult
    public func prepareForConversation() async -> [Swift.Error] {
        var errors: [Swift.Error] = .init()
        for (name, connection) in connections {
            do {
                try await connection.connect()
            } catch {
                print("[-] connect to server \(name) failed with \(error.localizedDescription)")
                errors.append(error)
            }
        }
        return errors
    }

    public func insert(_ server: ModelContextServer) {
        sdb.modelContextServerPut(object: server)
        updateFromDatabase()
    }

    public func ensureOrReconnect(_ serverID: ModelContextServer.ID) {
        if let connection = connections[serverID], connection.client != nil {
            return
        }
        guard let server = sdb.modelContextServerWith(serverID) else {
            return
        }
        updateClientStatus(serverID, status: .disconnected)
        Task.detached { await self.connectClient(server) }
    }

    private func updateActiveClients(_ eligibleServers: [ModelContextServer]) async {
        for server in eligibleServers {
            ensureOrReconnect(server.id)
        }
        for (key, value) in connections {
            if !eligibleServers.map(\.id).contains(key) {
                Task.detached { await value.disconnect() }
                connections.removeValue(forKey: key)
                updateClientStatus(key, status: .disconnected)
            }
        }
    }

    private func connectClient(_ config: ModelContextServer) async {
        updateClientStatus(config.id, status: .connecting)
        let connection = connections[config.id] ?? MCPConnection(config: config)
        connections[config.id] = connection
        await attemptConnectionWithRetry(manager: connection, config: config)
    }

    private func updateClientStatus(_ clientId: ModelContextServer.ID, status: ModelContextServer.ConnectionStatus) {
        edit(identifier: clientId) { client in
            client.connectionStatus = status
            if status == .connected {
                client.lastConnected = Date()
            }
        }
    }

    private func attemptConnectionWithRetry(manager: MCPConnection, config: ModelContextServer) async {
        let maxRetries = 3
        let baseDelay: TimeInterval = 1.0

        for attempt in 1 ... maxRetries {
            do {
                try await manager.connect()
                if let client = manager.client {
                    await negotiateCapabilities(client: client, config: config)
                }
                updateClientStatus(config.id, status: .connected)
                return
            } catch {
                if attempt == maxRetries {
                    updateClientStatus(config.id, status: .disconnected)
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(baseDelay * Double(attempt) * 1_000_000_000))
                }
            }
        }
    }

    // MARK: - Capability Negotiation

    private func negotiateCapabilities(client: MCP.Client, config: ModelContextServer) async {
        var discoveredCapabilities: [String] = []

        do {
            let (tools, _) = try await client.listTools()
            if !tools.isEmpty {
                discoveredCapabilities.append("tools")
            }
        } catch {
            print("[-] failed to list tools: \(error.localizedDescription)")
        }
        edit(identifier: config.id) { client in
            client.capabilities = StringArrayCodable(discoveredCapabilities)
        }
    }

    func listServerTools() async -> [MCPTool] {
        let toolInfos = await getAllTools()
        return toolInfos.map { MCPTool(toolInfo: $0, mcpService: self) }
    }

    // MARK: - Database

    func updateFromDatabase() {
        servers.send(sdb.modelContextServerList())
    }

    func create() -> ModelContextServer {
        defer { updateFromDatabase() }
        return sdb.modelContextServerMake()
    }

    func server(with identifier: ModelContextServer.ID?) -> ModelContextServer? {
        guard let identifier else { return nil }
        return sdb.modelContextServerWith(identifier)
    }

    func remove(_ identifier: ModelContextServer.ID) {
        defer { updateFromDatabase() }
        sdb.modelContextServerRemove(identifier: identifier)
    }

    func edit(identifier: ModelContextServer.ID, block: @escaping (inout ModelContextServer) -> Void) {
        defer { updateFromDatabase() }
        sdb.modelContextServerEdit(identifier: identifier, block)
    }
}
