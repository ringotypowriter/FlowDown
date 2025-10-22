//
//  SyncScopeController.swift
//  FlowDown
//
//  Created by AI on 2025/10/22.
//

import Storage
import UIKit

class SyncScopeController: StackScrollController {
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
    }
}
