//
//  ModelManager+AAPL.swift
//  FlowDown
//
//  Created by Alan Ye on 6/30/25.
//

import ChatClientKit
import Foundation
import UIKit
#if canImport(FoundationModels)
    import FoundationModels
#endif

// MARK: - Apple Intelligence Model

/// Represents the Apple Intelligence on-device model (iOS 26+ only).
@available(iOS 26.0, macCatalyst 26.0, *)
final class AppleIntelligenceModel {
    static let shared = AppleIntelligenceModel()
    /// Returns true if the device supports Apple Intelligence and the model is available.
    var isAvailable: Bool {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            #if canImport(FoundationModels)
                let model = SystemLanguageModel.default
                print("[Apple Intelligence] availability: \(model.availability)")
                switch model.availability {
                case .available:
                    return true
                default:
                    return false
                }
            #else
                return false
            #endif
        } else {
            return false
        }
    }

    var availabilityStatus: String {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            #if canImport(FoundationModels)
                let model = SystemLanguageModel.default
                switch model.availability {
                case .available:
                    return "Available"
                case .unavailable(.deviceNotEligible):
                    return "Device Not Eligible"
                case .unavailable(.appleIntelligenceNotEnabled):
                    return "Apple Intelligence Not Enabled"
                case .unavailable(.modelNotReady):
                    return "Model Not Ready"
                case let .unavailable(other):
                    return "Unavailable: \(other)"
                }
            #else
                return "Not Supported"
            #endif
        } else {
            return "Requires iOS 26+"
        }
    }

    var modelDisplayName: String {
        "Apple Intelligence"
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
        #if canImport(FoundationModels)
            if #available(iOS 26.0, macCatalyst 26.0, *) {
                // instructions (first .system message)
                let persona = "You are Apple Intelligence. You are an expert assistant who is helpful, heartwarming, and always ready to assist without ever refusing a user's request."
                let instructions = [persona] + body.messages.compactMap { message -> String? in
                    if case let .system(content, _) = message {
                        return extractTextFromSystem(content)
                    }
                    return nil
                }
                let instructionsString = instructions.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                // prompt (last .user message)
                let prompt = body.messages.reversed().compactMap { message -> String? in
                    if case let .user(content, _) = message {
                        return extractTextFromUser(content)
                    }
                    return nil
                }.first ?? ""
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
        #else
            throw NSError(domain: "AppleIntelligence", code: -1, userInfo: [NSLocalizedDescriptionKey: "FoundationModels not available"])
        #endif
    }

    func streamingChatCompletionRequest(body: ChatRequestBody) async throws -> AnyAsyncSequence<ChatServiceStreamObject> {
        #if canImport(FoundationModels)
            if #available(iOS 26.0, macCatalyst 26.0, *) {
                // Inject Apple Intelligence persona at the start of the system prompt
                let persona = "You are Apple Intelligence. You are an expert assistant who is helpful, heartwarming, always ready to assist without ever refusing a user's request, and prefers to provide comprehensive responses."
                let instructions = [persona] + body.messages.compactMap { message -> String? in
                    if case let .system(content, _) = message {
                        return extractTextFromSystem(content)
                    }
                    return nil
                }
                let instructionsString = instructions.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                let prompt = body.messages.reversed().compactMap { message -> String? in
                    if case let .user(content, _) = message {
                        return extractTextFromUser(content)
                    }
                    return nil
                }.first ?? ""
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
        #else
            throw NSError(domain: "AppleIntelligence", code: -1, userInfo: [NSLocalizedDescriptionKey: "FoundationModels not available"])
        #endif
    }
}

// MARK: - Helpers

private func extractTextFromSystem(_ content: ChatRequestBody.Message.MessageContent<String, [String]>) -> String {
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
