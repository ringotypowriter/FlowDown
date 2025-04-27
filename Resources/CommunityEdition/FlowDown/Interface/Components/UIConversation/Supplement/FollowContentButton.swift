//
//  FollowContentButton.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/10.
//

import UIKit

extension UIConversation {
    class FollowContentButton: UIView {
        let imageView = UIImageView()
        let titleLabel = UILabel()

        var onTap: () -> Void = {}

        init() {
            super.init(frame: .zero)

            backgroundColor = .systemBackground
            layerShadowColor = .black
            layerShadowOffset = .zero
            layerShadowRadius = 8
            layerShadowOpacity = 0.15

            addSubview(titleLabel)
            addSubview(imageView)

            imageView.contentMode = .scaleAspectFit
            imageView.image = UIImage(
                systemName: "arrow.down",
                withConfiguration: UIImage.SymbolConfiguration(weight: .bold)
            )
            imageView.tintColor = .label
            imageView.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.centerY.equalToSuperview()
            }

            titleLabel.font = .preferredFont(forTextStyle: .footnote).bold
            titleLabel.textColor = .label
            titleLabel.text = NSLocalizedString("Back to New Contents", comment: "")
            titleLabel.snp.makeConstraints { make in
                make.top.bottom.right.equalToSuperview().inset(16)
                make.left.equalTo(imageView.snp.right).offset(8)
            }

            isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(buttonTapped))
            addGestureRecognizer(tap)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = min(frame.width, frame.height) / 2
        }

        @objc private func buttonTapped() {
            onTap()
        }
    }
}
