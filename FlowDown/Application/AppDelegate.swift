//
//  AppDelegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import AlertController
import ChidoriMenu
import ConfigurableKit
import MarkdownView
import MLX
import MLXLMCommon
import RichEditor
import ScrubberKit
import UIKit

@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
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

        return true
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
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
