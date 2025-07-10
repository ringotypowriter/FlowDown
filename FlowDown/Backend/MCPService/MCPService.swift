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

    public let clients: CurrentValueSubject<[ModelContextClient], Never> = .init([])
    var activeClients: [String: MCP.Client] = [:]
    private var connectionManagers: [String: MCPConnectionManager] = [:]
    private var cancellables = Set<AnyCancellable>()

    var enabledClients: [ModelContextClient] {
        clients.value.filter(\.isEnabled)
    }

    // MARK: - Initialization

    override private init() {
        super.init()

        updateFromDatabase()

        clients
            .map { $0.filter(\.isEnabled) }
            .removeDuplicates()
            .ensureMainThread()
            .sink { [weak self] enabledMCPClients in
                guard let self else { return }
                Task {
                    await self.updateActiveClients(enabledMCPClients)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Client

    private func updateActiveClients(_ enabledClients: [ModelContextClient]) async {
        let enabledClientNames = Set(enabledClients.map(\.name))

        for clientName in connectionManagers.keys {
            if !enabledClientNames.contains(clientName) {
                await disconnectClient(clientName)
            }
        }

        for client in enabledClients {
            if connectionManagers[client.name] == nil {
                await connectClient(client)
            }
        }
    }

    private func connectClient(_ config: ModelContextClient) async {
        updateClientStatus(config.id, status: .connecting)

        let connectionManager = MCPConnectionManager(config: config)
        connectionManagers[config.name] = connectionManager

        await attemptConnectionWithRetry(manager: connectionManager, config: config)
    }

    private func disconnectClient(_ clientName: String) async {
        if let manager = connectionManagers[clientName] {
            await manager.disconnect()
            connectionManagers.removeValue(forKey: clientName)
        }

        activeClients.removeValue(forKey: clientName)

        if let config = clients.value.first(where: { $0.name == clientName }) {
            updateClientStatus(config.id, status: .disconnected)
        }
    }

    private func updateClientStatus(_ clientId: ModelContextClient.ID, status: ModelContextClient.ConnectionStatus) {
        edit(identifier: clientId) { client in
            client.connectionStatus = status
            if status == .connected {
                client.lastConnected = Date()
            }
        }
    }

    // MARK: - Connection Retry

    private func attemptConnectionWithRetry(manager: MCPConnectionManager, config: ModelContextClient) async {
        let maxRetries = 3
        let baseDelay: TimeInterval = 1.0

        for attempt in 1 ... maxRetries {
            do {
                try await manager.connect()
                if let client = manager.connectedClient {
                    activeClients[config.name] = client
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

    private func negotiateCapabilities(client: MCP.Client, config: ModelContextClient) async {
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

    // MARK: - Database

    func updateFromDatabase() {
        clients.send(sdb.modelContextClientList())
    }

    func create() -> ModelContextClient {
        defer { updateFromDatabase() }
        return sdb.modelContextClientMake()
    }

    func client(with identifier: ModelContextClient.ID?) -> ModelContextClient? {
        guard let identifier else { return nil }
        return sdb.modelContextClientWith(identifier)
    }

    func remove(_ identifier: ModelContextClient.ID) {
        defer { updateFromDatabase() }
        sdb.modelContextClientRemove(identifier: identifier)
    }

    func edit(identifier: ModelContextClient.ID, block: @escaping (inout ModelContextClient) -> Void) {
        defer { updateFromDatabase() }
        sdb.modelContextClientEdit(identifier: identifier, block)
    }

    // MARK: - Connection

    func isClientConnected(_ clientName: String) -> Bool {
        connectionManagers[clientName]?.isConnected ?? false
    }

    func reconnectClient(_ clientName: String) async {
        if let manager = connectionManagers[clientName] {
            try? await manager.connect()
        }
    }
}
