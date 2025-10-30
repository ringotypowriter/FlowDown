//
//  Created by ktiays on 2025/2/12.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Foundation
import RegexBuilder
import ServerEvent
import Tokenizers

open class RemoteChatClient: ChatService {
    private let session = URLSession.shared

    /// The ID of the model to use.
    ///
    /// The required section should be in alphabetical order.
    public let model: String
    public var baseURL: String?
    public var path: String?
    public var apiKey: String?

    public enum Error: Swift.Error {
        case invalidURL
        case invalidApiKey
        case invalidData
    }

    public var collectedErrors: String?

    public var additionalHeaders: [String: String] = [:]
    public var additionalField: [String: Any] = [:]

    public init(
        model: String,
        baseURL: String? = nil,
        path: String? = nil,
        apiKey: String? = nil,
        additionalHeaders: [String: String] = [:],
        additionalBodyField: [String: Any] = [:]
    ) {
        self.model = model
        self.baseURL = baseURL
        self.path = path
        self.apiKey = apiKey
        self.additionalHeaders = additionalHeaders
        additionalField = additionalBodyField
    }

    public func chatCompletionRequest(body: ChatRequestBody) async throws -> ChatResponseBody {
        let model = model
        logger.info("starting non-streaming request to model: \(model) with \(body.messages.count) messages")
        let startTime = Date()
        var body = body
        body.model = model
        body.stream = false
        body.streamOptions = nil
        let request = try request(for: body, additionalField: additionalField)
        let (data, _) = try await session.data(for: request)
        logger.debug("received response data: \(data.count) bytes")
        var response = try JSONDecoder().decode(ChatResponseBody.self, from: data)
        response.choices = response.choices.map { choice in
            var choice = choice
            choice.message = extractReasoningContent(from: choice.message)
            return choice
        }
        let duration = Date().timeIntervalSince(startTime)
        let contentLength = response.choices.first?.message.content?.count ?? 0
        logger.info("completed non-streaming request in \(String(format: "%.2f", duration))s, content length: \(contentLength)")
        return response
    }

    private func processReasoningContent(
        _ content: [String],
        _ reasoningContent: [String],
        _ isInsideReasoningContent: inout Bool,
        _ response: inout ChatCompletionChunk
    ) {
        // now we can decode <think> and </think> tag for that purpose
        // transfer all content to buffer, and begin our process
        let bufferContent = content.joined() // 将内容数组合并为单个字符串
        assert(reasoningContent.isEmpty)

        if !isInsideReasoningContent {
            if let range = bufferContent.range(of: REASONING_START_TOKEN) {
                let beforeReasoning = String(bufferContent[..<range.lowerBound])
                    .trimmingCharactersFromEnd(in: .whitespacesAndNewlines)
                let afterReasoningBegin = String(bufferContent[range.upperBound...])
                    .trimmingCharactersFromStart(in: .whitespacesAndNewlines)

                // 检查同一块内容中是否有结束标记
                if let endRange = afterReasoningBegin.range(of: REASONING_END_TOKEN) {
                    // 有开始也有结束标记 - 完整的推理块
                    let reasoningText = String(afterReasoningBegin[..<endRange.lowerBound])
                        .trimmingCharactersFromEnd(in: .whitespacesAndNewlines)
                    let remainingText = String(afterReasoningBegin[endRange.upperBound...])
                        .trimmingCharactersFromStart(in: .whitespacesAndNewlines)

                    // 更新响应数据
                    var delta = [ChatCompletionChunk.Choice.Delta]()
                    if !beforeReasoning.isEmpty {
                        delta.append(.init(content: beforeReasoning))
                    }
                    if !reasoningText.isEmpty {
                        delta.append(.init(reasoningContent: reasoningText))
                    }
                    if !remainingText.isEmpty {
                        delta.append(.init(content: remainingText))
                    }
                    response = .init(choices: delta.map { .init(delta: $0) })
                } else {
                    // 有开始标记但没有结束标记 - 进入推理内容
                    isInsideReasoningContent = true
                    var delta = [ChatCompletionChunk.Choice.Delta]()
                    if !beforeReasoning.isEmpty {
                        delta.append(.init(content: beforeReasoning))
                    }
                    if !afterReasoningBegin.isEmpty {
                        delta.append(.init(reasoningContent: afterReasoningBegin))
                    }
                    response = .init(choices: delta.map { .init(delta: $0) })
                    // 如果刚好在 </think> 前面截断了 那就只有服务器知道要不要 cut 了
                    // UI 上面可以处理一下
                }
            }
        } else {
            // 我们已经在推理内容中，检查是否有结束标记
            if let range = bufferContent.range(of: REASONING_END_TOKEN) {
                // 找到结束标记 - 退出推理模式
                isInsideReasoningContent = false

                let reasoningText = String(bufferContent[..<range.lowerBound])
                    .trimmingCharactersFromEnd(in: .whitespacesAndNewlines)
                let remainingText = String(bufferContent[range.upperBound...])
                    .trimmingCharactersFromStart(in: .whitespacesAndNewlines)

                // 更新响应数据
                response = .init(choices: [
                    .init(delta: .init(reasoningContent: reasoningText)),
                    .init(delta: .init(content: remainingText)),
                ])
            } else {
                // 仍在推理内容中
                response = .init(choices: [.init(delta: .init(
                    reasoningContent: bufferContent
                ))])
            }
        }
    }

