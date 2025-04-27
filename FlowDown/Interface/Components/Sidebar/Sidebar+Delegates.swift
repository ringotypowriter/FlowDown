//
//  Sidebar+Delegates.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/5/25.
//

import Foundation
import Storage
import UIKit

extension Sidebar: NewChatButton.Delegate {
    func newChatDidCreated(_ identifier: Conversation.ID) {
        chatSelection = identifier
    }
}

extension Sidebar: ConversationListView.Delegate {
    func conversationListView(didSelect identifier: Conversation.ID?) {
        chatSelection = identifier
    }
}
