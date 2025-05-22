//
//  Created by ktiays on 2025/1/31.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import ListViewKit
import Litext
import MarkdownView
import SnapKit
import UIKit

final class UserMessageView: MessageListRowView {
    static let contentPadding: CGFloat = 20
    static let textPadding: CGFloat = 12
    static let maximumIdealWidth: CGFloat = 800

    var text: String? {
        didSet {
            guard let text else {
                attributedText = nil
                return
            }
            attributedText = .init(string: text, attributes: [
                .font: theme.fonts.body,
                .foregroundColor: theme.colors.body,
            ])
        }
    }

    private var attributedText: NSAttributedString? {
        didSet {
            textView.attributedText = attributedText ?? .init()
        }
    }

    private lazy var textView: LTXLabel = .init().with { $0.isSelectable = true }

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .accent.withAlphaComponent(0.05)
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        textView.backgroundColor = .clear
        contentView.addSubview(textView)
    }

    @available(*, unavailable)
    @MainActor required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        textView.intrinsicContentSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let insets = MessageListView.listRowInsets
        let textContainerWidth = Self.availableTextWidth(for: bounds.width - insets.horizontal)
        textView.preferredMaxLayoutWidth = textContainerWidth
        let textSize = textView.intrinsicContentSize
        let contentWidth = ceil(textSize.width) + Self.textPadding * 2
        contentView.frame = .init(
            x: bounds.width - contentWidth - insets.right,
            y: 0,
            width: contentWidth,
            height: bounds.height - insets.bottom
        )
        textView.frame = contentView.bounds.insetBy(dx: Self.textPadding, dy: Self.textPadding)
    }

    @inlinable
    static func availableContentWidth(for width: CGFloat) -> CGFloat {
        max(0, min(maximumIdealWidth, width - contentPadding * 2))
    }

    @inlinable
    static func availableTextWidth(for width: CGFloat) -> CGFloat {
        availableContentWidth(for: width) - textPadding * 2
    }
}
