//
//  ChatTemplateManager.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import ConfigurableKit
import Foundation
import UIKit

class ChatTemplateManager {
    static let shared = ChatTemplateManager()

    let templateSaveQueue = DispatchQueue(label: "ChatTemplateManager.SaveQueue")

    @Published var templates: [ChatTemplate] = [] {
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
        if let decoded = try? PropertyListDecoder().decode([ChatTemplate].self, from: data) {
            print("[*] loaded \(decoded.count) chat templates")
            templates = decoded
        }
    }

    func addTemplate(_ template: ChatTemplate) {
        assert(Thread.isMainThread)
        templates.append(template)
    }

    func template(for itemIdentifier: ChatTemplate.ID) -> ChatTemplate? {
        assert(Thread.isMainThread)
        return templates.first(where: { $0.id == itemIdentifier })
    }

    func update(_ template: ChatTemplate) {
        assert(Thread.isMainThread)
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else {
            assertionFailure()
            return
        }
        templates[index] = template
    }

    func remove(_ template: ChatTemplate) {
        assert(Thread.isMainThread)
        templates.removeAll(where: { $0.id == template.id })
    }

    func remove(for itemIdentifier: ChatTemplate.ID) {
        assert(Thread.isMainThread)
        templates.removeAll(where: { $0.id == itemIdentifier })
    }
}
