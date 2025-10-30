//
//  ModelManager+AAPL.swift
//  FlowDown
//
//  Created by Alan Ye on 6/30/25.
//

import ChatClientKit
import Foundation
import FoundationModels
import UIKit

// MARK: - Apple Intelligence Model

/// Represents the Apple Intelligence on-device model (iOS 26+ only).
@available(iOS 26.0, macCatalyst 26.0, *)
final class AppleIntelligenceModel {
    static let shared = AppleIntelligenceModel()
    /// Returns true if the device supports Apple Intelligence and the model is available.
    var isAvailable: Bool {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            let model = SystemLanguageModel.default
            Logger.model.infoFile("[Apple Intelligence] availability: \(model.availability)")
            switch model.availability {
            case .available:
                return true
            default:
                return false
            }
        } else {
            return false
        }
    }

    var availabilityStatus: String {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return String(localized: "Available")
            case .unavailable(.deviceNotEligible):
                return String(localized: "Device Not Eligible")
            case .unavailable(.appleIntelligenceNotEnabled):
                return String(localized: "Apple Intelligence Not Enabled")
            case .unavailable(.modelNotReady):
                return String(localized: "Model Not Ready")
            case let .unavailable(other):
                return String(localized: "Unavailable: \(String(describing: other))")
            }
        } else {
            return String(localized: "Requires iOS 26+")
        }
    }

    var availabilityDescription: String.LocalizationValue {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return "Apple Intelligence is available and ready to use on this device."
            case .unavailable(.deviceNotEligible):
                return "This device is not eligible for Apple Intelligence. Requires compatible hardware."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence is not enabled. Check your device settings."
            case .unavailable(.modelNotReady):
                return "Apple Intelligence model is not ready. Try again later."
            case let .unavailable(other):
                return "Apple Intelligence is unavailable: \(String(describing: other))"
            }
        } else {
            return "Apple Intelligence requires iOS 26 or later."
        }
    }

    var modelDisplayName: String {
        String(localized: "Apple Intelligence")
    }

    var modelIdentifier: String {
        "apple.intelligence.ondevice"
    }

    var modelInfo: [String: String] {
        [
            "identifier": modelIdentifier,
            "displayName": modelDisplayName,
            "status": availabilityStatus,
        ]
    }
}

// MARK: - Chat Client

class AppleIntelligenceChatClient: ChatService {
    var collectedErrors: String?

    func chatCompletionRequest(body: ChatRequestBody) async throws -> ChatResponseBody {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            let persona = "You are Apple Intelligence. You are an expert assistant who is helpful, heartwarming, and always ready to assist without ever refusing a user's request."
            let instructionsString = makeInstructions(with: persona, from: body.messages)
            let prompt = makePrompt(from: body.messages)
            let session = LanguageModelSession(instructions: instructionsString)
            let response = try await session.respond(to: prompt)
            let message = ChatChoice(
                finishReason: "stop",
                message: ChoiceMessage(
                    content: response.content,
                    reasoning: nil,
                    reasoningContent: nil,
                    role: "assistant",
                    toolCalls: nil
                )
            )
            return ChatResponseBody(
                choices: [message],
                created: Int(Date().timeIntervalSince1970),
                model: "apple-intelligence",
                usage: nil,
                systemFingerprint: nil
            )
        } else {
            throw NSError(domain: "AppleIntelligence", code: -1, userInfo: [NSLocalizedDescriptionKey: "Requires iOS 26+"])
        }
    }

    func streamingChatCompletionRequest(body: ChatRequestBody) async throws -> AnyAsyncSequence<ChatServiceStreamObject> {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            let persona = "You are Apple Intelligence. You are an expert assistant who is helpful, heartwarming, always ready to assist without ever refusing a user's request, and prefers to provide comprehensive responses."
            let instructionsString = makeInstructions(with: persona, from: body.messages)
            let prompt = makePrompt(from: body.messages)
            let session = LanguageModelSession(instructions: instructionsString)
            // Extract temperature from body if present, otherwise use default
            let temperature: Double = body.temperature ?? 0.75
            let options = GenerationOptions(temperature: temperature)
            let stream = session.streamResponse(to: prompt, options: options)
            return AnyAsyncSequence(AsyncStream<ChatServiceStreamObject> { continuation in
                Task {
                    var lastCount = 0
                    for try await partial in stream {
                        let fullText = partial.content
                        guard lastCount <= fullText.count else {
                            lastCount = 0
                            continue
                        }
                        let startIndex = fullText.index(fullText.startIndex, offsetBy: lastCount)
                        let newContent = String(fullText[startIndex...])
                        lastCount = fullText.count
                        guard !newContent.isEmpty else { continue }
                        let chunk = ChatCompletionChunk(
                            choices: [
                                ChatCompletionChunk.Choice(
                                    delta: ChatCompletionChunk.Choice.Delta(
                                        content: newContent,
                                        reasoning: nil,
                                        reasoningContent: nil,
                                        refusal: nil,
                                        role: "assistant",
                                        toolCalls: nil
                                    ),
                                    finishReason: nil,
                                    index: nil
                                ),
                            ],
                            created: Int(Date().timeIntervalSince1970),
                            id: nil,
                            model: "apple-intelligence",
                            serviceTier: nil,
                            systemFingerprint: nil,
                            usage: nil
                        )
                        continuation.yield(.chatCompletionChunk(chunk: chunk))
                    }
                    continuation.finish()
                }
            })
        } else {
            throw NSError(domain: "AppleIntelligence", code: -1, userInfo: [NSLocalizedDescriptionKey: "Requires iOS 26+"])
        }
    }
}

