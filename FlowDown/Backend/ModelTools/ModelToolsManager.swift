//
//  ModelToolsManager.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/27/25.
//

import AlertController
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

    func perform(withTool tool: ModelTool, parms: String, anchorTo view: UIView) -> String? {
        assert(!Thread.isMainThread)

        var ans = String(localized: "Execute tool call timed out")
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            let alert = AlertViewController(
                title: String(localized: "Tool Call"),
                message: String(localized: "Your model is calling a tool: \(tool.interfaceName)"),
            ) { context in
                context.addAction(title: String(localized: "Cancel")) {
                    context.dispose {
                        sem.signal()
                    }
                }
                context.addAction(title: String(localized: "Use Tool"), attribute: .dangerous) {
                    context.dispose {
                        Task {
                            ans = try await tool.execute(with: parms, anchorTo: view)
                            sem.signal()
                        }
                    }
                }
            }
            view.parentViewController?.present(alert, animated: true)
        }
        sem.wait()

        return ans
    }
}
