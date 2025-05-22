//
//  Created by ktiays on 2025/2/6.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import ListViewKit
import MarkdownView
import SnapKit
import UIKit

final class AiMessageView: MessageListRowView {
    private let viewProvider: DrawingViewProvider
    private(set) lazy var markdownView: MarkdownTextView = .init(viewProvider: viewProvider)

    var linkTapHandler: ((MarkdownTextView.LinkPayload, NSRange, CGPoint) -> Void)? {
        get { markdownView.linkHandler }
        set { markdownView.linkHandler = newValue }
    }

    var codePreviewHandler: ((String?, NSAttributedString) -> Void)? {
        get { markdownView.codePreviewHandler }
        set { markdownView.codePreviewHandler = newValue }
    }

    init(viewProvider: DrawingViewProvider) {
        self.viewProvider = viewProvider
        super.init(frame: .zero)
        configureSubviews()
    }

    @available(*, unavailable)
    @MainActor required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureSubviews() {
        markdownView.ignoresCharacterSetSuffixForCodeHighlighting = ["\u{25CF}", "`"]
        contentView.addSubview(markdownView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        markdownView.frame = contentView.bounds
    }
}
