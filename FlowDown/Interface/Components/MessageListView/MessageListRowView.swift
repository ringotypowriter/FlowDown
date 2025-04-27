//
//  Created by ktiays on 2025/2/7.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext
import MarkdownView
import ThatListView
import UIKit

class MessageListRowView: ThatListRowView {
    var theme: MarkdownTheme = .default {
        didSet {
            themeDidUpdate()
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
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

        var bfs: [UIView] = subviews
        while let firstView = bfs.first {
            bfs.removeFirst()
            bfs.append(contentsOf: firstView.subviews)
            if let ltxLabel = firstView as? LTXLabel {
                ltxLabel.clearSelection()
            }
        }
    }
}
