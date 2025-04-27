//
//  CompactContentController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/10.
//

import UIKit

class CompactContentController: UITabBarController {
    let contents: [UIViewController] = [
        UINavigationController(
            rootViewController: ConversationListController()
        ).then {
            $0.navigationBar.prefersLargeTitles = true
            $0.tabBarItem = .init(
                title: NSLocalizedString("Chat", comment: ""),
                image: UIImage(systemName: "bubble.left.and.bubble.right"),
                tag: 0
            )
        },
        UINavigationController(
            rootViewController: SettingViewController()
        ).then {
            $0.navigationBar.prefersLargeTitles = true
            $0.tabBarItem = .init(
                title: NSLocalizedString("Settings", comment: ""),
                image: UIImage(systemName: "gear"),
                tag: 1
            )
        },
    ]

    init() {
        super.init(nibName: nil, bundle: nil)
        viewControllers = contents
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
