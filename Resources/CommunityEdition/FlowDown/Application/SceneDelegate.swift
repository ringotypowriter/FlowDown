//
//  SceneDelegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import Combine
import ConfigurableKit
import UIKit

@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var cancellables = Set<AnyCancellable>()

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        #if targetEnvironment(macCatalyst)
            if let titlebar = windowScene.titlebar {
                titlebar.titleVisibility = .hidden
                titlebar.toolbar = nil
            }
        #endif
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 800, height: 500)

        ConfigurableKit.publisher(forKey: .theme, type: String.self)
            .sink { [weak self] input in
                guard let window = self?.window,
                      let input,
                      let theme = InterfaceStyle(rawValue: input)
                else { return }

                window.overrideUserInterfaceStyle = theme.style

                let appearance = theme.appearance
                let setAppearanceSelector = Selector(("setAppearance:"))
                guard let app = (NSClassFromString("NSApplication") as? NSObject.Type)?
                    .value(forKey: "sharedApplication") as? NSObject,
                    app.responds(to: setAppearanceSelector)
                else { return }
                app.perform(setAppearanceSelector, with: appearance)
            }
            .store(in: &cancellables)
    }

    func sceneDidDisconnect(_: UIScene) {}

    func sceneDidBecomeActive(_: UIScene) {}

    func sceneWillResignActive(_: UIScene) {}

    func sceneWillEnterForeground(_: UIScene) {}

    func sceneDidEnterBackground(_: UIScene) {}
}
