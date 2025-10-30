//
//  Created by ktiays on 2025/2/7.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import ListViewKit
import Litext
import MarkdownView
import UIKit

class MessageListRowView: ListRowView, UIContextMenuInteractionDelegate {
    var theme: MarkdownTheme = .default {
        didSet {
            themeDidUpdate()
            setNeedsLayout()
        }
    }

    let contentView = UIView()
    var contextMenuProvider: ((CGPoint) -> UIMenu?)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false // tool tip will extend out
        addSubview(contentView)
        contentView.isUserInteractionEnabled = true

        contentView.addInteraction(UIContextMenuInteraction(delegate: self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        themeDidUpdate()
        super.layoutSubviews()

        let insets = MessageListView.listRowInsets
        contentView.frame = CGRect(
            x: insets.left,
            y: 0,
            width: bounds.width - insets.horizontal,
            height: bounds.height - insets.bottom
        )
    }

    func themeDidUpdate() {}

    override func prepareForReuse() {
        super.prepareForReuse()
        contextMenuProvider = nil

        // clear any LTXLabel selection
        var queue = subviews
        while let v = queue.first {
            queue.removeFirst()
            queue.append(contentsOf: v.subviews)
            (v as? LTXLabel)?.clearSelection()
        }
    }

    // MARK: - UIContextMenuInteractionDelegate

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let menu = contextMenuProvider?(location) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            menu
        }
    }
}
