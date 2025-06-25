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

    static var supposeToOpenModel: [URL] = [] {
        didSet {
            guard !supposeToOpenModel.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .openModel, object: nil)
            }
        }
    }

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        #if targetEnvironment(macCatalyst)
            if let titlebar = windowScene.titlebar {
                titlebar.titleVisibility = .hidden
                titlebar.toolbar = nil
            }
        #endif
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 1100, height: 650)

        UIView.setAnimationsEnabled(false)
        DispatchQueue.main.async { UIView.setAnimationsEnabled(true) }

        for urlContext in connectionOptions.urlContexts { handleIncomingURL(urlContext.url) }
    }

    func scene(_: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        for urlContext in contexts { handleIncomingURL(urlContext.url) }
    }

    private func handleIncomingURL(_ url: URL) {
        switch url.scheme {
        case "file":
            switch url.pathExtension {
            case "fdmodel", "plist":
                prepareModelImport(from: url)
            default: break // dont know how
            }
        case "flowdown":
            break // just open our app
        default:
            break
        }
    }

    private func prepareModelImport(from url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        Self.supposeToOpenModel.append(url)
    }

    func sceneDidDisconnect(_: UIScene) {}

    func sceneDidBecomeActive(_: UIScene) {}

    func sceneWillResignActive(_: UIScene) {}

    func sceneWillEnterForeground(_: UIScene) {}

    func sceneDidEnterBackground(_: UIScene) {}
}

extension Notification.Name {
    static let openModel = Notification.Name("openModel")
}
