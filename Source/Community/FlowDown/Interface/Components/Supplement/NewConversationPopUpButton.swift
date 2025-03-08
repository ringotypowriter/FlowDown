//
//  NewConversationPopUpButton.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import UIKit

class NewConversationPopUpButton: UIButton {
    init() {
        super.init(frame: .zero)

        let plusImage = UIImage(systemName: "plus")
        setImage(plusImage, for: .normal)
        setTitleColor(.label, for: .normal)
        tintColor = .label

        accessibilityLabel = NSLocalizedString("New conversation", comment: "Button to start a new conversation")
        addTarget(self, action: #selector(onClick), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    weak var delegate: Delegate?

    @objc func onClick() {
//        guard let parentViewController else { return }
//        let viewController = NewConversationPickerController(sourceView: self)
//        parentViewController.present(viewController, animated: true)
        let conv = ConversationManager.shared.createConversation()
        delegate?.onNewConversation(conv)
    }
}

extension NewConversationPopUpButton {
    protocol Delegate: AnyObject {
        func onNewConversation(_ conversation: Conversation)
    }
}
