//
//  AppDelegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import AlertController
import ChidoriMenu
import CloudKit
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
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
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
        ChidoriMenuConfiguration.suggestedWidth = nil // auto width

        templateMenuCancellable = ChatTemplateManager.shared.$templates
            .receive(on: DispatchQueue.main)
            .sink { _ in
                UIMenuSystem.main.setNeedsRebuild()
            }

        if !sdb.hasPerformedFirstSync {
            Task {
                try await sdb.performSyncFirstTimeSetup()
            }
        }

        application.registerForRemoteNotifications()

        return true
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken _: Data) {
        logger.info("Did register for remote notifications")
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("ERROR: Failed to register for notifications: \(error.localizedDescription)")
    }

    func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.noData)
            return
        }
        logger.info("Received cloudkit notification: \(notification)")

        guard notification.containerIdentifier == CloudKitConfig.containerIdentifier else {
            completionHandler(.noData)
            return
        }

        Task {
            do {
                logger.info("cloudkit notification fetchChanges")
                try await syncEngine.fetchChanges()
                completionHandler(.newData)
            } catch {
                logger.error("cloudkit notification fetchLatestChanges: \(error)")
                completionHandler(.failed)
            }
        }
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
