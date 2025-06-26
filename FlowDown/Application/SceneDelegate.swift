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

    static var supposeToSendMessage: String? {
        didSet {
            guard let message = supposeToSendMessage, !message.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NotificationCenter.default.post(name: .sendNewMessage, object: message)
            }
        }
    }

    func scene(
        _ scene: UIScene, willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
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

        for urlContext in connectionOptions.urlContexts {
            handleIncomingURL(urlContext.url)
        }
    }

    func scene(_: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        for urlContext in contexts {
            handleIncomingURL(urlContext.url)
        }
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
            handleFlowDownURL(url)
        default:
            break
        }
    }

    private func prepareModelImport(from url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        Self.supposeToOpenModel.append(url)
    }

    private func handleFlowDownURL(_ url: URL) {
        print("[*] Handling FlowDown URL: \(url)")
        guard let host = url.host(), !host.isEmpty else {
            print("[*] No host found, just opening app")
            return
        }

        print("[*] URL host: \(host)")
        switch host {
        case "new":
            handleNewMessageURL(url)
        default:
            print("[*] Unknown action: \(host), just opening app")
        }
    }

    private func handleNewMessageURL(_ url: URL) {
        print("[*] Handling new message URL: \(url)")
        let pathComponents = url.pathComponents
        print("[*] Path components: \(pathComponents)")

        guard pathComponents.count >= 2 else {
            print("[*] Invalid format, should be /message")
            return
        }

        // extract msg from path
        let encodedMessage = pathComponents[1]
        print("[*] Encoded message: \(encodedMessage)")

        guard let message = encodedMessage.removingPercentEncoding,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            print("[*] Failed to decode message or message is empty")
            return
        }

        print("[*] Decoded message: \(message)")
        Self.supposeToSendMessage = message
    }

    func sceneDidDisconnect(_: UIScene) {}

    func sceneDidBecomeActive(_: UIScene) {}

    func sceneWillResignActive(_: UIScene) {}

    func sceneWillEnterForeground(_: UIScene) {}

    func sceneDidEnterBackground(_: UIScene) {}
}

extension Notification.Name {
    static let openModel = Notification.Name("openModel")
    static let sendNewMessage = Notification.Name("sendNewMessage")
}
