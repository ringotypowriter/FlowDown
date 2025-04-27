//
//  FormNavigationController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import UIKit

class FormNavigationController: UINavigationController {
    init(viewController: UIViewController) {
        super.init(rootViewController: viewController)

        navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        modalPresentationStyle = .formSheet
        modalTransitionStyle = .coverVertical
        preferredContentSize = CGSize(width: 500 + navigationBar.height, height: 500)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        for press in presses {
            guard let key = press.key else { continue }
            if key.keyCode == .keyboardEscape {
                didHandleEvent = true
                dismiss(animated: true)
            }
        }
        if didHandleEvent == false {
            super.pressesBegan(presses, with: event)
        }
    }
}
