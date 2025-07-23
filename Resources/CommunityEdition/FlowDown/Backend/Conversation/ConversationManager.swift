//
//  ConversationManager.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/10.
//

import Combine
import Foundation
import OrderedCollections

class ConversationManager {
    static let shared = ConversationManager()
    private init() {}

    typealias Conversations = OrderedDictionary<Conversation.ID, Conversation>
    var conversations: CurrentValueSubject<Conversations, Never> = .init([:])

    func alteringConversations(block: @escaping (inout Conversations) -> Void) {
        var values = conversations.value
        block(&values)
        conversations.send(values)
    }

    func conversationsPublisher() -> AnyPublisher<Conversations, Never> {
        conversations.removeDuplicates().eraseToAnyPublisher()
    }

    func conversation(withIdentifier convID: Conversation.ID) -> Conversation? {
        conversations.value[convID]
    }

    func remove(withIdentifier convID: Conversation.ID) {
        alteringConversations {
            $0.removeValue(forKey: convID)
            if $0.isEmpty {
                let conv = Conversation()
                $0.updateValue(conv, forKey: conv.id)
            }
        }
    }

    func removeAll() {
        alteringConversations {
            $0.removeAll()
            let conv = Conversation()
            $0.updateValue(conv, forKey: conv.id)
        }
    }
}

extension ConversationManager {
    @discardableResult
    func createConversation() -> Conversation {
        assert(Thread.isMainThread)
        let conv = Conversation()
        alteringConversations { $0.updateValue(conv, forKey: conv.id) }
        return conv
    }
}
