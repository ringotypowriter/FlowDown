//
//  ServiceProvider+Models.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/8.
//

import ConfigurableKit
import Foundation
import OrderedCollections

extension ServiceProvider {
    func fetchModels() async -> Result<Models, Error> {
        do {
            guard let url = baseEndpoint.url, !url.absoluteString.isEmpty else {
                try Errors.throwText(NSLocalizedString("Invalid URL", comment: ""))
            }
            var models: Models = .init()

            let textCompletionModels = try await fetchTextCompletionModels(baseURL: url)
            models[.textCompletion] = textCompletionModels

            return .success(models)
        } catch {
            return .failure(error)
        }
    }

    func fetchTextCompletionModels(baseURL url: URL) async throws -> OrderedSet<ModelIdentifier> {
        let listEndpointForTextCompletionModels = template.listEndpointForTextCompletionModels
            .reduce(url) { $0.appendingPathComponent($1) }
        var listTextCompletionModelsRequest = URLRequest(
            url: listEndpointForTextCompletionModels,
            cachePolicy: .reloadRevalidatingCacheData
        )
        if !token.isEmpty { listTextCompletionModelsRequest.addValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        ) }
        let (data, _) = try await URLSession.shared.data(for: listTextCompletionModelsRequest)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return try decodeTextCompletionModels(fromObject: object)
    }

    func decodeTextCompletionModels(fromObject object: Any) throws -> OrderedSet<ServiceProvider.ModelIdentifier> {
        try template.decodeTextCompletionModels(fromObject: object)
    }
}

extension ServiceProvider.Template {
    var listEndpointForTextCompletionModels: [String] {
        switch self {
        case .openAPI:
            ["v1", "models"]
        case .openAI:
            ["v1", "models"]
        case .deepseek:
            ["v1", "models"]
        case .openRouter:
            ["v1", "models"]
        case .groq:
            ["v1", "models"]
        }
    }

    func decodeTextCompletionModels(fromObject object: Any) throws -> OrderedSet<ServiceProvider.ModelIdentifier> {
        switch self {
        case .openAPI, .openAI, .deepseek, .openRouter, .groq:
            guard let object = object as? [String: Any] else { break }
            guard let list = object["data"] as? [[String: Any]] else { break }
            let ids = list.compactMap { $0["id"] as? String }
            return .init(ids.sorted())
        }
        try Errors.throwText(NSLocalizedString("Unable to decode models", comment: ""))
    }
}

extension ServiceProvider.ModelType {
    func getDefault() -> ServiceProvider.ModelIdentifier? {
        ConfigurableKit.value(forKey: defaultKey)
    }

    func removeDefault() {
        ConfigurableKit.set(value: "", forKey: defaultKey)
    }
}
