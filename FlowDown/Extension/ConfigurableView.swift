//
//  ConfigurableView.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/28/25.
//

import ConfigurableKit
import UIKit

class ConfigurableInfoView: ConfigurableView {
    var valueLabel: EasyHitButton { contentView as! EasyHitButton }

    private var onTapBlock: ((ConfigurableInfoView) -> Void) = { _ in }

    override init() {
        super.init()
        valueLabel.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        valueLabel.titleLabel?.numberOfLines = 0
        valueLabel.titleLabel?.textAlignment = .right
        valueLabel.contentHorizontalAlignment = .right
        valueLabel.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        valueLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(self.snp.width).dividedBy(2)
        }
    }

    func configure(value: String, isDestructive: Bool = false) {
        let attrString = NSAttributedString(string: value, attributes: [
            .foregroundColor: isDestructive ? .red : UIColor.accent,
            .font: UIFont.systemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
                weight: .semibold
            ),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
        valueLabel.setAttributedTitle(attrString, for: .normal)
    }

    @discardableResult
    func setTapBlock(_ block: @escaping (ConfigurableInfoView) -> Void) -> Self {
        onTapBlock = block
        return self
    }

    @objc private func tapped() {
        onTapBlock(self)
    }

    override class func createContentView() -> UIView {
        EasyHitButton()
    }
}

class ConfigurableToggleActionView: ConfigurableView {
    var switchView: UISwitch { contentView as! UISwitch }
    var boolValue: Bool = false {
        didSet {
            if switchView.isOn != boolValue {
                switchView.isOn = boolValue
            }
        }
    }

    var actionBlock: ((Bool) -> Void) = { _ in }

    override init() {
        super.init()
        switchView.onTintColor = .accent
        switchView.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
    }

    override open class func createContentView() -> UIView {
        UISwitch()
    }

    @objc open func valueChanged() {
        boolValue = switchView.isOn
        actionBlock(boolValue)
    }
}
