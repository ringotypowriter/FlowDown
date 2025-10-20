//
//  Indicator.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/29/25.
//

import AlertController
import Foundation
import SafariServices
import SPIndicator
import UIKit

enum Indicator {
    private static func ensureMainThread(_ execute: @escaping () -> Void) {
        if Thread.isMainThread {
            execute()
        } else {
            DispatchQueue.main.asyncAndWait {
                execute()
            }
        }
    }

    static func present(
        title: String,
        message: String? = nil,
        preset: SPIndicatorIconPreset = .done,
        haptic: SPIndicatorHaptic = .success,
        referencingView: UIView? = nil
    ) {
        ensureMainThread {
            let view = SPIndicatorView(title: title, message: message, preset: preset)
            if let window = referencingView as? UIWindow {
                view.presentWindow = window
            } else if let window = referencingView?.window {
                view.presentWindow = window
            }
            view.present(haptic: haptic, completion: nil)
        }
    }

    typealias CompletionHandler = (_ dismissComplete: @escaping @MainActor () -> Void) -> Void
    typealias CompletionExecutor = (_ completionHandler: @escaping CompletionHandler) -> Void
    static func progress(
        title: String,
        message: String? = nil,
        controller: UIViewController,
        completionExecutor: @escaping CompletionExecutor
    ) {
        ensureMainThread {
            let alert = AlertProgressIndicatorViewController(title: title, message: message ?? "")
            controller.present(alert, animated: true)
            let handler: (_ dismissComplete: @escaping () -> Void) -> Void = { block in
                ensureMainThread {
                    alert.dismiss(animated: true) {
                        block()
                    }
                }
            }
            DispatchQueue.global().async {
                completionExecutor(handler)
            }
        }
    }

    static func present(_ url: URL, showThirdPartyContentWarning: Bool = true, referencedView: UIView?) {
        if showThirdPartyContentWarning {
            let alert = AlertViewController(
                title: String(localized: "Third Party Content"),
                message: String(localized: "We are not responsible for the content of this website you are about to visit.")
            ) { context in
                context.addAction(title: String(localized: "Cancel")) {
                    context.dispose()
                }
                context.addAction(title: String(localized: "Open"), attribute: .dangerous) {
                    context.dispose {
                        #if targetEnvironment(macCatalyst)
                            UIApplication.shared.open(url)
                        #else
                            let safari = SFSafariViewController(url: url)
                            safari.modalPresentationStyle = .formSheet
                            safari.preferredContentSize = CGSize(width: 555, height: 555)
                            referencedView?.parentViewController?.present(safari, animated: true)
                        #endif
                    }
                }
            }
            referencedView?.parentViewController?.present(alert, animated: true)
        } else {
            #if targetEnvironment(macCatalyst)
                UIApplication.shared.open(url)
            #else
                let safari = SFSafariViewController(url: url)
                safari.modalPresentationStyle = .formSheet
                safari.preferredContentSize = CGSize(width: 555, height: 555)
                referencedView?.parentViewController?.present(safari, animated: true)
            #endif
        }
    }

    static func open(_ url: URL, showThirdPartyContentWarning: Bool = true, referencedView: UIView?) {
        if showThirdPartyContentWarning {
            let alert = AlertViewController(
                title: String(localized: "Third Party Content"),
                message: String(localized: "We are not responsible for the content of this website you are about to visit.")
            ) { context in
                context.addAction(title: String(localized: "Cancel")) {
                    context.dispose()
                }
                context.addAction(title: String(localized: "Open"), attribute: .dangerous) {
                    context.dispose {
                        UIApplication.shared.open(url)
                    }
                }
            }
            referencedView?.parentViewController?.present(alert, animated: true)
        } else {
            UIApplication.shared.open(url)
        }
    }
}
