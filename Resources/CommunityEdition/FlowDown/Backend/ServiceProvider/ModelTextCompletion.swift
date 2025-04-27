//
//  ModelTextCompletion.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import EventSource
import Foundation

class TextCompletionModel_OpenAPI: AnyObject, ModelProtocol {
    let endpoint: URL
    let token: String
    let identifier: String

    var task: Task<Void, Never>?

    required init(provider: ServiceProvider, identifier: String) throws {
        guard let endpoint = provider
            .baseEndpoint
            .url?
            .appendingPathComponent("v1")
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")
        else {
            try Errors.throwText(NSLocalizedString("Invalid endpoint", comment: ""))
        }

        self.endpoint = endpoint
        token = provider.token
        self.identifier = identifier
    }

    func execute(
        input: Any,
        updatingResult: @escaping (Any) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        assert(input is [Conversation.Message])
        task?.cancel()
        task = nil
        task = Task.detached {
            guard let messages = input as? [Conversation.Message] else {
                completion(.failure(NSError(
                    domain: "TextCompletionModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid input"]
                )))
                return
            }
            do {
                try await self.executeRun(messages: messages, updatingResult: updatingResult)
                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    private func executeRun(
        messages: [Conversation.Message],
        updatingResult: @escaping (Any) -> Void
    ) async throws {
        let url = endpoint
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "POST"
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "stream": true,
            "model": identifier,
            "messages": messages.compactMap { $0.toEndpointDictionary() },
            "temperature": 0.7,
        ])

        _ = updatingResult

        let eventSource = EventSource()
        let connection = await eventSource.dataTask(for: request)

        var receivedContent = ""
        for await event in await connection.events() {
            switch event {
            case .open:
                print("[*] model established a new connection at \(Date())")
            case let .error(error):
                print("[*] received an error:", error.localizedDescription)
                throw error
            case let .event(event):
                guard !Task.isCancelled else { break }
                assert(!Thread.isMainThread)
                guard let data = event.data?.data(using: .utf8) else { continue }
                let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let delta = object?["choices"] as? [[String: Any]]
                let content = delta?.first?["delta"] as? [String: Any]
                let text = content?["content"] as? String
                guard let text, !text.isEmpty else { continue }
                receivedContent += text
                updatingResult(receivedContent)
            case .closed:
                print("[*] model closed the connection.")
            }
        }

        await connection.cancel()
        updatingResult(receivedContent)
        if receivedContent.isEmpty {
            try Errors.throwText(NSLocalizedString("No response from server", comment: ""))
        }
    }
}

private extension Conversation.Message {
    func toEndpointDictionary() -> [String: Any]? {
        let role: String? = switch participant {
        case .assistant: "assistant"
        case .user: "user"
        case .system: "system"
        case .hint: nil
        }
        guard let role else { return nil }
        return [
            "content": document,
            "role": role,
        ]
    }
}

/*
 {
     choices =     (
                 {
             delta =             {
                 content = "";
             };
             "finish_reason" = stop;
             index = 0;
             logprobs = "<null>";
         }
     );
     created = 1736414942;
     id = "b1d6724c-2386-4ec0-9379-eb8a5a13b587";
     model = "deepseek-chat";
     object = "chat.completion.chunk";
     "system_fingerprint" = "fp_3a5770e1b4";
     usage =     {
         "completion_tokens" = 8;
         "prompt_cache_hit_tokens" = 0;
         "prompt_cache_miss_tokens" = 438;
         "prompt_tokens" = 438;
         "total_tokens" = 446;
     };
 }
 */
