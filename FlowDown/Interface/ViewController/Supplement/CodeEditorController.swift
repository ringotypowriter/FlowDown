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

    init(language: String? = nil, text: String) {
        super.init(nibName: nil, bundle: nil)
        edgesForExtendedLayout = []

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
                self?.indicator.removeFromSuperview()
            }
        } else if let languageObject = TreeSitterLanguage.language(withIdentifier: "markdown") {
            textView.applyAsync(language: languageObject, text: text) { [weak self] in
                self?.indicator.stopAnimating()
                self?.indicator.removeFromSuperview()
            }
        } else {
            indicator.stopAnimating()
            indicator.removeFromSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private var collector: ((String) -> Void)? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .background

        navigationController?.navigationBar.backgroundColor = .background

        let sep = SeparatorView()
        view.addSubview(sep)
        sep.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.height.equalTo(1)
        }

        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalTo(sep.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(done)
            ),
            UIBarButtonItem(
                customView: indicator
            ),
        ]
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
