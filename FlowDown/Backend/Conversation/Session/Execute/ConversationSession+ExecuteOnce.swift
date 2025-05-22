//
//  ConversationSession+ExecuteOnce.swift
//  FlowDown
//
//  Created by 秋星桥 on 3/19/25.
//

import ChatClientKit
import Foundation
import Storage

extension ConversationSession {
    func doMainInferenceOnce(
        _ currentMessageListView: MessageListView,
        _ modelID: ModelManager.ModelIdentifier,
        _ requestMessages: inout [ChatRequestBody.Message],
        _ tools: [ChatRequestBody.Tool]?,
        _ webSearchResults: [Message.WebSearchStatus.SearchResult],
        _ modelWillExecuteTools: Bool
    ) async throws -> Bool {
        await requestUpdate(view: currentMessageListView)
        await currentMessageListView.loading()

        let message = appendNewMessage(role: .assistant)
        let stream = try await ModelManager.shared.streamingInfer(
            with: modelID,
            input: requestMessages,
            tools: tools
        )
        defer { self.stopThinking(for: message.id) }

        var pendingToolCalls: [ToolCallRequest] = []

        for try await resp in stream {
            let reasoningContent = resp.reasoningContent
            let content = resp.content
            pendingToolCalls.append(contentsOf: resp.toolCallRequests)
            message.reasoningContent = reasoningContent
            message.document = content
            if !content.isEmpty {
                stopThinking(for: message.id)
            } else if !reasoningContent.isEmpty {
                startThinking(for: message.id)
            }
            await requestUpdate(view: currentMessageListView)
        }
        stopThinking(for: message.id)
        await requestUpdate(view: currentMessageListView)

        if !message.document.isEmpty {
            logger.info("\(message.document)")
            message.document = fixWebReferenceIfNeeded(in: message.document, with: webSearchResults)
        }
        if !message.reasoningContent.isEmpty, message.document.isEmpty {
            message.document = String(localized: "Thinking finished without output any content.")
        }

        await requestUpdate(view: currentMessageListView)
        requestMessages.append(
            .assistant(
                content: .text(message.document),
                toolCalls: pendingToolCalls.map {
                    .init(id: $0.id.uuidString, function: .init(name: $0.name, arguments: $0.args))
                }
            )
        )

        if message.document.isEmpty, message.reasoningContent.isEmpty, !modelWillExecuteTools {
            throw NSError(
                domain: "Inference Service",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "No response from model."),
                ]
            )
        }

        // 请求结束 如果没有启用工具调用就结束
        guard modelWillExecuteTools else {
            assert(pendingToolCalls.isEmpty)
            return false
        }
        pendingToolCalls = pendingToolCalls.filter {
            $0.name.lowercased() != MTWaitForNextRound().functionName.lowercased()
        }
        guard !pendingToolCalls.isEmpty else { return false }
        assert(modelWillExecuteTools)

        await requestUpdate(view: currentMessageListView)
        await currentMessageListView.loading(with: String(localized: "Utilizing tool call"))

        var atLeastOneToolHasBeenProcessed = false

        for request in pendingToolCalls {
            guard let tool = ModelToolsManager.shared.tool(for: request) else {
                throw NSError(
                    domain: "Tool Error",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: String(localized: "Unable to process tool request with name: \(request.name)"),
                    ]
                )
            }
            await currentMessageListView.loading(with: String(localized: "Utilizing tool: \(tool.interfaceName)"))
            let performResult: String
            var isSuccessful = false
            do {
                // 等待一秒以避免过快执行任务用户还没看到内容
                try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                guard let result = ModelToolsManager.shared.perform(
                    withTool: tool,
                    parms: request.args,
                    anchorTo: currentMessageListView
                ) else { continue }
                performResult = result
                isSuccessful = true
            } catch {
                if let displayableError = error as? DisplayableError {
                    performResult = displayableError.displayableText
                } else {
                    performResult = error.localizedDescription
                }
            }

            atLeastOneToolHasBeenProcessed = true
            await requestUpdate(view: currentMessageListView)

            let toolMessage = appendNewMessage(role: .toolHint)
            toolMessage.toolStatus = .init(name: tool.interfaceName, state: isSuccessful ? 1 : 0, message: performResult)
            await requestUpdate(view: currentMessageListView)

            // tool call done this round, and not using tool call content for capbilities issues
            requestMessages.append(.tool(content: .text(performResult), toolCallID: request.id.uuidString))
        }

        await requestUpdate(view: currentMessageListView)

        guard atLeastOneToolHasBeenProcessed else { return false }
        return true
    }
}
