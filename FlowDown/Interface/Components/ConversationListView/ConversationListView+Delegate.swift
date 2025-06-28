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

    private func createHeaderView(title: String) -> UIView {
        let headerView = UIView()
        headerView.backgroundColor = .clear

        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        label.numberOfLines = 1

        label.text = title
        headerView.addSubview(label)
        label.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(4)
        }
        return headerView
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section > 0 else { return nil } // skip the first section header
        let sectionIdentifier = dataSource.snapshot().sectionIdentifiers[section]
        return createHeaderView(title: sectionIdentifier)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        UIFont.preferredFont(forTextStyle: .caption1).lineHeight + 8
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point _: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let cell = tableView.cellForRow(at: indexPath)
        if let cell = cell as? Cell {
            selection.send(identifier)
            cell.presentMenu()
        }
        return nil
    }

    // bug/trouble make
    // func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    //     .init(actions: [UIContextualAction(
    //         style: .destructive,
    //         title: String(localized: "Delete")
    //     ) { [weak self] _, _, completion in
    //         guard let self,
    //               let identifier = dataSource.itemIdentifier(for: indexPath)
    //         else { return completion(false) }
    //         ConversationManager.shared.deleteConversation(identifier: identifier)
    //         completion(true)
    //     }])
    // }
}
