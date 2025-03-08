//
//  Settings+App.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import ConfigurableKit
import Foundation

extension Settings {
    private static let appearanceObject: ConfigurableObject = .init(
        icon: "moon",
        title: NSLocalizedString("Appearance", comment: ""),
        explain: NSLocalizedString("Select the light or dark appearance.", comment: ""),
        key: SettingsKey.theme.rawValue,
        defaultValue: InterfaceStyle.system.rawValue,
        annotation: .list { [
            .init(
                icon: "circle.righthalf.fill",
                title: NSLocalizedString("System", comment: ""),
                section: NSLocalizedString("System", comment: ""),
                rawValue: InterfaceStyle.system.rawValue
            ),
            .init(
                icon: "sun.min",
                title: NSLocalizedString("Always Light", comment: ""),
                section: NSLocalizedString("Override", comment: ""),
                rawValue: InterfaceStyle.light.rawValue
            ),
            .init(
                icon: "moon",
                title: NSLocalizedString("Always Dark", comment: ""),
                section: NSLocalizedString("Override", comment: ""),
                rawValue: InterfaceStyle.dark.rawValue
            ),
        ] }
    )
    private static let updateObject: ConfigurableObject = .init(
        icon: "arrow.up",
        title: NSLocalizedString("Check Updates", comment: ""),
        explain: NSLocalizedString("Check for updates manually.", comment: ""),
        ephemeralAnnotation: .action { viewController in
            let alert = UIAlertController(
                title: "",
                message: NSLocalizedString("No updates available.", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("OK", comment: ""),
                style: .default,
                handler: nil
            ))
            viewController?.present(alert, animated: true)
        }
    )

    static let appSettings: ConfigurableObject = .init(
        icon: "app.badge",
        title: NSLocalizedString("Application", comment: ""),
        ephemeralAnnotation: .submenu { [
            appearanceObject,
            updateObject,
        ] }
    )
}
