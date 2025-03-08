//
//  ModelAvailabilityEditorController+Cell.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/8.
//

import ConfigurableKit
import OrderedCollections
import UIKit

extension ModelAvailabilityEditorController {
    class CellViewModel: Identifiable, Hashable, Equatable {
        let id: UUID = .init()
        let modelType: ServiceProvider.ModelType
        let modelIdentifier: ServiceProvider.ModelIdentifier
        var bool: Bool
        var highlight: String

        init(
            modelType: ServiceProvider.ModelType,
            modelIdentifier: ServiceProvider.ModelIdentifier,
            bool: Bool = true,
            highlight: String = ""
        ) {
            self.modelType = modelType
            self.modelIdentifier = modelIdentifier
            self.bool = bool
            self.highlight = highlight
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(modelType)
            hasher.combine(modelIdentifier)
            hasher.combine(bool)
            hasher.combine(highlight)
        }

        static func == (lhs: CellViewModel, rhs: CellViewModel) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
    }

    class ConfigurableEphemeralBoolView: ConfigurableView {
        var switchView: UISwitch { contentView as! UISwitch }

        override class func createContentView() -> UIView {
            UISwitch()
        }
    }

    class Cell: UITableViewCell {
        let view = ConfigurableEphemeralBoolView()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            separatorInset = .zero
            let margin = AutoLayoutMarginView(view)
            contentView.addSubview(margin)
            margin.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            view.configure(icon: UIImage(systemName: "sun.min"))
            view.configure(description: "")
            view.switchView.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        private var identifier: CellViewModel.ID? = nil
        override func prepareForReuse() {
            super.prepareForReuse()
            identifier = nil
        }

        func configure(with vm: CellViewModel) {
            identifier = vm.id
            view.switchView.setOn(vm.bool, animated: false)

            let label = view.titleLabel
            label.text = ""

            let defaultAttrs: [NSAttributedString.Key: Any] = [
                .font: label.font ?? UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: label.textColor ?? .label,
            ]
            let attributed = NSMutableAttributedString(string: vm.modelIdentifier, attributes: defaultAttrs)
            let range = (attributed.string as NSString).range(of: vm.highlight)
            attributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: UIColor.accent],
                range: range
            )
            label.attributedText = attributed
        }

        @objc func switchValueChanged() {
            let value = view.switchView.isOn
            guard let parent = parentViewController as? ModelAvailabilityEditorController else { return }
            guard let id = identifier else { return }
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                parent.update(identifier: id, to: value)
            }
        }
    }

    class Header: UITableViewHeaderFooterView {
        let label = UILabel().then {
            $0.font = .preferredFont(forTextStyle: .caption1)
            $0.textColor = .label
            $0.numberOfLines = 0
        }

        let background = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            contentView.addSubview(background)
            contentView.addSubview(label)
            background.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            label.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.top.bottom.equalToSuperview().inset(8)
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        func configure(with title: String) {
            label.text = title
        }
    }
}
