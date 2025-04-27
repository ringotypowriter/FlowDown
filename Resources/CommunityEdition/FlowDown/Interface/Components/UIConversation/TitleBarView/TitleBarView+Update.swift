//
//  TitleBarView+Update.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import UIKit

extension UIConversation.TitleBarView {
    func subscribe(to conversation: Conversation) {
        conversation.registerListener(self)
    }
}

extension UIConversation.TitleBarView: Conversation.Delegate {
    func metadataDidUpdate(metadata: Conversation.Metadata) {
        avatarImageView.image = metadata.avatarImage
        titleLabel.text = metadata.title
    }
}
