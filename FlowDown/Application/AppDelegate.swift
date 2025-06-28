//
//  AppDelegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import AlertController
import ChidoriMenu
import Combine
import ConfigurableKit
import MarkdownView
import MLX
import MLXLMCommon
import RichEditor
import ScrubberKit
import UIKit

@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var templateMenuCancellable: AnyCancellable?
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UITableView.appearance().backgroundColor = .clear
        UIButton.appearance().tintColor = .accent
        UITextView.appearance().tintColor = .accent
        UINavigationBar.appearance().tintColor = .accent
        UISwitch.appearance().onTintColor = .accent
        UIUserInterfaceStyle.subscribeToConfigurableItem()

        MLX.GPU.subscribeToConfigurableItem()
        EditorBehavior.subscribeToConfigurableItem()
        MarkdownTheme.subscribeToConfigurableItem()
        ScrubberConfiguration.subscribeToConfigurableItem()
        ScrubberConfiguration.setup() // build access control rule

        AlertControllerConfiguration.alertImage = .avatar
        AlertControllerConfiguration.accentColor = .accent
        AlertControllerConfiguration.backgroundColor = .background
        AlertControllerConfiguration.separatorColor = SeparatorView.color

        ChidoriMenuConfiguration.accentColor = UIColor.accent
        ChidoriMenuConfiguration.backgroundColor = UIColor.background
        
        templateMenuCancellable = ChatTemplateManager.shared.$templates
            .receive(on: DispatchQueue.main)
            .sink { _ in
                UIMenuSystem.main.setNeedsRebuild()
            }
        return true
    }

    func application(
        _: UIApplication,
        didDiscardSceneSessions _: Set<UISceneSession>
    ) {}

    func applicationDidBecomeActive(_: UIApplication) {
        MLX.GPU.onApplicationBecomeActivate()
    }

    func applicationWillResignActive(_: UIApplication) {
        MLX.GPU.onApplicationResignActivate()
    }
}
