//
//  ChatTemplateManager.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import ConfigurableKit
import Foundation
import OrderedCollections
import UIKit

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
}
