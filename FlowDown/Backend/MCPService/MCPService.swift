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
}

extension MCPService {
    private func updateFromDatabase() {
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
}
