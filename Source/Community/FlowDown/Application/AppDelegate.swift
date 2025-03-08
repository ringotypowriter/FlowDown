//
//  AppDelegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import ConfigurableKit
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
        Settings.installTriggers()
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
}
