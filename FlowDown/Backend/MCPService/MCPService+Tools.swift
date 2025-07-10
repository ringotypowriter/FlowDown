//
//  MCPService+Tools.swift
//  FlowDown
//
//  Created by Alan Ye on 7/10/25.
//

import AlertController
import ChatClientKit
import ConfigurableKit
import Foundation
import MCP
import UIKit

// MARK: - MCPService Tools

extension MCPService {
    func listTools(from clientName: String) async throws -> [Tool] {
        guard let client = activeClients[clientName] else {
            throw MCPError.clientNotFound
        }

        guard let config = clients.value.first(where: { $0.name == clientName }),
              config.capabilities.array.contains("tools")
        else {
            throw MCPError.capabilityNotSupported("tools")
        }

        let (tools, _) = try await client.listTools()
        return tools
    }

    func callTool(name: String, arguments: [String: Value]? = nil, from clientName: String) async throws -> (content: [Tool.Content], isError: Bool?) {
        guard let client = activeClients[clientName] else {
            throw MCPError.clientNotFound
        }

        return try await client.callTool(name: name, arguments: arguments)
    }

    func getAllTools() async -> [MCPToolInfo] {
        var allTools: [MCPToolInfo] = []

        for (clientName, _) in activeClients {
            do {
                let tools = try await listTools(from: clientName)
                let toolInfos = tools.map { tool in
                    MCPToolInfo(
                        tool: tool,
                        clientName: clientName
                    )
                }
                allTools.append(contentsOf: toolInfos)
            } catch {
                // Failed to list tools from client
            }
        }

        return allTools
    }
}

// MARK: - MCPToolInfo

struct MCPToolInfo {
    let tool: Tool
    let clientName: String

    var name: String { tool.name }
    var description: String? { tool.description }
    var inputSchema: Value? { tool.inputSchema }
}

// MARK: - MCPTool

class MCPTool: ModelTool {
    let toolInfo: MCPToolInfo
    let mcpService: MCPService

    init(toolInfo: MCPToolInfo, mcpService: MCPService) {
        self.toolInfo = toolInfo
        self.mcpService = mcpService
        super.init()
    }

    override var shortDescription: String {
        toolInfo.description ?? "MCP Tool"
    }

    override var interfaceName: String {
        toolInfo.name
    }

    override var functionName: String {
        toolInfo.name
    }

    override var definition: ChatRequestBody.Tool {
        let parameters = convertMCPSchemaToJSONValues(toolInfo.inputSchema)
        return .function(
            name: toolInfo.name,
            description: toolInfo.description ?? "MCP Tool",
            parameters: parameters,
            strict: false
        )
    }

    override class var controlObject: ConfigurableObject {
        .init(
            icon: "hammer",
            title: "MCP Tools",
            explain: "Tools from connected MCP servers",
            key: "MCP.Tools.Enabled",
            defaultValue: true,
            annotation: .boolean
        )
    }

    override func execute(with input: String, anchorTo view: UIView) async throws -> String {
        let approved = try await requestUserApprovalForToolExecution(view: view)
        guard approved else {
            throw NSError(domain: "MCPTool", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Tool execution cancelled by user",
            ])
        }

        do {
            var arguments: [String: Value]?
            if !input.isEmpty {
                let data = Data(input.utf8)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    arguments = json.compactMapValues { value in
                        convertJSONValueToMCPValue(value)
                    }
                }
            }

            let result = try await mcpService.callTool(
                name: toolInfo.name,
                arguments: arguments,
                from: toolInfo.clientName
            )

            return formatToolResult(result.content, isError: result.isError)

        } catch {
            throw error
        }
    }

    private func formatToolResult(_ contents: [Tool.Content], isError: Bool?) -> String {
        var result = ""

        for content in contents {
            switch content {
            case let .text(text):
                result += text
            case let .image(_, mimeType, _):
                result += "[Image: \(mimeType)]"
            case let .resource(uri, text, _):
                result += "[Resource: \(uri)]"
                if !text.isEmpty {
                    result += "\n\(text)"
                }
            case let .audio(_, mimeType):
                result += "[Audio: \(mimeType)]"
            }
            result += "\n"
        }

        if isError == true {
            result = "Error: \(result)"
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func requestUserApprovalForToolExecution(view: UIView) async throws -> Bool {
        guard let viewController = view.parentViewController else {
            throw NSError(domain: "MCPTool", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot display approval dialog",
            ])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let alert = AlertViewController(
                title: "Execute MCP Tool",
                message: "The model wants to execute '\(toolInfo.name)' from \(toolInfo.clientName). This tool can access external resources.\n\nDescription: \(toolInfo.description ?? "No description available")"
            ) { context in
                context.addAction(title: "Cancel") {
                    context.dispose {
                        continuation.resume(returning: false)
                    }
                }
                context.addAction(title: "Allow", attribute: .dangerous) {
                    context.dispose {
                        continuation.resume(returning: true)
                    }
                }
            }

            viewController.present(alert, animated: true) {
                guard alert.isVisible else {
                    continuation.resume(throwing: NSError(domain: "MCPTool", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to display approval dialog",
                    ]))
                    return
                }
            }
        }
    }
}

// MARK: - Tool Integration

extension MCPService {
    func getMCPTools() async -> [MCPTool] {
        let toolInfos = await getAllTools()
        return toolInfos.map { MCPTool(toolInfo: $0, mcpService: self) }
    }
}

// MARK: - JSON to MCP Value

private extension MCPTool {
    private func convertMCPSchemaToJSONValues(_ mcpSchema: Value?) -> [String: JSONValue] {
        guard let mcpSchema else {
            return ["type": .string("object"), "properties": .object([:]), "additionalProperties": .bool(false)]
        }

        if case let .object(dict) = convertMCPValueToJSONValue(mcpSchema) {
            return dict
        }
        return ["type": .string("object"), "properties": .object([:]), "additionalProperties": .bool(false)]
    }

    private func convertMCPValueToJSONValue(_ value: Value) -> JSONValue {
        switch value {
        case let .string(string):
            .string(string)
        case let .int(int):
            .int(int)
        case let .double(double):
            .double(double)
        case let .bool(bool):
            .bool(bool)
        case let .array(values):
            .array(values.map { convertMCPValueToJSONValue($0) })
        case let .object(dict):
            .object(dict.mapValues { convertMCPValueToJSONValue($0) })
        case .null:
            .null(NSNull())
        case let .data(mimeType: mimeType, _):
            .string("[Data: \(mimeType ?? "unknown")]")
        }
    }

    func convertJSONValueToMCPValue(_ jsonValue: Any) -> Value? {
        switch jsonValue {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if number.isBool {
                return .bool(number.boolValue)
            } else if number.isInteger {
                return .int(number.intValue)
            } else {
                return .double(number.doubleValue)
            }
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let array as [Any]:
            let values = array.compactMap { convertJSONValueToMCPValue($0) }
            return .array(values)
        case let dict as [String: Any]:
            let pairs = dict.compactMapValues { convertJSONValueToMCPValue($0) }
            return .object(pairs)
        case is NSNull:
            return .null
        default:
            return nil
        }
    }
}

private extension NSNumber {
    var isBool: Bool {
        CFBooleanGetTypeID() == CFGetTypeID(self)
    }

    var isInteger: Bool {
        !isBool && floor(doubleValue) == doubleValue
    }
}
