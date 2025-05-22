//
//  MainController+Content.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/20/25.
//

import Foundation
import Storage
import UIKit

extension MainController {
    func setupViews() {
        contentView.hideKeyboardWhenTappedAround()

        contentView.contentView.addSubview(chatView)
        chatView.onCreateNewChat = { [weak self] in
            guard let self else { return }
            sidebar.newChatButton.didTap()
        }
        chatView.onSuggestNewChat = { [weak self] id in
            guard let self else { return }
            load(id)
        }
        chatView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        #if !targetEnvironment(macCatalyst)
            chatView.escapeButton.actionBlock = { [weak self] in
                self?.view.doWithAnimation {
                    self?.isSidebarCollapsed.toggle()
                }
            }
        #endif

        sidebar.delegate = self
        sidebarView.contentView.addSubview(sidebar)
        sidebar.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        sidebar.conversationListView.tableView.gestureRecognizers?.forEach {
            guard $0 is UIPanGestureRecognizer else { return }
            $0.cancelsTouchesInView = false
        }
    }

    func load(_ conv: Conversation.ID?) {
        print("[MainController] sidebarDidSelectNewChat: \(conv ?? -1)")
        chatView.prepareForReuse()
        guard let identifier = conv else { return }

        sidebar.chatSelection = identifier
        chatView.use(conversation: identifier)

        let session = ConversationSessionManager.shared.session(for: identifier)
        session.updateModels()
    }
}

extension MainController: Sidebar.Delegate {
    func sidebarRecivedSingleTapForSelection() {
        #if !targetEnvironment(macCatalyst)
            DispatchQueue.main.async {
                guard self.presentedViewController == nil else { return }
                let tableView = self.sidebar.conversationListView.tableView
                guard !tableView.isEditing else { return }
                self.view.doWithAnimation { self.isSidebarCollapsed = true }
            }
        #endif
    }

    func sidebarDidSelectNewChat(_ conv: Conversation.ID?) {
        load(conv)
    }
}
