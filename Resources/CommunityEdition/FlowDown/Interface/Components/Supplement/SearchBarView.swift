//
//  SearchBarView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import UIKit

class SearchBarView: UIView {
    let backgroundView = UIView().then { view in
        view.layerBorderColor = .label.withAlphaComponent(0.25)
        view.layerBorderWidth = 1
        view.layerCornerRadius = 8
        view.backgroundColor = .label.withAlphaComponent(0.1)
    }

    init() {
        super.init(frame: .zero)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        addSubview(backgroundView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
