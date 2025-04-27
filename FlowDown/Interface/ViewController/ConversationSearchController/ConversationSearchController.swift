//
//  ConversationSearchController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/5/25.
//

import AlertController
import Storage
import UIKit

#if targetEnvironment(macCatalyst)
    class ConversationSearchController: AlertBaseController {
        init(callback: @escaping SearchCallback) {
            super.init(
                rootViewController: NavigationController(callback: callback),
                preferredWidth: 660,
                preferredHeight: 420
            )
            shouldDismissWhenTappedAround = true
            shouldDismissWhenEscapeKeyPressed = true
        }

        override func contentViewDidLoad() {
            super.contentViewDidLoad()
            contentView.backgroundColor = .background
        }

        class NavigationController: UINavigationController {
            init(callback: @escaping SearchCallback) {
                super.init(rootViewController: ContentController(callback: callback))
                navigationBar.prefersLargeTitles = false
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError()
            }
        }
    }
#else
    class ConversationSearchController: UINavigationController {
        init(callback: @escaping SearchCallback) {
            super.init(rootViewController: ContentController(callback: callback))
            navigationBar.prefersLargeTitles = false
            modalPresentationStyle = .formSheet
            modalTransitionStyle = .coverVertical
            preferredContentSize = .init(width: 550, height: 550 - navigationBar.height)
            view.backgroundColor = .background
            isModalInPresentation = false
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }
    }
#endif

extension ConversationSearchController {
    typealias SearchCallback = (Conversation.ID?) -> Void
}

extension ConversationSearchController {
    class ContentController: UIViewController {
        var callback: ((Conversation.ID) -> Void) = { _ in }

        init(callback: @escaping SearchCallback) {
            super.init(nibName: nil, bundle: nil)
            title = String(localized: "Search")
            self.callback = { [weak self] in
                callback($0)
                self?.callback = { _ in }
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            view.backgroundColor = .background
            navigationController?.setNavigationBarHidden(true, animated: false)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let nav = navigationController, nav.viewControllers.count > 1 {
                nav.setNavigationBarHidden(false, animated: animated)
            }
        }
    }
}
