//
//  ConversationManager+CRUD.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/31/25.
//

import Combine
import Foundation
import RichEditor
import Storage

extension ConversationManager {
    func scanAll() {
        let items = sdb.listConversations()
        print("[+] scanned \(items.count) conversations")
        conversations.send(items)
    }

    func initialConversation() -> Conversation {
        if let firstItem = conversations.value.first,
           message(within: firstItem.id).isEmpty
        {
            print("[+] using first empty conversation with index: \(firstItem.id)")
            return firstItem
        }
        print("[+] creating a new conversation")
        return createNewConversation()
    }

    func createNewConversation() -> Conversation {
        let tempObject = sdb.createNewConversation()
        sdb.insertOrReplace(identifier: tempObject.id) { conv in
            conv.title = String(localized: "Conversation")
        }
        scanAll()
        guard let object = sdb.conversation(identifier: tempObject.id) else {
            preconditionFailure()
        }
        print("[+] created a new conversation with id: \(object.id)")
        NotificationCenter.default.post(name: .newChatCreated, object: object.id)
        return object
    }

    func conversation(identifier: Conversation.ID?) -> Conversation? {
        if let identifier {
            sdb.conversation(identifier: identifier)
        } else {
            nil
        }
    }

    func editConversation(identifier: Conversation.ID, block: @escaping (inout Conversation) -> Void) {
        let conv = conversation(identifier: identifier)
        guard var conv else { return }
        block(&conv)
        sdb.insertOrReplace(object: conv)
        scanAll()
    }

    func duplicateConversation(identifier: Conversation.ID) -> Conversation.ID? {
        let ans = sdb.duplicate(identifier: identifier) { conv in
            conv.creation = .init()
            conv.title = String(
                format: String(localized: "%@ Copy"),
                conv.title
            )
        }
        scanAll()
        return ans
    }

    func deleteConversation(identifier: Conversation.ID) {
        let session = ConversationSessionManager.shared.session(for: identifier)
        session.cancelCurrentTask {}
        sdb.remove(identifier: identifier)
        setRichEditorObject(identifier: identifier, nil)
        scanAll()
    }

    func eraseAll() {
        sdb.eraseAllConversations()
        clearRichEditorObject()
        scanAll()
    }

    func conversationIdentifierLookup(from messageIdentifier: Message.ID) -> Conversation.ID? {
        sdb.conversationIdentifierLookup(identifier: messageIdentifier)
    }
}

extension ConversationManager {
    func message(within conv: Conversation.ID) -> [Message] {
        sdb.listMessages(within: conv)
    }
}

extension Notification.Name {
    static let newChatCreated = Notification.Name("newChatCreated")
}
