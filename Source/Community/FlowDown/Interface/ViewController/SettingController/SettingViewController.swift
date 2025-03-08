//
//  SettingViewController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import ConfigurableKit
import UIKit

class SettingViewController: ConfigurableViewController {
    init() {
        super.init(manifest: Settings.manifest)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .comfortableBackground
        if navigationController?.modalPresentationStyle == .formSheet {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissModal)
            )
        }
    }

    @objc func dismissModal() {
        dismiss(animated: true)
    }
}
