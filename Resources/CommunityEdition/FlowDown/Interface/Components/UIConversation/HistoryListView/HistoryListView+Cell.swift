//
//  HistoryListView+Cell.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/13.
//

import UIKit

extension UIConversation.HistoryListView {
    class Cell: UITableViewCell {
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            backgroundColor = .clear

            let selectionColor = UIView().then {
                $0.backgroundColor = .accent.withAlphaComponent(0.1)
                $0.layer.cornerRadius = 8
            }
            selectedBackgroundView = selectionColor

            textLabel?.textColor = .label
            textLabel?.highlightedTextColor = .label
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }
    }
}
