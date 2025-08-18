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
        case openai_fast
        case mistral

        var model: CloudModel {
            switch self {
            case .openai:
                CloudModel(
                    id: "d26f2641-2802-490c-afcd-5e053460f829",
                    model_identifier: "gemini",
                    endpoint: "https://text.pollinations.ai/openai/v1/chat/completions",
                    context: .medium_64k,
                    capabilities: [.tool, .visual],
                    comment: String(localized: "This model is provided by pollinations.ai free of charge. Rate limit applies."),
                )

            case .openai_fast:
                CloudModel(
                    id: "0193f07a-2bc1-4937-ac68-ea3adbdb38ee",
                    model_identifier: "gpt-5-nano",
                    endpoint: "https://text.pollinations.ai/openai/v1/chat/completions",
                    context: .medium_64k,
                    capabilities: [.tool, .visual],
                    comment: String(localized: "This model is provided by pollinations.ai free of charge. Rate limit applies."),
                )

            case .mistral:
                CloudModel(
                    id: "78c9c492-ef7c-4504-aa95-04e4ce3a4602",
                    model_identifier: "mistral",
                    endpoint: "https://text.pollinations.ai/openai/v1/chat/completions",
                    context: .medium_64k,
                    capabilities: [.tool, .visual],
                    comment: String(localized: "This model is provided by pollinations.ai free of charge. Rate limit applies."),
                )
            }
        }
    }
}
