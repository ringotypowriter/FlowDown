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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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

        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }

    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let urlContext = URLContexts.first else { return }
        handleIncomingURL(urlContext.url)
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
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DisposableResources")
            .appendingPathComponent("WillImportedModels")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempFileURL = tempDir.appendingPathComponent(url.lastPathComponent)

            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }

            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            try FileManager.default.copyItem(at: url, to: tempFileURL)

            Self.supposeToOpenModel.append(tempFileURL)
        } catch {
            print("error handling .fdmodel file: \(error)")
        }
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
