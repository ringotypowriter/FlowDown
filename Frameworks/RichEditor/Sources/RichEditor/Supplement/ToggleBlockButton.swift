//
//  ToggleBlockButton.swift
//  RichEditor
//
//  Created by 秋星桥 on 1/17/25.
//

import UIKit

class ToggleBlockButton: BlockButton {
    var isOn: Bool = false {
        didSet {
            updateUI()
            onValueChanged()
        }
    }

    var onValueChanged: () -> Void = {}

    override var actionBlock: () -> Void {
        get { super.actionBlock }
        set { fatalError() }
    }

    override init(text: String, icon: String) {
        super.init(text: text, icon: icon)
        super.actionBlock = { [weak self] in self?.isOn.toggle() }
    }

    var strikeThrough: Bool = false {
        didSet { updateUI() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateUI()
    }

    func updateUI() {
        if isOn {
            applyOnAppearance()
        } else {
            applyDefaultAppearance()
        }
    }

    func applyOnAppearance() {
        borderView.layer.borderColor = UIColor.accent.cgColor
        borderView.backgroundColor = .accent
        iconView.tintColor = .white
        titleLabel.textColor = .white
        updateStrikes()
    }

    override func applyDefaultAppearance() {
        super.applyDefaultAppearance()
        updateStrikes()
    }

    func updateStrikes() {
        let attrText = titleLabel.attributedText?.mutableCopy() as? NSMutableAttributedString
        attrText?.addAttribute(
            .strikethroughStyle,
            value: strikeThrough ? 1 : 0,
            range: NSRange(location: 0, length: attrText?.length ?? 0)
        )
        titleLabel.attributedText = attrText
    }
}
