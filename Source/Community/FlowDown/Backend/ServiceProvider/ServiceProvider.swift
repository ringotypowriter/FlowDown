//
//  ServiceProvider.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/7.
//

import BetterCodable
import Foundation
import OrderedCollections

struct ServiceProvider: Codable, Equatable, Hashable, Identifiable {
    var id: UUID = .init()

    var template: Template

    var name: String
    var date: Date = .init()
    var baseEndpoint: String
    var token: String = ""

    typealias ModelIdentifier = String
    typealias Models = [ModelType: OrderedSet<ModelIdentifier>]
    @DefaultEmptyDictionary var models: Models = [:]
    @DefaultEmptyDictionary var enabledModels: Models = [:]
}

extension ServiceProvider {
    var modelCount: Int {
        models.map(\.value.count).reduce(0, +)
    }

    var modelTextList: String {
        models.map { $0.value.sorted().joined(separator: ", ") }.joined(separator: ", ")
    }

    var enabledModelCount: Int {
        enabledModels.map(\.value.count).reduce(0, +)
    }

    var enabledModelTextList: String {
        enabledModels.map { $0.value.sorted().joined(separator: ", ") }.joined(separator: ", ")
    }

    var interfaceDescription: String {
        [
            baseEndpoint.url?.absoluteString,
            "\(enabledModelCount)/\(modelCount)",
        ].compactMap(\.self).joined(separator: ", ")
    }
}

extension ServiceProvider {
    enum ModelType: String, Codable, CaseIterable {
        case textCompletion
    }
}

extension ServiceProvider.ModelType {
    var icon: String {
        switch self {
        case .textCompletion:
            "text.bubble"
        }
    }

    var interfaceText: String {
        switch self {
        case .textCompletion:
            NSLocalizedString("Text Completion", comment: "")
        }
    }

    var description: String {
        switch self {
        case .textCompletion:
            NSLocalizedString("Text completion models generate text based on the input. It is used in conversations to generate responses.", comment: "")
        }
    }

    var defaultKey: String {
        SettingsKey.defaultModelPrefix.rawValue + "." + rawValue
    }
}
