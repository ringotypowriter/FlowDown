//
//  MessageSecondaryBarView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/4.
//

import Foundation
import UIKit

class MessageSecondaryBarView: UIView {
    let stackView = UIStackView().then { stackView in
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
    }

    enum Gravity {
        case left
        case right
    }

    let dateLabel = UILabel().then { label in
        label.font = .footnote
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
    }

    lazy var optionsMenuButton = MenuButton { [weak self] in
        self?.message?.createMenu(referencingView: self ?? .init())
    }.then { $0.alpha = 0.5 }

    init(gravity: Gravity) {
        super.init(frame: .zero)
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            switch gravity {
            case .left:
                make.left.equalToSuperview()
            case .right:
                make.right.equalToSuperview()
            }
        }

        var views: [UIView] = [
            dateLabel,
            optionsMenuButton,
        ]
        if gravity == .right { views.reverse() }
        views.forEach(stackView.addArrangedSubview)

        alpha = 0.5
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private var message: Conversation.Message?
    func use(message: Conversation.Message?) {
        self.message = message
        updateContent()
    }

    func reset() {
        dateLabel.text = nil
    }

    func updateContent() {
        guard let message else {
            reset()
            return
        }
        dateLabel.text = message.date.formatted(date: .numeric, time: .shortened)
    }
}
