//
//  SettingButton 2.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/22/25.
//

import Combine
import Storage
import UIKit

class NewChatButton: UIButton {
    private var cancellables: Set<AnyCancellable> = []

    init() {
        super.init(frame: .zero)
        setImage(UIImage(systemName: "plus"), for: .normal)
        tintColor = .label
        imageView?.contentMode = .scaleAspectFit
        showsMenuAsPrimaryAction = true
        updateMenu()

        // Subscribe to template changes
        ChatTemplateManager.shared.$templates
            .ensureMainThread()
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    weak var delegate: Delegate?

    private func updateMenu() {
        menu = UIMenu(children: buildMenu())
    }

    private func buildMenu() -> [UIMenuElement] {
        let templates = ChatTemplateManager.shared.templates

        let newEmpty = UIAction(
            title: String(localized: "New Conversation"),
            image: UIImage(systemName: "plus")
        ) { [weak self] _ in
            let conv = ConversationManager.shared.createNewConversation()
            self?.delegate?.newChatDidCreated(conv.id)
        }

        if templates.isEmpty {
            return [newEmpty]
        }

        var actions: [UIAction] = []
        for template in templates.values {
            // Scale template avatar to standard menu icon size using aspect fit
            let scaledImage: UIImage? = {
                guard let originalImage = UIImage(data: template.avatar) else { return nil }
                let iconSize = UIFont.preferredFont(forTextStyle: .body).pointSize
                let targetSize = CGSize(width: iconSize, height: iconSize)

                // Calculate aspect fit size
                let aspectRatio = originalImage.size.width / originalImage.size.height
                var drawSize = targetSize
                if aspectRatio > 1 {
                    drawSize.height = targetSize.width / aspectRatio
                } else {
                    drawSize.width = targetSize.height * aspectRatio
                }

                let renderer = UIGraphicsImageRenderer(size: targetSize)
                return renderer.image { _ in
                    let origin = CGPoint(
                        x: (targetSize.width - drawSize.width) / 2,
                        y: (targetSize.height - drawSize.height) / 2
                    )
                    originalImage.draw(in: CGRect(origin: origin, size: drawSize))
                }
            }()

            let action = UIAction(
                title: template.name,
                image: scaledImage
            ) { [weak self] _ in
                let convId = ChatTemplateManager.shared.createConversationFromTemplate(template)
                self?.delegate?.newChatDidCreated(convId)
            }
            actions.append(action)
        }

        let templateMenu = UIMenu(
            title: String(localized: "Choose Template"),
            image: UIImage(systemName: "folder"),
            children: actions
        )

        return [
            UIMenu(
                title: String(localized: "New Chat"),
                options: [.displayInline],
                children: [newEmpty, templateMenu]
            ),
        ]
    }
}

extension NewChatButton {
    protocol Delegate: AnyObject {
        func newChatDidCreated(_ identifier: Conversation.ID)
    }
}
