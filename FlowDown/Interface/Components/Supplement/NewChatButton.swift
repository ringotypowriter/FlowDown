//
//  SettingButton 2.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/22/25.
//

import Storage
import UIKit

class NewChatButton: UIButton {
    init() {
        super.init(frame: .zero)
        setImage(UIImage(systemName: "plus"), for: .normal)
        tintColor = .label
        imageView?.contentMode = .scaleAspectFit
        addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    weak var delegate: Delegate?

    @objc func didTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let templates = ChatTemplateManager.shared.templates

        if templates.isEmpty {
            // No templates, create empty conversation directly
            let conv = ConversationManager.shared.createNewConversation()
            delegate?.newChatDidCreated(conv.id)
        } else {
            // Show menu with template options
            presentTemplateMenu()
        }
    }

    private func presentTemplateMenu() {
        let templates = ChatTemplateManager.shared.templates

        let newEmpty = UIAction(
            title: String(localized: "New Conversation"),
            image: "💬".textToImage(size: 64) ?? .init()
        ) { [weak self] _ in
            let conv = ConversationManager.shared.createNewConversation()
            self?.delegate?.newChatDidCreated(conv.id)
        }

        var actions: [UIAction] = []
        for template in templates.values {
            let action = UIAction(
                title: template.name,
                image: UIImage(data: template.avatar)
            ) { [weak self] _ in
                let convId = ChatTemplateManager.shared.createConversationFromTemplate(template)
                self?.delegate?.newChatDidCreated(convId)
            }
            actions.append(action)
        }

        let templateMenu = UIMenu(
            title: String(localized: "Choose Template"),
            image: "📁".textToImage(size: 64) ?? .init(),
            options: [.displayInline],
            children: actions
        )
        let menu = UIMenu(
            title: String(localized: "New Chat"),
            options: [.displayInline],
            children: [newEmpty, templateMenu]
        )

        present(menu: menu)
    }
}

extension NewChatButton {
    protocol Delegate: AnyObject {
        func newChatDidCreated(_ identifier: Conversation.ID)
    }
}
