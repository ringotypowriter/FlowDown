//
//  ConversationSession+Icon.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/18/25.
//

import ChatClientKit
import Foundation
import Storage

extension ConversationSessionManager.Session {
    func generateConversationIcon() async -> String? {
        guard let userMessage = messages.last(where: { $0.role == .user })?.document else {
            return nil
        }
        guard let assistantMessage = messages.last(where: { $0.role == .assistant })?.document else {
            return nil
        }
        let document = """
        [Begin.User.Message]
        \(userMessage)
        [End.User.Message]
        [Begin.Assistant.Message]
        \(assistantMessage)
        [End.Assistant.Message]
        """
        let messages: [ChatRequestBody.Message] = ModelManager.iconGenerationMessages(
            input: document
        ).map {
            switch $0.participant {
            case .system: .system(content: .text($0.document))
            case .assistant: .assistant(content: .text($0.document))
            case .user: .user(content: .text($0.document))
            }
        }

        do {
            guard let model = models.auxiliary else { throw NSError() }
            let ans = try await ModelManager.shared.infer(
                with: model,
                maxCompletionTokens: 8,
                input: messages
            )
            let ret = ans.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[*] generated conversation icon: \(ret)")
            // ret.count is the count in unicode scalars, which is good from Swift
            guard ret.count == 1 else { return nil }
            return ret
        } catch {
            print("[*] failed to generate conversation icon: \(error)")
            return nil
        }
    }
}
