//
//  ConversationListView+Delegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/5/25.
//

import Storage
import UIKit

extension ConversationListView {
    protocol Delegate: AnyObject {
        func conversationListView(didSelect identifier: Conversation.ID?)
    }
}

extension ConversationListView: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else { return }
        selection.send(identifier)
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard dataSource.snapshot().numberOfSections > 1 else { return nil }
        let sectionIdentifier = dataSource.snapshot().sectionIdentifiers[section]
        return SectionDateHeaderView().with {
            $0.updateTitle(date: sectionIdentifier)
        }
    }
}
