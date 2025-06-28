//
//  AppDelegate+Menu.swift
//  FlowDown
//
//  Created by Alan Ye on 6/27/25.
//

import AlertController
import Storage
import UIKit

extension AppDelegate {
    // MARK: - Menu Building

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == UIMenuSystem.main else { return }

        builder.insertChild(
            UIMenu(
                title: "",
                options: .displayInline,
                children: [
                    UIKeyCommand(
                        title: String(localized: "New Chat"),
                        action: #selector(requestNewChatFromMenu(_:)),
                        input: "n",
                        modifierFlags: .command
                    ),
                ]
            ),
            atStartOfMenu: .file
        )
        builder.insertChild(
            UIMenu(
                title: "",
                options: .displayInline,
                children: [
                    UIKeyCommand(
                        title: String(localized: "Delete Chat"),
                        action: #selector(deleteConversationFromMenu(_:)),
                        input: "\u{8}",
                        modifierFlags: [.command, .shift]
                    ),
                ]
            ),
            atEndOfMenu: .file
        )
        builder.insertSibling(
            UIMenu(
                title: "",
                options: .displayInline,
                children: [
                    UIKeyCommand(
                        title: String(localized: "Settings..."),
                        action: #selector(openSettingsFromMenu(_:)),
                        input: ",",
                        modifierFlags: .command
                    ),
                ]
            ),
            afterMenu: .preferences
        )
        builder.insertChild(
            UIMenu(
                title: "",
                options: .displayInline,
                children: [
                    UIKeyCommand(
                        title: String(localized: "Previous Conversation"),
                        action: #selector(selectPreviousConversationFromMenu(_:)),
                        input: UIKeyCommand.inputUpArrow,
                        modifierFlags: [.command, .alternate]
                    ),
                    UIKeyCommand(
                        title: String(localized: "Next Conversation"),
                        action: #selector(selectNextConversationFromMenu(_:)),
                        input: UIKeyCommand.inputDownArrow,
                        modifierFlags: [.command, .alternate]
                    ),
                ]
            ),
            atStartOfMenu: .view
        )
    }

    // MARK: - Menu Actions

    var mainWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first }
            .first
    }

    // Wire from MainController
    @objc func requestNewChatFromMenu(_: Any?) {
        (mainWindow?.rootViewController as? MainController)?.requestNewChat()
    }

    @objc func openSettingsFromMenu(_: Any?) {
        (mainWindow?.rootViewController as? MainController)?.openSettings()
    }

    // conversation related
    private func withCurrentConversation(_ block: (MainController, Conversation.ID, Conversation) -> Void) {
        guard let mainVC = mainWindow?.rootViewController as? MainController,
              let conversationID = mainVC.chatView.conversationIdentifier,
              let conversation = ConversationManager.shared.conversation(identifier: conversationID)
        else {
            return
        }
        block(mainVC, conversationID, conversation)
    }

    @objc func deleteConversationFromMenu(_: Any?) {
        withCurrentConversation { _, conversationID, _ in
            ConversationManager.shared.deleteConversation(identifier: conversationID)
        }
    }

    // conversation navigation
    @objc func selectPreviousConversationFromMenu(_: Any?) {
        withCurrentConversation { mainVC, conversationID, _ in
            let list = ConversationManager.shared.conversations.value
            guard let currentIndex = list.firstIndex(where: { $0.id == conversationID }), currentIndex > 0 else { return }
            let previousID = list[currentIndex - 1].id
            mainVC.sidebar.chatSelection = previousID
            mainVC.chatView.use(conversation: previousID) {
                mainVC.chatView.focusEditor()
            }
        }
    }

    @objc func selectNextConversationFromMenu(_: Any?) {
        withCurrentConversation { mainVC, conversationID, _ in
            let list = ConversationManager.shared.conversations.value
            guard let currentIndex = list.firstIndex(where: { $0.id == conversationID }), currentIndex < list.count - 1 else { return }
            let nextID = list[currentIndex + 1].id
            mainVC.sidebar.chatSelection = nextID
            mainVC.chatView.use(conversation: nextID) {
                mainVC.chatView.focusEditor()
            }
        }
    }
}
