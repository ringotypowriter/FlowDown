//
//  ServiceProvider+Template.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/8.
//

import Foundation

extension ServiceProvider {
    enum Template: String, CaseIterable, Codable {
        case openAPI

        case openAI
        case deepseek
        case openRouter
        case groq
    }
}

extension ServiceProvider.Template {
    func modelClassType(forType type: ServiceProvider.ModelType) -> ModelProtocol.Type {
        switch type {
        case .textCompletion:
            TextCompletionModel_OpenAPI.self
        }
    }
}

extension ServiceProvider.Template {
    var name: String {
        switch self {
        case .openAPI:
            NSLocalizedString("OpenAI Compatible API", comment: "")
        case .openAI:
            NSLocalizedString("OpenAI", comment: "")
        case .deepseek:
            NSLocalizedString("Deepseek", comment: "")
        case .openRouter:
            NSLocalizedString("OpenRouter", comment: "")
        case .groq:
            NSLocalizedString("Groq", comment: "")
        }
    }

    var baseEndpoint: String {
        switch self {
        case .openAPI:
            "https://"
        case .openAI:
            "https://api.openai.com"
        case .deepseek:
            "https://api.deepseek.com"
        case .openRouter:
            "https://openrouter.ai/api"
        case .groq:
            "https://api.groq.com/openai"
        }
    }

    var acquireTokenURL: URL? {
        switch self {
        case .openAPI:
            nil
        case .openAI:
            URL(string: "https://platform.openai.com/api-keys")!
        case .deepseek:
            URL(string: "https://platform.deepseek.com/api_keys")!
        case .openRouter:
            URL(string: "https://openrouter.ai/settings/keys")!
        case .groq:
            URL(string: "https://console.groq.com/keys")
        }
    }

    func new() -> ServiceProvider {
        ServiceProvider(
            template: self,
            name: ServiceProviders.newName(forTemplate: self),
            baseEndpoint: baseEndpoint
        )
    }
}
