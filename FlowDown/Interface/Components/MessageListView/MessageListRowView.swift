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
    var handleContextMenu: ((_ location: CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false // tool tip will extend out
        addSubview(contentView)

        contentView.isUserInteractionEnabled = true

        #if targetEnvironment(macCatalyst)
            contentView.addInteraction(UIContextMenuInteraction(delegate: self))
        #endif

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        contentView.addGestureRecognizer(longPress)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        themeDidUpdate()
        super.layoutSubviews()
        let insets = MessageListView.listRowInsets
        contentView.frame = .init(
            x: insets.left,
            y: 0,
            width: bounds.width - insets.horizontal,
            height: bounds.height - insets.bottom
        )
    }

    func themeDidUpdate() {}

    override func prepareForReuse() {
        super.prepareForReuse()

        handleContextMenu = nil

        var bfs: [UIView] = subviews
        while let firstView = bfs.first {
            bfs.removeFirst()
            bfs.append(contentsOf: firstView.subviews)
            if let ltxLabel = firstView as? LTXLabel {
                ltxLabel.clearSelection()
            }
        }
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        handleContextMenu?(location)
        return nil
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        handleContextMenu?(gesture.location(in: contentView))
    }
}
