//
//  ChatTemplateManager.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import ChatClientKit
import ConfigurableKit
import Foundation
import OrderedCollections
import Storage
import UIKit
import XMLCoder

class ChatTemplateManager {
    static let shared = ChatTemplateManager()

    let templateSaveQueue = DispatchQueue(label: "ChatTemplateManager.SaveQueue")

    @Published var templates: OrderedDictionary<ChatTemplate.ID, ChatTemplate> = [:] {
        didSet {
            templateSaveQueue.async {
                guard let data = try? PropertyListEncoder().encode(self.templates) else {
                    assertionFailure()
                    return
                }
                UserDefaults.standard.set(data, forKey: "ChatTemplates")
            }
        }
    }

    private init() {
        let data = UserDefaults.standard.data(forKey: "ChatTemplates") ?? Data()
        if let decoded = try? PropertyListDecoder().decode(
            OrderedDictionary<ChatTemplate.ID, ChatTemplate>.self,
            from: data
        ) {
            print("[*] loaded \(decoded.count) chat templates")
            templates = decoded
        }
    }

    func addTemplate(_ template: ChatTemplate) {
        assert(Thread.isMainThread)
        assert(templates[template.id] == nil)
        templates[template.id] = template
    }

    func template(for itemIdentifier: ChatTemplate.ID) -> ChatTemplate? {
        assert(Thread.isMainThread)
        return templates[itemIdentifier]
    }

    func update(_ template: ChatTemplate) {
        assert(Thread.isMainThread)
        assert(templates[template.id] != nil)
        templates[template.id] = template
    }

    func remove(_ template: ChatTemplate) {
        assert(Thread.isMainThread)
        assert(templates[template.id] != nil)
        templates.removeValue(forKey: template.id)
    }

    func remove(for itemIdentifier: ChatTemplate.ID) {
        assert(Thread.isMainThread)
        assert(templates[itemIdentifier] != nil)
        templates.removeValue(forKey: itemIdentifier)
    }

    func createConversationFromTemplate(_ template: ChatTemplate) -> Conversation.ID {
        assert(Thread.isMainThread)
        let conversation = ConversationManager.shared.createNewConversation()

        ConversationManager.shared.editConversation(identifier: conversation.id) { conv in
            conv.icon = template.avatar
            conv.title = template.name
            conv.shouldAutoRename = template.name.isEmpty // Only auto-rename if template name is empty
        }

        if !template.prompt.isEmpty {
            let session = ConversationSessionManager.shared.session(for: conversation.id)

            if !template.inheritApplicationPrompt {
                let systemMessages = session.messages.filter { $0.role == .system }
                for message in systemMessages {
                    session.delete(messageIdentifier: message.id)
                }
            }
            let templateMessage = session.appendNewMessage(role: .system)
            templateMessage.document = template.prompt
            session.save()
        }

        return conversation.id
    }

