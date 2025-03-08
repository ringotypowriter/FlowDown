//
//  ProgressCoverView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import Foundation
import UIKit

extension UIConversation {
    class ProgressCoverView: UIView {
        let vfx = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        let indicator = UIActivityIndicatorView(style: .large)

        init() {
            super.init(frame: .zero)

            addSubview(vfx)
            vfx.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            addSubview(indicator)
            indicator.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }

            indicator.startAnimating()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }
    }
}
