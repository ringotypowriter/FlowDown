//
//  SettingController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import AlertController
import UIKit

#if targetEnvironment(macCatalyst)
    class SettingController: AlertBaseController {
        override convenience init() {
            self.init(rootViewController: NavigationController())
            shouldDismissWhenTappedAround = false
            shouldDismissWhenEscapeKeyPressed = true
        }

        override func contentViewDidLoad() {
            super.contentViewDidLoad()
            contentView.backgroundColor = .background
        }

        class NavigationController: UINavigationController {
            let content = SettingContent()

            init() {
                super.init(rootViewController: content)
                navigationBar.prefersLargeTitles = false
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError()
            }
        }
    }
#else
    class SettingController: UINavigationController {
        init() {
            super.init(rootViewController: SettingContent())
            navigationBar.prefersLargeTitles = false
            modalPresentationStyle = .formSheet
            modalTransitionStyle = .coverVertical
            preferredContentSize = .init(width: 550, height: 550 - navigationBar.height)
            view.backgroundColor = .background
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }
    }
#endif

extension SettingController {
    enum EntryPage {
        case general
        case inference
        case modelManagement
        case modelEditor(model: ModelManager.ModelIdentifier)
        case tools
        case dataControl
        case permissionList
        case contactUs
    }

    private static var nextEntryPage: EntryPage?

    static func setNextEntryPage(_ page: EntryPage) {
        nextEntryPage = page
    }

    static func getNextEntryPage() -> EntryPage? {
        if let ret = nextEntryPage {
            nextEntryPage = nil
            return ret
        }
        return nil
    }
}