    func createTemplateFromConversation(
        _ conversation: Conversation,
        model: ModelManager.ModelIdentifier,
        controller _: UIViewController,
        completion: @escaping (Result<ChatTemplate, Error>) -> Void
    ) {
        Task {
            do {
                let template = try await generateChatTemplate(from: conversation, using: model)
                await MainActor.run {
                    completion(.success(template))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    private func generateChatTemplate(from conversation: Conversation, using model: ModelManager.ModelIdentifier) async throws -> ChatTemplate {
        let session = ConversationSessionManager.shared.session(for: conversation.id)

        // Get conversation messages for analysis
        let userMessages = session.messages.filter { $0.role == .user }
        let assistantMessages = session.messages.filter { $0.role == .assistant }

        guard !userMessages.isEmpty, !assistantMessages.isEmpty else {
            throw NSError(
                domain: "ChatTemplate",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Conversation does not have enough messages to create a template."),
                ]
            )
        }

        // Prepare conversation context
        let conversationContext = userMessages.prefix(3).map(\.document).joined(separator: "\n\n")
        let responseContext = assistantMessages.prefix(3).map(\.document).joined(separator: "\n\n")

        // Create XML structure for template generation
        let templateRequest = TemplateGenerationXML(
            task: String(localized: "Analyze the conversation and generate a reusable chat template. Extract the core purpose, create a concise name, suggest an appropriate emoji, and write a system prompt that captures the essence of the conversation pattern."),
            conversation_context: conversationContext,
            response_context: responseContext,
            output_format: TemplateGenerationXML.OutputFormat(
                name: "Short descriptive name for the template using concise language",
                emoji: "Single emoji representing the template purpose",
                prompt: "System prompt that captures the conversation pattern and purpose",
                inherit_app_prompt: true
            )
        )

        let encoder = XMLEncoder()
        encoder.outputFormatting = .prettyPrinted
        let xmlData = try encoder.encode(templateRequest, withRootKey: "template_generation")
        let xmlString = String(data: xmlData, encoding: .utf8) ?? ""

        let messages: [ChatRequestBody.Message] = [
            .system(content: .text("You are a chat template generator. Analyze conversations and create reusable templates. Respond ONLY with valid XML following the exact format provided. Do not include any text outside the XML structure. Please ensure using user's preferred language inside conversation.")),
            .user(content: .text(xmlString)),
        ]

        let response = try await ModelManager.shared.infer(
            with: model,
            maxCompletionTokens: 512,
            input: messages,
            additionalField: [:]
        )

        return try parseTemplateResponse(response.content)
    }

    private func parseTemplateResponse(_ xmlString: String) throws -> ChatTemplate {
        let decoder = XMLDecoder()

        // Try to decode the response as TemplateResponse
        if let data = xmlString.data(using: .utf8),
           let templateResponse = try? decoder.decode(TemplateResponse.self, from: data)
        {
            let emojiData = templateResponse.emoji.textToImage(size: 64)?.pngData() ?? Data()

            return ChatTemplate(
                name: templateResponse.name.trimmingCharacters(in: .whitespacesAndNewlines),
                avatar: emojiData,
                prompt: templateResponse.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                inheritApplicationPrompt: templateResponse.inherit_app_prompt
            )
        }

        // Fallback to regex parsing if XML parsing fails
        return try parseTemplateUsingRegex(xmlString)
    }

    private func parseTemplateUsingRegex(_ xmlString: String) throws -> ChatTemplate {
        let namePattern = #"<name>(.*?)</name>"#
        let emojiPattern = #"<emoji>(.*?)</emoji>"#
        let promptPattern = #"<prompt>(.*?)</prompt>"#
        let inheritPattern = #"<inherit_app_prompt>(.*?)</inherit_app_prompt>"#

        guard let nameRegex = try? NSRegularExpression(pattern: namePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let emojiRegex = try? NSRegularExpression(pattern: emojiPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let promptRegex = try? NSRegularExpression(pattern: promptPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let inheritRegex = try? NSRegularExpression(pattern: inheritPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        else {
            throw NSError(domain: "ChatTemplateGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create regex patterns"])
        }

        let range = NSRange(xmlString.startIndex ..< xmlString.endIndex, in: xmlString)

        // Extract name
        let name = if let nameMatch = nameRegex.firstMatch(in: xmlString, options: [], range: range),
                      let nameRange = Range(nameMatch.range(at: 1), in: xmlString)
        {
            String(xmlString[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            throw NSError(domain: "ChatTemplate", code: -1, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "Failed to extract required information from model response."),
            ])
        }

        // Extract emoji
        let emoji = if let emojiMatch = emojiRegex.firstMatch(in: xmlString, options: [], range: range),
                       let emojiRange = Range(emojiMatch.range(at: 1), in: xmlString)
        {
            String(xmlString[emojiRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            "🤖"
        }

        // Extract prompt
        let prompt = if let promptMatch = promptRegex.firstMatch(in: xmlString, options: [], range: range),
                        let promptRange = Range(promptMatch.range(at: 1), in: xmlString)
        {
            String(xmlString[promptRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            throw NSError(domain: "ChatTemplate", code: -1, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "Failed to extract required information from model response."),
            ])
        }

        // Extract inherit_app_prompt
        let inheritAppPrompt: Bool
        if let inheritMatch = inheritRegex.firstMatch(in: xmlString, options: [], range: range),
           let inheritRange = Range(inheritMatch.range(at: 1), in: xmlString)
        {
            let inheritValue = String(xmlString[inheritRange]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            inheritAppPrompt = inheritValue == "true"
        } else {
            inheritAppPrompt = true
        }

        let emojiData = emoji.textToImage(size: 64)?.pngData() ?? Data()

        return ChatTemplate(
            name: name,
            avatar: emojiData,
            prompt: prompt,
            inheritApplicationPrompt: inheritAppPrompt
        )
    }
}

// MARK: - XML Models for Template Generation

private struct TemplateGenerationXML: Codable {
    let task: String
    let conversation_context: String
    let response_context: String
    let output_format: OutputFormat

    struct OutputFormat: Codable {
        let name: String
        let emoji: String
        let prompt: String
        let inherit_app_prompt: Bool
    }
}

private struct TemplateResponse: Codable {
    let name: String
    let emoji: String
    let prompt: String
    let inherit_app_prompt: Bool
}
