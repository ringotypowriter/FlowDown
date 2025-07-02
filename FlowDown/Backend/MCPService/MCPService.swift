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

// TODO: add resource & template management

// base function:
class MCPService: NSObject {
    static let shared = MCPService()

    public let clientConfigs: CurrentValueSubject<[MCPClient], Never> = .init([])
    private let enabledMCPClientsCfg: CurrentValueSubject<[MCPClient], Never> = .init([]) // listen from clientConfig (filter enabled)
    private var clients: CurrentValueSubject<[String: Client], Never> = .init([:]) // active clients, key is client identifier
    private var toolsCache: CurrentValueSubject<[String: [MCPTool]], Never> = .init([:]) // cache tools for each client
    private var toolsEnable: CurrentValueSubject<[String: Bool], Never> = .init([:]) // tools enabled state, key is tool identifier whyyy is it all @Published??
    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
        setSubscriptions() // workflow: when clientConfig changes, all things changed together.
        loadFromDatabase() // then we can change clientConfig from database XD.
    }

    // MARK: - Initalize

    private func setSubscriptions() {
        // ClientConfig -> EnabledClients
        clientConfigs.map { clients in
            clients.filter(\.isEnabled)
        }
        .sink { [weak self] enabledClients in
            self?.enabledMCPClientsCfg.send(enabledClients)
            print("[+] Enabled MCP Clients: \(enabledClients.map(\.name))")
        }
        .store(in: &cancellables)
        // EnabledClients -> (create active clients)
        enabledMCPClientsCfg.sink { [weak self] enabledClients in
            self?.createActiveClient(enabledClients: enabledClients)
        }
        .store(in: &cancellables)
        // active clients -> toolsCache.
        clients.sink { [weak self] clients in
            guard let self else { return }
            Task {
                var nTC = [String: [MCPTool]]() // new tool cache
                await withTaskGroup(of: (String, [MCPTool]?).self) { group in
                    for (idx, client) in clients {
                        // assert is all connected here.
                        group.addTask {
                            do {
                                let (tools, _) = try await client.listTools()
                                let mcpTools = tools.map { tool in
                                    MCPTool(tool: tool, client: client)
                                }
                                return (idx, mcpTools)
                            } catch {
                                print("[-] Failed to fetch tools for client \(idx): \(error)")
                                return (idx, nil)
                            }
                        }
                    }
                    for await (idx, tools) in group {
                        if let tools {
                            nTC[idx] = tools
                        }
                    }
                }
                await MainActor.run {
                    self.toolsCache.send(nTC)
                }
            }
        }.store(in: &cancellables)
    }

    private func loadFromDatabase() {
        clientConfigs.send(scanMCPClients())
    }

    // MARK: - Active Clients Management

    private func createActiveClient(enabledClients _: [MCPClient]) {
        // remove disabled, search enabled
    }

    // MARK: - Tools Managemnt
}

// MARK: - Client creation for mcp-swift-sdk

extension MCPService {
//    func createMCPClient(for config: MCPClient) async throws -> Client {
//        switch config.type {
//        case .http:
//
//        case .sse:
//
//        }
//    }
}

// MARK: - MCPClient CRUD

extension MCPService {
    func scanMCPClients() -> [MCPClient] {
        sdb.listMCPClients()
    }

    func newMCPClient() -> MCPClient {
        let client = MCPClient()
        sdb.insert(object: client)
        defer { clientConfigs.send(scanMCPClients()) }
        return client
    }

    func insertMCPClient(profile: MCPClient) {
        sdb.insert(object: profile)
        clientConfigs.send(scanMCPClients())
    }

    func McpClient(identifier: MCPClient.ID?) -> MCPClient? {
        guard let identifier else { return nil }
        return sdb.mcpClient(identifier: identifier)
    }

    func removeClient(identifier: MCPClient.ID) {
        sdb.remove(mcpIdentifier: identifier)
        clientConfigs.send(scanMCPClients())
    }

    func editClient(identifier: MCPClient.ID?, block: @escaping (inout MCPClient) -> Void) {
        guard let identifier else { return }
        sdb.insertOrReplace(identifier: identifier, block)
        clientConfigs.send(scanMCPClients())
    }
}
