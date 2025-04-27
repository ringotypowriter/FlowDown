//
//  Conversation+Metadata.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import ConfigurableKit
import Foundation
import UIKit

private let defaultTitle = NSLocalizedString("Conversation", comment: "")

extension Conversation {
    struct Metadata: Codable {
        var title: String = defaultTitle
        var date: Date = .init()
        var avatarImageData: Data = .init()

        var providerIdentifier: ServiceProvider.ID? = nil
        var modelIdentifier: ServiceProvider.ModelIdentifier? = nil
    }
}

extension Conversation.Metadata {
    var titleIsDefault: Bool { defaultTitle == title }

    var avatarImage: UIImage {
        if let image = UIImage(data: avatarImageData) {
            return image
        }
        return UIImage(systemName: "quote.bubble") ?? .init()
    }

    var serviceProvider: ServiceProvider? {
        ServiceProviders.get(id: providerIdentifier)
    }

    func getModel() throws -> any ModelProtocol {
        guard let provider = serviceProvider,
              let modelIdentifier,
              !modelIdentifier.isEmpty
        else {
            try Errors.throwText(NSLocalizedString("Model not found", comment: ""))
        }
        return try provider.template
            .modelClassType(forType: .textCompletion)
            .init(provider: provider, identifier: modelIdentifier)
    }
}
