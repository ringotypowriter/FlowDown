//
//  MessageListView+Delegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/6.
//

import UIKit

extension UIConversation.MessageListView: UITableViewDelegate, UITableViewDataSource {
    func item(forIndexPath indexPath: IndexPath) -> Element? {
        elements.values[safe: indexPath.row]
    }

    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        elements.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = item(forIndexPath: indexPath) else {
            assertionFailure()
            return UITableViewCell()
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: item.cell.rawValue, for: indexPath)
        if let cell = cell as? BaseCell {
            cell.layoutEngine = layoutEngine
            cell.registerViewModel(element: item)
        }
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = item(forIndexPath: indexPath) else {
            return 0
        }
        if let height = layoutEngine.height(forElement: item) {
            heightKeeper[item.id] = height
            return height
        }
        let ret = layoutEngine.resolveLayoutNow(item).height
        heightKeeper[item.id] = ret
        return ret
    }

    func tableView(_: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = item(forIndexPath: indexPath) else {
            return 0
        }
        if let height = layoutEngine.height(forElement: item) {
            return height
        }
        if let height = heightKeeper[item.id] {
            return height
        }
        return UITableView.automaticDimension
    }

    func tableView(_: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point _: CGPoint) -> UIContextMenuConfiguration? {
        guard let dataElement = item(forIndexPath: indexPath) else {
            return nil
        }
        guard var referenceView: UIView = tableView.cellForRow(at: indexPath) else {
            return nil
        }
        if let cell = referenceView as? BaseCell {
            referenceView = cell.containerView.subviews.first ?? cell.containerView
        }
        guard let menu = dataElement.createMenu(referencingView: referenceView) else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            menu
        }
    }
}