    public func streamingChatCompletionRequest(
        body: ChatRequestBody
    ) async throws -> AnyAsyncSequence<ChatServiceStreamObject> {
        let model = model
        var body = body
        body.model = model
        body.stream = true

        // streamOptions is not supported when running up on cohere api
        // body.streamOptions = .init(includeUsage: true)
        let request = try request(for: body, additionalField: additionalField)
        logger.info("starting streaming request to model: \(model) with \(body.messages.count) messages, temperature: \(body.temperature ?? 1.0)")

        let stream = AsyncStream<ChatServiceStreamObject> { continuation in
            Task.detached {
                // Extracts or preserves the reasoning content within a `ChoiceMessage`.

                var canDecodeReasoningContent = true
                var isInsideReasoningContent = false
                let toolCallCollector: ToolCallCollector = .init()
                var chunkCount = 0
                var totalContentLength = 0

                let eventSource = EventSource()
                let dataTask = eventSource.dataTask(for: request)

                for await event in dataTask.events() {
                    switch event {
                    case .open:
                        logger.info("connection was opened.")
                    case let .error(error):
                        logger.error("received an error: \(error)")
                        self.collect(error: error)
                    case let .event(event):
                        guard let data = event.data?.data(using: .utf8) else {
                            continue
                        }
                        if let text = String(data: data, encoding: .utf8) {
                            if text.lowercased() == "[DONE]".lowercased() {
                                logger.debug("received done from upstream")
                                continue
                            }
                        }
                        do {
                            var response = try JSONDecoder().decode(ChatCompletionChunk.self, from: data)

                            // Extract reasoning content from API (if any)
                            let reasoningContent = [
                                response.choices.map(\.delta).compactMap(\.reasoning),
                                response.choices.map(\.delta).compactMap(\.reasoningContent),
                            ].flatMap(\.self).filter { !$0.isEmpty }

                            // If API provides non-empty reasoning content, it has native support
                            if canDecodeReasoningContent, !reasoningContent.isEmpty {
                                canDecodeReasoningContent = false
                            }

                            // Only process <think> tags if API doesn't have native reasoning support
                            if canDecodeReasoningContent {
                                let content = response.choices.map(\.delta).compactMap(\.content)
                                self.processReasoningContent(content, [], &isInsideReasoningContent, &response)
                            }

                            for delta in response.choices {
                                for toolDelta in delta.delta.toolCalls ?? [] {
                                    toolCallCollector.submit(delta: toolDelta)
                                }
                                if let content = delta.delta.content {
                                    totalContentLength += content.count
                                }
                            }

                            chunkCount += 1
                            continuation.yield(.chatCompletionChunk(chunk: response))
                        } catch {
                            if let text = String(data: data, encoding: .utf8) {
                                logger.log("text content associated with this error \(text)")
                            }
                            self.collect(error: error)
                        }
                        if let decodeError = self.extractError(fromInput: data) {
                            self.collect(error: decodeError)
                        }
                    case .closed:
                        logger.info("connection was closed.")
                    }
                }

                toolCallCollector.finalizeCurrentDeltaContent()
                for call in toolCallCollector.pendingRequests {
                    continuation.yield(.tool(call: call))
                }
                logger.info("streaming completed: received \(chunkCount) chunks, total content length: \(totalContentLength), tool calls: \(toolCallCollector.pendingRequests.count)")
                continuation.finish()
            }
        }
        return stream.eraseToAnyAsyncSequence()
    }

    private func collect(error: Swift.Error) {
        if let error = error as? EventSourceError {
            switch error {
            case .undefinedConnectionError:
                collectedErrors = String(localized: "Unable to connect to the server.", bundle: .module)
            case let .connectionError(statusCode, response):
                if let decodedError = extractError(fromInput: response) {
                    collectedErrors = decodedError.localizedDescription
                } else {
                    collectedErrors = String(localized: "Connection error: \(statusCode)", bundle: .module)
                }
            case .alreadyConsumed:
                assertionFailure()
            }
            return
        }
        collectedErrors = error.localizedDescription
        logger.error("collected error: \(error.localizedDescription)")
    }

