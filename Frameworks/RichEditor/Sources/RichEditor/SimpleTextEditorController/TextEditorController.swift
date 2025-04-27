//
//  TextEditorController.swift
//  RichEditor
//
//  Created by 秋星桥 on 1/18/25.
//

import AlertController
import UIKit

#if targetEnvironment(macCatalyst)
    typealias ContentHolderController = AlertBaseController
#else
    typealias ContentHolderController = UINavigationController
#endif

class TextEditorController: ContentHolderController {
    let rootController = TextEditorContentController()

    var text: String {
        get { rootController.text }
        set { rootController.text = newValue }
    }

    var callback: (String) -> Void {
        get { rootController.callback }
        set { rootController.callback = newValue }
    }

    var cancellable: Bool {
        get { rootController.cancellable }
        set { rootController.cancellable = newValue }
    }

    #if targetEnvironment(macCatalyst)
        override init() {
            super.init(
                rootViewController: UINavigationController(rootViewController: rootController),
                preferredWidth: 555,
                preferredHeight: 555
            )
        }
    #else
        init() {
            super.init(rootViewController: rootController)
            modalTransitionStyle = .coverVertical
            modalPresentationStyle = .formSheet
            preferredContentSize = .init(width: 555, height: 555 - navigationBar.frame.height)
            isModalInPresentation = true
        }
    #endif

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    #if !targetEnvironment(macCatalyst)
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
        }
    #endif
}

class TextEditorContentController: UIViewController {
    var text: String = ""
    var callback: ((String) -> Void) = { _ in }

    let textView = UITextView()
    var bottomOffset: CGFloat = 0

    init() {
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Text Editor", bundle: .module, comment: "")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    var cancellable: Bool = false {
        didSet { updateLeftButtons() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "Background")

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
        textView.clipsToBounds = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.isEditable = true
        view.addSubview(textView)

        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])

        assert(navigationController != nil)
        navigationItem.rightBarButtonItem = .init(
            systemItem: .done,
            primaryAction: .init { [weak self] _ in
                self?.done()
            }
        )

        updateLeftButtons()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layoutIfNeeded()
        textView.text = text
    }

    func updateLeftButtons() {
        if cancellable {
            navigationItem.leftBarButtonItem = .init(
                systemItem: .cancel,
                primaryAction: .init { [weak self] _ in
                    self?.cancelDone()
                }
            )
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }

    func done() {
        callback(textView.text)
        navigationController?.dismiss(animated: true)
    }

    func cancelDone() {
        textView.text = text // just in case
        navigationController?.dismiss(animated: true)
    }
}
