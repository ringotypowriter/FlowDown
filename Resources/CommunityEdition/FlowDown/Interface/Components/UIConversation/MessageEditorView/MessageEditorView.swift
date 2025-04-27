//
//  MessageEditorView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import NumericTransitionLabel
import UIKit

private let controlBarHeight: CGFloat = 24

extension UIConversation {
    class MessageEditorView: UIView {
        weak var delegate: Delegate?

        let blurBackgroundView = UIVisualEffectView(
            effect: UIBlurEffect(style: .regular)
        )

        let stackView = UIStackView().then { stack in
            stack.axis = .vertical
            stack.spacing = 8
            stack.distribution = .equalSpacing
        }

        let textView = TextEditorView().then { view in
            view.font = .body
            view.setContentHuggingPriority(.required, for: .vertical)
            view.setContentCompressionResistancePriority(.required, for: .vertical)
        }

        let placeholderLabel = UILabel().then { label in
            label.font = .body
            label.textColor = .placeholderText
            #if targetEnvironment(macCatalyst)
                label.text = NSLocalizedString(
                    "Type a message...  (Press Option + Enter for New Line)",
                    comment: "Placeholder text for message editor"
                )
            #else
                label.text = NSLocalizedString(
                    "Type a message...",
                    comment: "Placeholder text for message editor"
                )
            #endif
        }

        let controlBarView = UIView().then { view in
            view.snp.makeConstraints { make in
                make.height.equalTo(controlBarHeight)
            }
        }

        let controlBarLeftStack = UIStackView().then { view in
            view.axis = .horizontal
            view.spacing = 16
            view.distribution = .equalSpacing
            view.alignment = .center
        }

        let textCountLabel = NumericTransitionLabel(font: .footnote.monospaced).then { view in
            view.textColor = .label
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let modelSelectButton = ModelSelectButton(modelType: .textCompletion)

        let controlBarRightStack = UIStackView().then { view in
            view.axis = .horizontal
            view.spacing = 16
            view.distribution = .equalSpacing
            view.alignment = .bottom
        }

        let sendButton = UIButton().then { view in
            view.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
            view.setTitleColor(.accent, for: .normal)
            view.imageView?.tintColor = .accent
            view.imageView?.contentMode = .scaleAspectFit
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
            view.accessibilityLabel = NSLocalizedString("Send", comment: "Send button")
        }

        init() {
            super.init(frame: .zero)

            masksToBounds = true
            clipsToBounds = true

            setupSubviews()
            layoutIfNeeded()
            updateContentStatus()

            textView.returnKeyPressed = { [weak self] in self?.submitMessage() }
            sendButton.addTarget(self, action: #selector(submitMessage), for: .touchUpInside)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        func collectViewModel() -> ViewModel {
            let vm = ViewModel()
            vm.message = textView.text
            return vm
        }

        @objc func submitMessage() {
            textView.text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let vm = collectViewModel()
            defer { updateContentStatus() }
            guard vm.isSendable else { return }
            textView.text = ""
            textView.resignFirstResponder()
            delegate?.messageEditorSubmitMessage(self, message: vm)
        }

        func updateContentStatus() {
            textView.snp.remakeConstraints {
                $0.height.equalTo(suggestedEditorHeight(textView))
            }
            textCountLabel.text = String(textView.text.count)
            sendButton.isEnabled = collectViewModel().isSendable
            sendButton.alpha = sendButton.isEnabled ? 1 : 0.5
            withAnimation { [self] in
                placeholderLabel.alpha = [
                    !textView.isFirstResponder,
                    textView.text.isEmpty,
                ].allSatisfy(\.self) ? 1 : 0

                superview?.layoutIfNeeded()
                layoutIfNeeded()
            }
        }
    }
}

private extension UIConversation.MessageEditorView {
    func setupSubviews() {
        addSubview(blurBackgroundView)
        addSubview(stackView)
        stackView.addArrangedSubviews([
            textView,
            controlBarView,
        ])

        blurBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        textView.addSubview(placeholderLabel)
        controlBarView.addSubviews([
            controlBarLeftStack,
            controlBarRightStack,
        ])

        textView.delegate = self
        placeholderLabel.snp.makeConstraints { make in
            make.top.left.equalToSuperview()
        }

        controlBarLeftStack.snp.makeConstraints { make in
            make.top.left.bottom.equalToSuperview()
        }
        controlBarLeftStack.alpha = 0.5
        controlBarLeftStack.addArrangedSubviews([
            textCountLabel,
            modelSelectButton,
        ])
        for arrangedSubview in controlBarLeftStack.arrangedSubviews {
            arrangedSubview.snp.makeConstraints { make in
                make.height.equalTo(controlBarHeight)
            }
        }

        controlBarRightStack.snp.makeConstraints { make in
            make.top.right.bottom.equalToSuperview()
            make.left.greaterThanOrEqualTo(controlBarLeftStack.snp.right)
        }

        controlBarRightStack.addArrangedSubviews([
            sendButton,
        ])
    }
}
