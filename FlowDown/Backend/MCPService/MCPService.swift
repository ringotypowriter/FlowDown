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
                Task { await self.syncServerConnections(enabledServers) }
            }
            .store(in: &cancellables)
    }

    @discardableResult
    public func prepareForConversation() async -> [Swift.Error] {
        var errors: [Swift.Error] = .init()
        let snapshot = connections // for thread safety
        for (name, connection) in snapshot {
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
        updateServerStatus(serverID, status: .disconnected)
        Task.detached { await self.connectToServer(server) }
    }

    func rebuildConnectionAndInspect(
        serverID: ModelContextServer.ID,
        completion: @escaping (Result<String, Swift.Error>) -> Void
    ) {
        Task.detached {
            do {
                guard let server = self.server(with: serverID) else {
                    throw MCPError.invalidConfiguration
                }
                await self.connections[serverID]?.disconnect()
                self.updateServerStatus(serverID, status: .disconnected)
                let connection: MCPConnection = try await self.connectOnce(server)
                self.connections[serverID] = connection
                if let client = connection.client {
                    await self.negotiateCapabilities(client: client, config: server)
                    let tools = try await client.listTools().tools
                    completion(.success(tools.map(\.name).joined(separator: ", ")))
                } else {
                    assertionFailure()
                }
            } catch {}
        }
    }

    private func syncServerConnections(_ eligibleServers: [ModelContextServer]) async {
        for server in eligibleServers {
            ensureOrReconnect(server.id)
        }
        for (key, value) in connections {
            if !eligibleServers.map(\.id).contains(key) {
                Task.detached { await value.disconnect() }
                connections.removeValue(forKey: key)
                updateServerStatus(key, status: .disconnected)
            }
        }
    }

    private func connectToServer(_ config: ModelContextServer) async {
        updateServerStatus(config.id, status: .connecting)
        let connection = try? await connectOnce(config)
        connections[config.id] = connection
    }

    private func updateServerStatus(_ clientId: ModelContextServer.ID, status: ModelContextServer.ConnectionStatus) {
        edit(identifier: clientId) { client in
            client.connectionStatus = status
            if status == .connected {
                client.lastConnected = Date()
            }
        }
    }

    private func connectOnce(_ config: ModelContextServer) async throws -> MCPConnection {
        let connection = MCPConnection(config: config)
        try await connection.connect()
        if let client = connection.client {
            await negotiateCapabilities(client: client, config: config)
        } else {
            assertionFailure()
        }
        updateServerStatus(config.id, status: .connected)
        return connection
    }

    private func attemptConnectionWithRetry(config: ModelContextServer) async {
        let maxRetries = 3
        let baseDelay: TimeInterval = 1.0

        for attempt in 1 ... maxRetries {
            do {
                print("[+] connecting to server \(config.id) (attempt \(attempt))")
                let connection = try await connectOnce(config)
                connections[config.id] = connection
                print("[+] successfully connected to server \(config.id)")
                updateServerStatus(config.id, status: .connected)
                return
            } catch {
                if attempt == maxRetries {
                    updateServerStatus(config.id, status: .disconnected)
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
