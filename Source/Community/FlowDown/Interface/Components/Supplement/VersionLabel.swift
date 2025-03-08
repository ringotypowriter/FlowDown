//
//  VersionLabel.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import UIKit

class VersionLabel: UILabel {
    init() {
        super.init(frame: .zero)
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        text = String(format: NSLocalizedString("Version %@ (%@)", comment: ""), version, build)
        font = .systemFont(ofSize: UIFont.labelFontSize, weight: .semibold)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
