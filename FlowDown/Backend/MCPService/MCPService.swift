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
    private(set) var connections: [String: MCPConnection] = [:]
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

    // MARK: - Client

    private func updateActiveClients(_ eligibleServers: [ModelContextServer]) async {
        let enabledClientNames = Set(eligibleServers.map(\.name))

        for clientName in connections.keys {
            if !enabledClientNames.contains(clientName) {
                await disconnectClient(clientName)
                connections.removeValue(forKey: clientName)
            }
        }

        for client in eligibleServers {
            if connections[client.name] == nil {
                await connectClient(client)
            }
        }
    }

    private func connectClient(_ config: ModelContextServer) async {
        updateClientStatus(config.id, status: .connecting)

        let connectionManager = MCPConnection(config: config)
        connections[config.name] = connectionManager

        await attemptConnectionWithRetry(manager: connectionManager, config: config)
    }

    private func disconnectClient(_ clientName: String) async {
        if let manager = connections[clientName] {
            await manager.disconnect()
            connections.removeValue(forKey: clientName)
        }

        if let config = servers.value.first(where: { $0.name == clientName }) {
            updateClientStatus(config.id, status: .disconnected)
        }
    }

    private func updateClientStatus(_ clientId: ModelContextServer.ID, status: ModelContextServer.ConnectionStatus) {
        edit(identifier: clientId) { client in
            client.connectionStatus = status
            if status == .connected {
                client.lastConnected = Date()
            }
        }
    }

    // MARK: - Connection Retry

    private func attemptConnectionWithRetry(manager: MCPConnection, config: ModelContextServer) async {
        let maxRetries = 5
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
            // Tools not available
        }
        edit(identifier: config.id) { client in
            client.capabilities = StringArrayCodable(discoveredCapabilities)
        }
    }

    func getMCPTools() async -> [MCPTool] {
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

    // MARK: - Connection

    func isClientConnected(_ clientName: String) -> Bool {
        connections[clientName]?.isConnected ?? false
    }

    func reconnectClient(_ clientName: String) async {
        if let manager = connections[clientName] {
            try? await manager.connect()
        }
    }
}
