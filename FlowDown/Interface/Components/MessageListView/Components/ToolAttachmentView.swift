//
//  ToolAttachmentView.swift
//  FlowDown
//
//  Created by Willow Zhang on 11/7/25.
//

import RichEditor
import UIKit

final class ToolAttachmentView: MessageListRowView {
    private static let hintFont: UIFont = .systemFont(ofSize: 12)
    private static let hintVerticalPadding: CGFloat = 8
    private static let hintHorizontalPadding: CGFloat = 16

    private lazy var attachmentsBar: AttachmentsBar = .init()
    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.font = Self.hintFont
        label.textColor = .systemOrange
        label.numberOfLines = 0
        label.text = String(localized: "Note: The tool returned images, but the current model cannot see them.")
        return label
    }()

    private var shouldShowHint = false

    static func height(shouldShowVisionHint: Bool, maxWidth: CGFloat) -> CGFloat {
        var height = AttachmentsBar.itemHeight

        if shouldShowVisionHint {
            let hintText = String(localized: "Note: The tool returned images, but the current model cannot see them.")
            let hintSize = (hintText as NSString).boundingRect(
                with: CGSize(width: maxWidth - hintHorizontalPadding, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: hintFont],
                context: nil
            ).size
            height += hintSize.height + hintVerticalPadding
        }

        return height
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        attachmentsBar.inset = .zero
        attachmentsBar.isDeletable = false
        attachmentsBar.collectionView.alwaysBounceHorizontal = false
        contentView.addSubview(attachmentsBar)
        contentView.addSubview(hintLabel)
    }

    @available(*, unavailable)
    @MainActor required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        attachmentsBar.deleteAllItems()
        shouldShowHint = false
        hintLabel.isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let bounds = contentView.bounds
        let idealWidth = attachmentsBar.idealSize().width
        let attachmentWidth = min(idealWidth, bounds.width)

        // 工具消息左对齐
        attachmentsBar.frame = .init(
            x: 0,
            y: 0,
            width: attachmentWidth,
            height: AttachmentsBar.itemHeight
        )

        // 提示标签在附件下方
        if shouldShowHint {
            let hintSize = hintLabel.sizeThatFits(.init(
                width: bounds.width - Self.hintHorizontalPadding,
                height: .greatestFiniteMagnitude
            ))
            hintLabel.frame = .init(
                x: Self.hintHorizontalPadding / 2,
                y: AttachmentsBar.itemHeight + 4,
                width: bounds.width - Self.hintHorizontalPadding,
                height: hintSize.height
            )
        }
    }

    func update(with attachments: MessageListView.Attachments, shouldShowVisionHint: Bool) {
        for element in attachments.items {
            attachmentsBar.insert(item: element)
        }

        shouldShowHint = shouldShowVisionHint
        hintLabel.isHidden = !shouldShowVisionHint
        setNeedsLayout()
    }
}
