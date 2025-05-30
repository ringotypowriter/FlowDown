//
//  ModelManager+Builtin.swift
//  FlowDown
//
//  Created by 秋星桥 on 4/6/25.
//

import Foundation
import Storage

extension CloudModel {
    enum BuiltinModel: CaseIterable {
        case openai
        case mistral
        case llama

        var model: CloudModel {
            switch self {
            case .openai:
                CloudModel(
                    id: "95b2ed31-d84d-4ce5-86a4-d362687bb18a",
                    isProfileInControl: true,
                    model_identifier: "openai",
                    endpoint: "https://text.pollinations.ai/openai/v1/chat/completions",
                    context: .medium_64k,
                    capabilities: [.tool, .visual]
                )

            case .mistral:
                CloudModel(
                    id: "78c9c492-ef7c-4504-aa95-04e4ce3a4602",
                    isProfileInControl: true,
                    model_identifier: "mistral",
                    endpoint: "https://text.pollinations.ai/openai/v1/chat/completions",
                    context: .medium_64k,
                    capabilities: [.tool, .visual]
                )

            case .llama:
                CloudModel(
                    id: "78c9c492-ef7c-4504-aa95-04e4ce3a4602",
                    isProfileInControl: true,
                    model_identifier: "llama-vision",
                    endpoint: "https://text.pollinations.ai/openai/v1/chat/completions",
                    context: .medium_64k,
                    capabilities: [.tool, .visual]
                )
            }
        }
    }
}
