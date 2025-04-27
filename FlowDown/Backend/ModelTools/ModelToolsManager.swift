//
//  ModelToolsManager.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/27/25.
//

import ChatClientKit
import Foundation

class ModelToolsManager {
    static let shared = ModelToolsManager()

    private let tools: [ModelTool]

    private init() {
        tools = [
            MTWaitForNextRound(),

            MTAddCalendarTool(),
            MTQueryCalendarTool(),

            MTWebScraperTool(),

            MTLocationTool(),

            MTURLTool(),
        ]

        #if DEBUG
            var registeredToolNames: Set<String> = []
        #endif

        for tool in tools {
            print("[*] registering tool: \(tool.functionName)")
            #if DEBUG
                assert(registeredToolNames.insert(tool.functionName).inserted)
            #endif
            if tool is MTWaitForNextRound { continue }
        }
    }

    var enabledTools: [ModelTool] {
        tools.filter { tool in
            if tool is MTWaitForNextRound { return true }
            return tool.isEnabled
        }
    }

    var configurableTools: [ModelTool] {
        tools.filter { tool in
            if tool is MTWaitForNextRound { return false }
            return true
        }
    }

    func tool(for request: ToolCallRequest) -> ModelTool? {
        print("[*] finding tool call with function name \(request.name)")
        return enabledTools.first {
            $0.functionName.lowercased() == request.name.lowercased()
        }
    }

    nonisolated
    func perform(withTool tool: ModelTool, parms: String, anchorTo view: UIView) async throws -> String? {
        assert(!Thread.isMainThread)
        return try await tool.execute(with: parms, anchorTo: view)
    }
}
