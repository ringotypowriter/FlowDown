//
//  Value+UserInterfaceStyle.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/26/25.
//

import Combine
import ConfigurableKit
import Foundation
import UIKit

extension UIUserInterfaceStyle {
    static var cases: [UIUserInterfaceStyle] = [
        .light,
        .dark,
        .unspecified,
    ]

    var icon: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        case .unspecified: "circle"
        @unknown default: "circle"
        }
    }

    var title: String {
        switch self {
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        case .unspecified: String(localized: "System")
        @unknown default: String(localized: "System")
        }
    }

    var catalystAppearance: NSObject? {
        switch self {
        case .light:
            (NSClassFromString("NSAppearance") as? NSObject.Type)?
                .perform(NSSelectorFromString("appearanceNamed:"), with: "NSAppearanceNameAqua")?
                .takeUnretainedValue() as? NSObject
        case .dark:
            (NSClassFromString("NSAppearance") as? NSObject.Type)?
                .perform(NSSelectorFromString("appearanceNamed:"), with: "NSAppearanceNameDarkAqua")?
                .takeUnretainedValue() as? NSObject
        default: nil
        }
    }
}

extension UIUserInterfaceStyle {
    static let storageKey = "app.appearance.UIUserInterfaceStyle"
    private static var cancellables: Set<AnyCancellable> = []

    static let configurableObject: ConfigurableObject = .init(
        icon: "lightbulb",
        title: String(localized: "Appearance"),
        explain: String(localized: "Override system appearance, either light or dark."),
        key: storageKey,
        defaultValue: UIUserInterfaceStyle.unspecified.rawValue,
        annotation: .list {
            UIUserInterfaceStyle.cases.map { item -> ListAnnotation.ValueItem in
                .init(
                    icon: item.icon,
                    title: item.title,
                    rawValue: item.rawValue
                )
            }
        }
    )

    static func subscribeToConfigurableItem() {
        assert(cancellables.isEmpty)
        ConfigurableKit.publisher(forKey: storageKey, type: Int.self)
            .sink { input in
                var style: UIUserInterfaceStyle = .unspecified
                if let input, let value = UIUserInterfaceStyle(rawValue: input) {
                    style = value
                }
                UIView.animate(withDuration: 0.25) {
                    apply(style: style)
                }
            }
            .store(in: &cancellables)
    }

    static func apply(style: Self) {
        #if targetEnvironment(macCatalyst)
            let appearance = style.catalystAppearance
            let setAppearanceSelector = Selector(("setAppearance:"))
            guard let app = (NSClassFromString("NSApplication") as? NSObject.Type)?
                .value(forKey: "sharedApplication") as? NSObject,
                app.responds(to: setAppearanceSelector)
            else { return }
            app.perform(setAppearanceSelector, with: appearance)
        #else
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .forEach { $0.overrideUserInterfaceStyle = style }
        #endif
    }
}
