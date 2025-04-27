//
//  TextEditorContentController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/24/25.
//

import UIKit

class TextEditorContentController: UIViewController {
    var text: String = ""
    var callback: ((String) -> Void) = { _ in }

    let textView = UITextView()
    var bottomOffset: CGFloat = 0

    init() {
        super.init(nibName: nil, bundle: nil)
        title = String(localized: "Text Editor")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        edgesForExtendedLayout = []

        view.backgroundColor = .background
        let coverView = UIView().with { $0.backgroundColor = .background }
        view.addSubview(coverView)
        // fix nav bar blinking
        coverView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(-250)
            make.left.right.equalToSuperview()
        }

        textView.font = .monospacedSystemFont(
            ofSize: UIFont.systemFontSize,
            weight: .regular
        )
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false
        textView.textColor = .label
        textView.textAlignment = .natural
        textView.backgroundColor = .clear
        textView.textContainerInset = .init(top: 0, left: 10, bottom: 0, right: 10)
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.textContainer.lineFragmentPadding = .zero
        textView.textContainer.maximumNumberOfLines = 0
        textView.font = .preferredFont(forTextStyle: .body)
        textView.clipsToBounds = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.isEditable = true
        view.addSubview(textView)

        textView.snp.makeConstraints { make in
            make.top.leading.right.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }

        assert(navigationController != nil)
        navigationItem.rightBarButtonItem = .init(
            systemItem: .done,
            primaryAction: .init { [weak self] _ in
                self?.done()
            }
        )

        navigationItem.leftBarButtonItem = .init(
            systemItem: .cancel,
            primaryAction: .init { [weak self] _ in
                self?.cancelDone()
            }
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        textView.text = text
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    open func done() {
        callback(textView.text)
        navigationController?.popViewController(animated: true)
    }

    open func cancelDone() {
        textView.text = text // just in case
        navigationController?.popViewController(animated: true)
    }
}