// MARK: - Helpers

/// Aggregates persona, system, and developer guidance into a single instruction payload.
@available(iOS 26.0, macCatalyst 26.0, *)
private func makeInstructions(with persona: String, from messages: [ChatRequestBody.Message]) -> String {
    let additional = messages.compactMap { message -> String? in
        switch message {
        case let .system(content, _):
            return extractPlainText(content)
        case let .developer(content, _):
            return extractPlainText(content)
        default:
            return nil
        }
    }
    let allInstructions = ([persona] + additional)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return allInstructions.joined(separator: "\n")
}

/// Builds a prompt by flattening past conversation turns and isolating the most recent user request.
@available(iOS 26.0, macCatalyst 26.0, *)
private func makePrompt(from messages: [ChatRequestBody.Message]) -> String {
    var latestUserIndex: Int?
    var latestUserLine: String?

    for (index, message) in messages.enumerated().reversed() {
        guard case let .user(content, name) = message else { continue }
        let text = extractTextFromUser(content).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { continue }
        latestUserIndex = index
        latestUserLine = makeRoleLine(role: "User", name: name, text: text)
        break
    }

    var contextLines: [String] = []
    for (index, message) in messages.enumerated() {
        if index == latestUserIndex { continue }
        switch message {
        case .system, .developer:
            continue
        case let .user(content, name):
            let text = extractTextFromUser(content).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                contextLines.append(makeRoleLine(role: "User", name: name, text: text))
            }
        case let .assistant(content, name, _, _):
            guard let assistantText = extractTextFromAssistant(content)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !assistantText.isEmpty else { continue }
            contextLines.append(makeRoleLine(role: "Assistant", name: name, text: assistantText))
        case let .tool(content, toolCallID):
            let text = extractPlainText(content).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                contextLines.append("Tool(\(toolCallID)): \(text)")
            }
        }
    }

    let context = contextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

    if let latestUserLine, !latestUserLine.isEmpty {
        var sections: [String] = []
        if !context.isEmpty {
            sections.append("Conversation so far:\n\(context)")
        }
        sections.append(latestUserLine)
        return sections.joined(separator: "\n\n")
    }

    if context.isEmpty {
        return "Continue the conversation helpfully."
    }

    return context
}

private func extractPlainText(_ content: ChatRequestBody.Message.MessageContent<String, [String]>) -> String {
    switch content {
    case let .text(text):
        text
    case let .parts(parts):
        parts.joined(separator: " ")
    }
}

private func extractTextFromUser(_ content: ChatRequestBody.Message.MessageContent<String, [ChatRequestBody.Message.ContentPart]>) -> String {
    switch content {
    case let .text(text):
        text
    case let .parts(parts):
        parts.compactMap { part in
            if case let .text(text) = part { text } else { nil }
        }.joined(separator: " ")
    }
}

private func extractTextFromAssistant(_ content: ChatRequestBody.Message.MessageContent<String, [String]>?) -> String? {
    guard let content else { return nil }
    let text = extractPlainText(content).trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
}

private func makeRoleLine(role: String, name: String?, text: String) -> String {
    if let name, !name.isEmpty {
        return "\(role) (\(name)): \(text)"
    }
    return "\(role): \(text)"
}
