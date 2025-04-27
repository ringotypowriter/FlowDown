//
//  ConversationController+Delegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import Foundation

extension ConversationController: UIConversation.ModelSelectButton.Delegate {
    func modelPickerDidPick(provider: ServiceProvider, modelType _: ServiceProvider.ModelType, modelIdentifier: String) {
        var write = conversation.metadata
        write.providerIdentifier = provider.id
        write.modelIdentifier = modelIdentifier
        conversation.metadata = write
    }
}

extension ConversationController: UIConversation.MessageEditorView.Delegate {
    func messageEditorSubmitMessage(
        _: UIConversation.MessageEditorView,
        message: UIConversation.MessageEditorView.ViewModel
    ) {
        process(message)
    }

    private func process(_ message: UIConversation.MessageEditorView.ViewModel) {
        let message = Conversation.Message(
            conversationIdentifier: conversation.id,
            participant: .user,
            document: message.message,
            attachment: [] // TODO: IMPL
        )
        conversation.process(message: message)
        conversation.continueInterfere()
        messageList.pauseUpdateDueToUserInteract.send(false)
    }
}

extension ConversationController: Conversation.Delegate {
    func metadataDidUpdate(metadata: Conversation.Metadata) {
        titleBar.avatarImageView.image = metadata.avatarImage
        titleBar.titleLabel.withAnimation {
            self.titleBar.titleLabel.text = metadata.title
        }
        messageEditor.modelSelectButton.setTitle(
            metadata.modelIdentifier ?? NSLocalizedString("No Model Selected", comment: "")
        )
    }

    func messagesDidUpdate(messages: [Conversation.Message]) {
        messageListSubject.send(messages)
    }

    func conversationBeginProcessing() {
        progressCover.alpha = 0
        progressCover.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.progressCover.alpha = 1
        }
    }

    func conversationEndProcessing() {
        progressCover.alpha = 1
        UIView.animate(withDuration: 0.25) {
            self.progressCover.alpha = 0
        } completion: { _ in
            self.progressCover.isHidden = true
        }
    }
}

extension ConversationController: UIConversation.TitleBarView.Delegate {
    func titleBarCreateContextMenu() -> [UIMenuElement] {
        if navigationController != nil {
            [
                UIMenu(options: [.displayInline, .singleSelection], children: [
                    UIAction(
                        title: NSLocalizedString("Delete", comment: ""),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive,
                        handler: { _ in
                            ConversationManager.shared.remove(withIdentifier: self.conversation.id)
                            self.navigationController?.popViewController()
                        }
                    ),
                ]),
                UIMenu(options: [.displayInline, .singleSelection], children: [
                    UIAction(
                        title: NSLocalizedString("Back", comment: ""),
                        image: UIImage(systemName: "arrow.left"),
                        attributes: [],
                        handler: { _ in
                            self.navigationController?.popViewController()
                        }
                    ),
                ]),
            ]
        } else {
            conversation.createMenu()
        }
    }
}
