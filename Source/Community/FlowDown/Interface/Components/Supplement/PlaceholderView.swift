//
//  PlaceholderView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/7.
//

import UIKit

class PlaceholderView: UIView {
    lazy var stackView = UIStackView(arrangedSubviews: [iconView, label]).then {
        $0.axis = .vertical
        $0.spacing = 20
        $0.alignment = .center
        $0.distribution = .equalSpacing
    }

    let iconView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.tintColor = .label
        $0.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }
    }

    let label = UILabel().then {
        $0.font = .body
        $0.textColor = .label
        $0.numberOfLines = 0
        $0.textAlignment = .center
    }

    init(icon: UIImage = .placeholderEmpty, text: String) {
        super.init(frame: .zero)

        iconView.image = icon
        label.text = text

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.lessThanOrEqualToSuperview().inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
