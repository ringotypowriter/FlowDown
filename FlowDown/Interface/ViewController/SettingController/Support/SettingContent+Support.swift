//
//  SettingContent+Support.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/24/25.
//

import ConfigurableKit
import Storage
import UIKit

extension SettingController.SettingContent {
    class SupportController: StackScrollController {
        init() {
            super.init(nibName: nil, bundle: nil)
            title = String(localized: "Contact Us")
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .background
        }

        override func setupContentViews() {
            super.setupContentViews()

            stackView.addArrangedSubview(SeparatorView())

            for section in settingSections {
                if !section.title.isEmpty {
                    stackView.addArrangedSubviewWithMargin(
                        ConfigurableSectionHeaderView().with(header: section.title)
                    ) { $0.bottom /= 2 }
                    stackView.addArrangedSubview(SeparatorView())
                }
                for object in section.objects {
                    stackView.addArrangedSubviewWithMargin(object.createView())
                    stackView.addArrangedSubview(SeparatorView())
                }
                if !section.footer.isEmpty {
                    stackView.addArrangedSubviewWithMargin(
                        ConfigurableSectionFooterView().with(footer: section.footer)
                    ) { $0.top /= 2 }
                    stackView.addArrangedSubview(SeparatorView())
                }
            }
        }
    }
}

extension SettingController.SettingContent.SupportController {
    typealias SettingSection = (
        title: String,
        objects: [ConfigurableObject],
        footer: String
    )
    var contactObject: SettingSection {
        (
            title: String(localized: "Contact Us"),
            objects: [
                ConfigurableObject(
                    icon: "envelope",
                    title: String(localized: "Email"),
                    explain: String(localized: "Send us an email."),
                    ephemeralAnnotation: .openLink(
                        title: String(localized: "Open..."),
                        url: URL(string: "mailto:flowdownapp@qaq.wiki")!
                    )
                ),
                ConfigurableObject(
                    icon: "safari",
                    title: String(localized: "GitHub"),
                    explain: String(localized: "Leave a message on GitHub issue."),
                    ephemeralAnnotation: .openLink(
                        title: String(localized: "Open..."),
                        url: URL(string: "https://github.com/Lakr233/FlowDown-Beta/issues")!
                    )
                ),
                ConfigurableObject(
                    icon: "bubble.left",
                    title: String(localized: "Discord"),
                    explain: String(localized: "Join our Discord server."),
                    ephemeralAnnotation: .openLink(
                        title: String(localized: "Open..."),
                        url: URL(string: "https://discord.gg/UHKMRyJcgc")!
                    )
                ),
            ],
            footer: String(localized: "Please feel free to contact us if you have any questions or suggestions.")
        )
    }

    var openSourceObject: SettingSection { (
        title: String(localized: "Software Resources"),
        objects: [
            ConfigurableObject(
                icon: "flag.filled.and.flag.crossed",
                title: String(localized: "Open Source Licenses"),
                explain: String(localized: "These are the open-source licenses for the frameworks used in this app."),
                ephemeralAnnotation: .action { controller in
                    controller?.navigationController?.pushViewController(OpenSourceLicenseController(), animated: true)
                }
            ),
        ],
        footer: String(localized: "This app wont be possible without the help of open source community.")
    )
    }

    var agreementsObject: SettingSection { (
        title: String(localized: "Agreements"),
        objects: [
            ConfigurableObject(
                icon: "lock",
                title: String(localized: "Privacy Policy"),
                explain: String(localized: "Tells you how we handle your data."),
                ephemeralAnnotation: .action { controller in
                    controller?.navigationController?.pushViewController(PrivacyPolicyController(), animated: true)
                }
            ),
        ],
        footer: String(localized: "Please read the agreements carefully.")
    ) }

    var settingSections: [SettingSection] { [
        contactObject,
        agreementsObject,
        openSourceObject,
    ] }
}
