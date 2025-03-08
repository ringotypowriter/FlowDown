//
//  Settings+Data.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/15.
//

import ConfigurableKit
import Foundation
import Network
import UIKit

extension Settings {
    private static var dataSettingsList: [ConfigurableObject] = [
        ConfigurableObject(
            icon: "trash",
            title: NSLocalizedString("Delete All Conversation", comment: ""),
            explain: NSLocalizedString("Delete all conversation data, including messages and media.", comment: ""),
            key: SettingsKey.theme.rawValue,
            defaultValue: InterfaceStyle.system.rawValue,
            annotation: .action { controller in
                guard let controller else { return }
                let alert = UIAlertController(
                    title: NSLocalizedString("Delete All Conversation", comment: ""),
                    message: NSLocalizedString("Are you sure you want to delete all conversation data?", comment: ""),
                    preferredStyle: .alert
                )
                alert.addAction(.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
                alert.addAction(.init(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in
                    ConversationManager.shared.removeAll()
                })
                controller.present(alert, animated: true)
            }
        ),
        ConfigurableObject(
            icon: "network",
            title: NSLocalizedString("Request Local Access", comment: ""),
            explain: NSLocalizedString("Request access to local area network for local inference.", comment: ""),
            key: SettingsKey.theme.rawValue,
            defaultValue: InterfaceStyle.system.rawValue,
            annotation: .action { controller in
                let alert = UIAlertController(
                    title: NSLocalizedString("Request Local Access", comment: ""),
                    message: NSLocalizedString("Access to local area network is requested, please confirm in the system settings if needed.", comment: ""),
                    preferredStyle: .alert
                )
                alert.addAction(.init(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
                    _ = ProcessInfo.processInfo.hostName
                })
                controller?.present(alert, animated: true)
            }
        ),
    ]

    static let dataSettings = ConfigurableObject(
        icon: "folder.badge.person.crop",
        title: NSLocalizedString("Data", comment: ""),
        ephemeralAnnotation: .submenu { dataSettingsList }
    )
}
