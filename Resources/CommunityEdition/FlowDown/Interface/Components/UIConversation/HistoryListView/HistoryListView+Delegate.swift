//
//  HistoryListView+Delegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/13.
//

import UIKit

extension UIConversation.HistoryListView: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let item else { return }
        delegate?.historyListDidSelectConversation(withIdentifier: item)
    }

    func tableView(_: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point _: CGPoint) -> UIContextMenuConfiguration? {
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let item else { return nil }
        guard let conv = ConversationManager.shared.conversation(withIdentifier: item) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            .init(options: [.displayInline, .singleSelection], children: [
                UIDeferredMenuElement.uncached {
                    $0(conv.createMenu())
                },
            ])
        }
    }
}

extension UIConversation.HistoryListView {
    protocol Delegate: AnyObject {
        func historyListDidSelectConversation(withIdentifier: Conversation.ID)
    }
}
