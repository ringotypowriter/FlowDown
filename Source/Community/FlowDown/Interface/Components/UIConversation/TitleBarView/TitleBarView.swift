//
//  TitleBarView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import NumericTransitionLabel
import UIKit

extension UIConversation {
    class TitleBarView: UIView {
        let avatarImageView = CircleImageView().then { view in
            view.tintColor = .label
        }

        let titleLabel = NumericTransitionLabel(font: .title.bold).then {
            $0.clipsToBounds = true
            $0.textColor = .label
        }

        let menuButton = UIButton().then { view in
            view.setImage(UIImage(systemName: "ellipsis"), for: .normal)
            view.imageView?.contentMode = .scaleAspectFill
            view.tintColor = .label
        }

        weak var delegate: Delegate?

        init() {
            super.init(frame: .zero)
            setupViews()

            menuButton.menu = .init(options: [.displayInline, .singleSelection], children: [
                UIDeferredMenuElement.uncached { [weak self] provider in
                    let menu = self?.delegate?.titleBarCreateContextMenu() ?? []
                    provider(menu)
                },
            ])
            menuButton.showsMenuAsPrimaryAction = true
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }
    }
}

extension UIConversation.TitleBarView {
    func setupViews() {
        addSubviews([
            avatarImageView,
            titleLabel,
            menuButton,
        ])

        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        let titleLayoutGuide = UILayoutGuide()
        addLayoutGuide(titleLayoutGuide)
        titleLayoutGuide.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(16)
            make.centerY.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLayoutGuide)
            make.right.lessThanOrEqualTo(titleLayoutGuide)
            make.centerY.equalToSuperview()
        }

        menuButton.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(32)
        }
    }
}
