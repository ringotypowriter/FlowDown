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

    public let clients: CurrentValueSubject<[ModelContextClient], Never> = .init([])

    var enabledClients: [ModelContextClient] {
        clients.value.filter(\.isEnabled)
    }

    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()

        updateFromDatabase()
        
        clients
            .map { $0.filter(\.isEnabled) }
            .removeDuplicates()
            .ensureMainThread()
            .sink { [weak self] enabledMCPClients in
                guard let self else { return }
                detectUseableTools(enabledClients: enabledMCPClients)
            }
            .store(in: &cancellables)
    }

    private func detectUseableTools(enabledClients _: [ModelContextClient]) {
        // remove disabled, search enabled
    }

    // MARK: - Tools Managemnt
}

// MARK: - MCPClient CRUD

extension MCPService {
    private func updateFromDatabase() {
        clients.send(sdb.modelContextClientList())
    }

    func create() -> ModelContextClient {
        defer { updateFromDatabase() }
        fatalError("not impl")
    }

    func insert(profile: ModelContextClient) {
        defer { updateFromDatabase() }
        fatalError("not impl")
    }

    func client(with identifier: ModelContextClient.ID?) -> ModelContextClient? {
        fatalError("not impl")
    }

    func remove(identifier: ModelContextClient.ID) {
        fatalError("not impl")
    }

    func edit(identifier: ModelContextClient.ID?, block: @escaping (inout ModelContextClient) -> Void) {
        fatalError("not impl")
    }
}
