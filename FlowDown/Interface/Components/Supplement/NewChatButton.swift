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
        let conv = ConversationManager.shared.createNewConversation()
        delegate?.newChatDidCreated(conv.id)
    }
}

extension NewChatButton {
    protocol Delegate: AnyObject {
        func newChatDidCreated(_ identifier: Conversation.ID)
    }
}
