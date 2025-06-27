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
                    )
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
                        modifierFlags: [.command]
                    )
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
                    )
                ]
            ),
            afterMenu: .preferences
        )
    }

    // MARK: - Menu Actions
    var mainWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first }
            .first
    }

    // Wire from MainController
    @objc func requestNewChatFromMenu(_ sender: Any?) {
        (mainWindow?.rootViewController as? MainController)?.requestNewChat()
    }

    @objc func openSettingsFromMenu(_ sender: Any?) {
        (mainWindow?.rootViewController as? MainController)?.openSettings()
    }

    // Conversation related
    private func withCurrentConversation(_ block: (MainController, Conversation.ID, Conversation) -> Void) {
        guard let mainVC = mainWindow?.rootViewController as? MainController,
              let conversationID = mainVC.chatView.conversationIdentifier,
              let conversation = ConversationManager.shared.conversation(identifier: conversationID)
        else {
            return
        }
        block(mainVC, conversationID, conversation)
    }

    @objc func deleteConversationFromMenu(_ sender: Any?) {
        withCurrentConversation { mainVC, conversationID, _ in
            ConversationManager.shared.deleteConversation(identifier: conversationID)
        }
    }
}
