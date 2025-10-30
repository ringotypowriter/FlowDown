//
//  CodeEditorController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/24/25.
//

import RunestoneEditor
import RunestoneLanguageSupport
import RunestoneThemeSupport
import UIKit

class CodeEditorController: UIViewController {
    let textView = RunestoneEditorView.new()

    let indicator = UIActivityIndicatorView()
    private lazy var doneBarButtonItem: UIBarButtonItem = .init(
        barButtonSystemItem: .done,
        target: self,
        action: #selector(done)
    )
    private lazy var spinnerBarButtonItem: UIBarButtonItem = .init(customView: indicator)

    private func updateRightBarButtonItems() {
        if indicator.isAnimating {
            navigationItem.rightBarButtonItems = [doneBarButtonItem, spinnerBarButtonItem]
        } else {
            navigationItem.rightBarButtonItems = [doneBarButtonItem]
        }
    }

    init(language: String? = nil, text: String) {
        super.init(nibName: nil, bundle: nil)

        indicator.startAnimating()

        textView.clipsToBounds = true
        textView.alwaysBounceVertical = true
        textView.isEditable = true
        textView.text = text
        textView.apply(theme: TomorrowTheme())

        if let language,
           let languageObject = TreeSitterLanguage.language(withIdentifier: language)
        {
            textView.applyAsync(language: languageObject, text: text) { [weak self] in
                self?.indicator.stopAnimating()
                self?.updateRightBarButtonItems()
            }
        } else if let languageObject = TreeSitterLanguage.language(withIdentifier: "markdown") {
            textView.applyAsync(language: languageObject, text: text) { [weak self] in
                self?.indicator.stopAnimating()
                self?.updateRightBarButtonItems()
            }
        } else {
            indicator.stopAnimating()
            updateRightBarButtonItems()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private var collector: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .background

        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        textView.textContainerInset.bottom = 400

        updateRightBarButtonItems()
    }

    @objc func done() {
        if let collector { collector(textView.text) }
        dispose()
    }

    @objc func dispose() {
        if navigationController?.viewControllers.count == 1 {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    func collectEditedContent(_ block: @escaping (String) -> Void) {
        assert(collector == nil)
        assert(textView.isEditable)
        collector = block
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(dispose)
            ),
        ]
    }
}
