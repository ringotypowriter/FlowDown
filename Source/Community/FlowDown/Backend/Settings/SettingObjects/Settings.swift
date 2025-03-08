//
//  Settings.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/6.
//

import Combine
import ConfigurableKit
import Foundation

enum Settings {
    private static var cancellables: Set<AnyCancellable> = []
    static func installTriggers() {
        assert(cancellables.isEmpty)
        ConfigurableKit.publisher(forKey: .serviceProvider, type: [ServiceProvider].self).sink { _ in
            checkOrRevokeDefaultModel()
        }.store(in: &cancellables)
    }

    static let manifest = ConfigurableManifest(
        title: NSLocalizedString("Setting", comment: ""),
        list: rootList,
        footer: [
            Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "-",
            NSLocalizedString("Version", comment: ""),
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-",
            NSLocalizedString("Build", comment: ""),
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-",
        ].joined(separator: " ")
    )

    static let rootList: [ConfigurableObject] = [
        appSettings,
        dataSettings,
        modelSettings,
    ]
}