    private func extractError(fromInput input: Data) -> Swift.Error? {
        let dic = try? JSONSerialization.jsonObject(with: input, options: []) as? [String: Any]
        guard let dic else { return nil }

        let errorDic = dic["error"] as? [String: Any]
        guard let errorDic else { return nil }

        var message = errorDic["message"] as? String ?? String(localized: "Unknown Error", bundle: .module)
        let code = errorDic["code"] as? Int ?? 403

        // check for metadata property, read there if find
        if let metadata = errorDic["metadata"] as? [String: Any],
           let metadataMessage = metadata["message"] as? String
        {
            message += " \(metadataMessage)"
        }

        return NSError(domain: String(localized: "Server Error"), code: code, userInfo: [
            NSLocalizedDescriptionKey: String(localized: "Server returns an error: \(code) \(message)", bundle: .module),
        ])
    }

    private func request(for body: ChatRequestBody, additionalField: [String: Any] = [:]) throws -> URLRequest {
        guard let baseURL else {
            logger.error("invalid base URL")
            throw Error.invalidURL
        }
        guard let apiKey else {
            logger.error("invalid API key")
            throw Error.invalidApiKey
        }

        var path = path ?? ""
        if !path.isEmpty, !path.starts(with: "/") {
            path = "/\(path)"
        }

        guard var urlComponents = URLComponents(string: baseURL),
              let pathComponents = URLComponents(string: path)
        else {
            logger.error("failed to parse URL components from baseURL: \(baseURL), path: \(path)")
            throw Error.invalidURL
        }

        urlComponents.path += pathComponents.path
        urlComponents.queryItems = pathComponents.queryItems

        guard let url = urlComponents.url else {
            logger.error("failed to construct final URL from components")
            throw Error.invalidURL
        }

        logger.debug("constructed request URL: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // additionalHeaders can override default headers including Authorization
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if !additionalField.isEmpty {
            var originalDictionary: [String: Any] = [:]
            if let data = request.httpBody,
               let dic = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                originalDictionary = dic
            }
            for (key, value) in additionalField {
                originalDictionary[key] = value
            }
            request.httpBody = try JSONSerialization.data(
                withJSONObject: originalDictionary,
                options: []
            )
        }

        return request
    }

    /// Extracts or preserves the reasoning content within a `ChoiceMessage`.
    ///
    /// This function inspects the provided `ChoiceMessage` to determine if it already contains
    /// a `reasoningContent` value, indicating compliance with the expected API format. If present,
    /// the original `ChoiceMessage` is returned unchanged. Otherwise, it attempts to extract the text
    /// enclosed within `<think>` and `</think>` tags from the `content` property,
    /// creating a new `ChoiceMessage` with the extracted content assigned to `reasoningContent`.
    ///
    /// - Parameter choice: The `ChoiceMessage` object to process.
    /// - Returns: A `ChoiceMessage` object, either the original if `reasoningContent` exists, or a new one
    ///            with extracted reasoning content if applicable; returns the original if extraction fails.
    private func extractReasoningContent(from choice: ChoiceMessage) -> ChoiceMessage {
        if false
            || choice.reasoning?.isEmpty == false
            || choice.reasoningContent?.isEmpty == false
        {
            // A reasoning content already exists, so return the original choice.
            return choice
        }

        guard let content = choice.content else {
            return choice
        }

        guard let startRange = content.range(of: REASONING_START_TOKEN),
              let endRange = content.range(of: REASONING_END_TOKEN, range: startRange.upperBound ..< content.endIndex)
        else {
            // No reasoning content found, return the original choice.
            return choice
        }

        let reasoningRange = startRange.upperBound ..< endRange.lowerBound

        let leading = content[..<startRange.lowerBound]
        let trailing = content[endRange.upperBound...]

        let reasoningContent = content[reasoningRange]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let remainingContent = String(
            (leading + trailing)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )

        var newChoice = choice
        newChoice.content = remainingContent
        newChoice.reasoningContent = reasoningContent
        return newChoice
    }
}

class ToolCallCollector {
    var functionName: String = ""
    var functionArguments: String = ""
    var currentId: Int?
    var pendingRequests: [ToolCallRequest] = []

    func submit(delta: ChatCompletionChunk.Choice.Delta.ToolCall) {
        guard let function = delta.function else { return }

        if currentId != delta.index { finalizeCurrentDeltaContent() }
        currentId = delta.index

        if let name = function.name, !name.isEmpty {
            functionName.append(name)
        }
        if let arguments = function.arguments {
            functionArguments.append(arguments)
        }
    }

    func finalizeCurrentDeltaContent() {
        guard !functionName.isEmpty || !functionArguments.isEmpty else {
            return
        }
        let call = ToolCallRequest(name: functionName, args: functionArguments)
        logger.debug("tool call finalized: \(call.name) with args: \(call.args)")
        pendingRequests.append(call)
        functionName = ""
        functionArguments = ""
    }
}
