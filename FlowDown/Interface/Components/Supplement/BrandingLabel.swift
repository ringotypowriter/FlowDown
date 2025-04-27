//
//  BrandingLabel.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import UIKit

class BrandingLabel: UILabel {
    init() {
        super.init(frame: .zero)
        text = String(localized: "FlowDown")
        font = .systemFont(ofSize: UIFont.labelFontSize, weight: .semibold)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
