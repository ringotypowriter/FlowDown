import AlertController
import Foundation
import UIKit

enum DistributionChannel {
    case appStore
    case gitHub
}

class UpdateManager {
    static let shared = UpdateManager()
    let currentChannel: DistributionChannel
    
    private init() {
        #if targetEnvironment(macCatalyst)
        if let receiptUrl = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: receiptUrl.path)
        {
            print("[+] Found App Store receipt at \(receiptUrl)")
            self.currentChannel = .appStore
        } else {
            print("[+] No App Store receipt found, using GitHub for updates.")
            self.currentChannel = .gitHub
        }
        #else
        self.currentChannel = .appStore // it's impossible to distribute iOS/iPadOS app through GitHub (right?)
        #endif
        self.check()
    }
    
    private var localVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version).\(build)"
    }
    
    func check(from controller: UIViewController? = nil) {
        print("[+] Checking for updates...")
        print("[+] Current version: \(self.localVersion)")
        if self.currentChannel == .gitHub {
            self.checkGitHubUpdate(from: controller)
        }
//        else {
//            () // don't check update in other channels.
//        }
    }

    private func checkGitHubUpdate(from controller: UIViewController? = nil) {
        guard let url = URL(string: "https://api.github.com/repos/Lakr233/FlowDown/releases/latest") else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let _ = json["body"] as? String, // maybe display updatelog.
                      let htmlUrl = json["html_url"] as? String,
                      let draft = json["draft"] as? Bool,
                      let prerelease = json["prerelease"] as? Bool,
                      !draft,
                      !prerelease
                else {
                    return
                }
                if tagName > self.localVersion {
                    print("[+] Found update: \(tagName). Alert user to download upgrade.")
                    await MainActor.run {
                        let alert = AlertViewController(
                            title: String(localized: "Update Available"),
                            message: String(
                                format: String(localized: "A new version %@ is available. \nPlease update to enjoy the latest features and improvements."),
                                tagName
                            )
                        ) { context in
                            context.addAction(title: String(localized: "Cancel")) {
                                context.dispose()
                            }
                            context.addAction(title: String(localized: "Download"),attribute: .dangerous) {
                                context.dispose()
                                if let url = URL(string: htmlUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    
                        // 获取最顶层的视图控制器来展示弹窗
                        let presentingController: UIViewController
                        if let controller = controller {
                            // 如果传入了控制器，检查它是否正在展示其他视图控制器
                            presentingController = controller.presentedViewController ?? controller
                        } else {
                            // 如果没有传入controller，获取最顶层的视图控制器
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let rootViewController = window.rootViewController
                            {
                                var topController = rootViewController
                                while let presented = topController.presentedViewController {
                                    topController = presented
                                }
                                presentingController = topController
                            } else {
                                return // 无法找到合适的视图控制器
                            }
                        }
                        
                        presentingController.present(alert, animated: true)
                    }
                }
            } catch {
                return
            }
        }
    }
}
