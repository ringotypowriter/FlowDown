//
//  Conversation+Delegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Foundation

extension Conversation {
    protocol Delegate: AnyObject {
        func metadataDidUpdate(metadata: Conversation.Metadata)
        func messagesDidUpdate(messages: [Conversation.Message])

        func conversationBeginProcessing()
        func conversationEndProcessing()
    }

    func registerListener(_ delegate: Delegate) {
        delegates.append(.init(value: delegate))
        delegate.metadataDidUpdate(metadata: metadata)
        delegate.messagesDidUpdate(messages: .init(messages.values))
        if isGenerating { delegate.conversationBeginProcessing() }
    }

    func dispatchBeginProcess() {
        isGenerating = true
        delegates.forEach { $0.value?.conversationBeginProcessing() }
    }

    func dispatchEndProcess() {
        isGenerating = false
        delegates.forEach { $0.value?.conversationEndProcessing() }
    }

    func dispatchMetadataUpdates() {
        delegates.forEach { $0.value?.metadataDidUpdate(metadata: metadata) }
    }

    func dispatchMessageUpdates() {
        delegates.forEach { $0.value?.messagesDidUpdate(messages: .init(messages.values)) }
    }
}

extension Conversation.Delegate {
    func metadataDidUpdate(metadata _: Conversation.Metadata) {}
    func messagesDidUpdate(messages _: [Conversation.Message]) {}
    func conversationBeginProcessing() {}
    func conversationEndProcessing() {}
}

extension Conversation {
    class DelegateBox {
        weak var value: Delegate?

        init(value: Delegate) {
            self.value = value
        }
    }
}

import UIKit

extension Conversation {
    func createMenu() -> [UIMenuElement] {
        [
            UIAction(
                title: NSLocalizedString("Delete", comment: ""),
                image: UIImage(systemName: "trash"),
                attributes: .destructive,
                handler: { _ in
                    ConversationManager.shared.remove(withIdentifier: self.id)
                }
            ),
        ]
    }
}
