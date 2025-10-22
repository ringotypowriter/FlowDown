//
//  SyncScopePage.swift
//  FlowDown
//
//  Created by AI on 2025/10/22.
//

import AlertController
import ConfigurableKit
import Storage
import UIKit

final class SyncScopePage: StackScrollController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        title = String(localized: "Sync Scope")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
    }

    override func setupContentViews() {
        super.setupContentViews()
        stackView.addArrangedSubview(SeparatorView())

        func addGroupToggle(icon: String, title: String, desc: String, group: SyncPreferences.Group) {
            let toggle = ConfigurableToggleActionView()
            toggle.configure(icon: UIImage(systemName: icon))
            toggle.configure(title: title)
            toggle.configure(description: desc)
            toggle.boolValue = SyncPreferences.isGroupEnabled(group)
            toggle.actionBlock = { value in
                SyncPreferences.setGroup(group, enabled: value)
            }
            stackView.addArrangedSubviewWithMargin(toggle)
            stackView.addArrangedSubview(SeparatorView())
        }

        addGroupToggle(
            icon: "text.bubble",
            title: String(localized: "Conversations, Messages, Attachments"),
            desc: String(localized: "Sync chats and their messages and files."),
            group: .conversations
        )

        addGroupToggle(
            icon: "brain.head.profile",
            title: String(localized: "Memory"),
            desc: String(localized: "Sync your AI memory entries."),
            group: .memory
        )

        addGroupToggle(
            icon: "rectangle.3.group.bubble.left",
            title: String(localized: "MCP Servers"),
            desc: String(localized: "Sync configured MCP connections."),
            group: .mcp
        )

        addGroupToggle(
            icon: "icloud",
            title: String(localized: "Models"),
            desc: String(localized: "Sync cloud model configurations."),
            group: .models
        )

        // Manual fetch action moved here; updated copy per requirements
        let refreshAction = ConfigurableObject(
            icon: "arrow.clockwise.icloud",
            title: String(localized: "手动从 iCloud 刷新"),
            explain: String(localized: "立即拉取更新"),
            ephemeralAnnotation: .action { controller in
                guard let controller else { return }

                guard SyncEngine.isSyncEnabled else {
                    let alert = AlertViewController(
                        title: String(localized: "Error Occurred"),
                        message: String(localized: "iCloud synchronization is not enabled")
                    ) { context in
                        context.addAction(title: String(localized: "OK"), attribute: .dangerous) { context.dispose() }
                    }
                    controller.present(alert, animated: true)
                    return
                }

                Indicator.progress(title: String(localized: "Refreshing..."), controller: controller) { completion in
                    Task { @MainActor in
                        do {
                            try await syncEngine.fetchChanges()
                            completion {}
                        } catch {
                            completion {}
                            let alert = AlertViewController(
                                title: String(localized: "Error Occurred"),
                                message: error.localizedDescription
                            ) { context in
                                context.addAction(title: String(localized: "OK"), attribute: .dangerous) { context.dispose() }
                            }
                            controller.present(alert, animated: true)
                        }
                    }
                }
            }
        ).createView()
        stackView.addArrangedSubviewWithMargin(refreshAction)
        stackView.addArrangedSubview(SeparatorView())
    }
}
