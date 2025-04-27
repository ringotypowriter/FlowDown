//
//  TextView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Foundation

class TextView: UITextView {
    override var intrinsicContentSize: CGSize {
        .init(width: bounds.width, height: attributedText.measureHeight(usingWidth: bounds.width))
    }

    #if DEBUG
        private var setupCompleted: Bool = false
    #endif

    override required init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commitInit()
    }

    convenience init() {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            self.init(usingTextLayoutManager: false)
        } else {
            self.init(frame: .zero, textContainer: nil)
            _ = layoutManager.textContainers
        }
        commitInit()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func commitInit() {
        #if DEBUG
            assert(!setupCompleted)
            setupCompleted = true
        #endif
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        textColor = .label
        textContainer.lineFragmentPadding = .zero
        textAlignment = .natural
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineBreakMode = .byTruncatingTail
        clipsToBounds = false
        isSelectable = true
        isScrollEnabled = true
    }
}
