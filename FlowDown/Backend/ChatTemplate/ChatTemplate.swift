//
//  ChatTemplate.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import Foundation
import UIKit

struct ChatTemplate: Identifiable, Codable, Equatable {
    var id: UUID = .init()

    var name: String = .init(localized: "New Template")
    var avatar: Data = "😶".textToImage(size: 256)?.pngData() ?? .init()
    var templateDescription: String = .init(localized: "My awesome chat template description.")

    enum ApplicationPromptBehavior: String, Codable {
        case inherit
        case ignore
    }

    var applicationPromptBehavior: ApplicationPromptBehavior = .inherit

    var prompt: String = .init(localized: "Please help me to...")
    var model: ModelManager.ModelIdentifier = .init()

    func with(_ modification: (inout ChatTemplate) -> Void) -> ChatTemplate {
        var template = self
        modification(&template)
        return template
    }
}
