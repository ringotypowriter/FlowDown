//
//  SettingButton.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import UIKit

class SettingButton: UIButton {
    init() {
        super.init(frame: .zero)
        setImage(UIImage(systemName: "gearshape"), for: .normal)
        tintColor = .label

        accessibilityLabel = NSLocalizedString("Settings", comment: "Button to open settings")

        addTarget(self, action: #selector(openSetting), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func openSetting() {
        guard let parentViewController else { return }
        let settingController: UIViewController = FormNavigationController(
            viewController: SettingViewController()
        )
        parentViewController.present(settingController, animated: true)
    }
}
