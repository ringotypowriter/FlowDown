//
//  ConversationManager+Menu.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/5/25.
//

import AlertController
import Foundation
import Storage
import UIKit

private let dateFormatter = DateFormatter().with {
    $0.locale = .current
    $0.dateStyle = .short
    $0.timeStyle = .short
}

extension ConversationManager {
    func menu(
        forConversation identifier: Conversation.ID?,
        view: UIView,
        suggestNewSelection: @escaping (Conversation.ID) -> Void
    ) -> UIMenu? {
        guard let controller = view.parentViewController else { return nil }
        guard let conv = conversation(identifier: identifier) else { return nil }

        let convHasEmptyContent = ConversationSessionManager.shared.session(for: conv.id)
            .messages
            .filter { [.user, .assistant].contains($0.role) }
            .isEmpty
        let session = ConversationSessionManager.shared.session(for: conv.id)

        let mainMenu = UIMenu(
            title: [
                dateFormatter.string(from: conv.creation),
            ].joined(separator: " "),
            options: [.displayInline],
            children: [
                UIAction(
                    title: String(localized: "Rename"),
                    image: UIImage(systemName: "pencil.tip.crop.circle.badge.arrow.forward")
                ) { _ in
                    let alert = AlertInputViewController(
                        title: "Rename",
                        message: "Set a new title for the conversation. Leave empty to keep unchanged. This will disable auto-renaming.",
                        placeholder: "Title",
                        text: conv.title
                    ) { text in
                        guard !text.isEmpty else { return }
                        ConversationManager.shared.editConversation(identifier: conv.id) {
                            $0.update(\.title, to: text)
                            $0.update(\.shouldAutoRename, to: false)
                        }
                    }
                    controller.present(alert, animated: true)
                },
                UIAction(
                    title: String(localized: "Pick New Icon"),
                    image: UIImage(systemName: "person.crop.circle.badge.plus")
                ) { _ in
                    let picker = EmojiPickerViewController(sourceView: view) { emoji in
                        ConversationManager.shared.editConversation(identifier: conv.id) {
                            let icon = emoji.emoji.textToImage(size: 128)?.pngData() ?? .init()
                            $0.update(\.icon, to: icon)
                            $0.update(\.shouldAutoRename, to: false)
                        }
                    }
                    controller.present(picker, animated: true)
                },
            ]
        )

        let savePictureMenu = UIMenu(
            options: [.displayInline],
            children: [
                UIAction(
                    title: String(localized: "Save Image"),
                    image: UIImage(systemName: "text.below.photo")
                ) { _ in
                    let captureView = ConversationCaptureView(session: session)
                    guard let controller = view.parentViewController else { return }
                    Indicator.progress(
                        title: "Rendering Content",
                        controller: controller
                    ) { completion in
                        let image = await withCheckedContinuation { continuation in
                            DispatchQueue.main.async {
                                captureView.capture(controller: controller) { image in
                                    continuation.resume(returning: image)
                                }
                            }
                        }

                        guard let image, let png = image.pngData() else { throw NSError() }
                        let exporter = DisposableExporter(
                            data: png,
                            name: "Exported-\(Int(Date().timeIntervalSince1970))".sanitizedFileName,
                            pathExtension: "png",
                            title: "Export Image"
                        )
                        await completion { exporter.run(anchor: view) }
                    }
                },
                UIMenu(
                    title: String(localized: "Export Document"),
                    image: UIImage(systemName: "doc"),
                    children: [
                        UIAction(
                            title: String(localized: "Export Plain Text"),
                            image: UIImage(systemName: "doc.plaintext")
                        ) { _ in
                            ConversationManager.shared.exportConversation(identifier: conv.id, exportFormat: .plainText) { result in
                                switch result {
                                case let .success(content):
                                    DisposableExporter(
                                        data: Data(content.utf8),
                                        name: "Exported-\(Int(Date().timeIntervalSince1970))",
                                        pathExtension: "txt",
                                        title: "Export Plain Text"
                                    ).run(anchor: view, mode: .file)
                                case .failure:
                                    Indicator.present(
                                        title: "Export Failed",
                                        preset: .error,
                                        referencingView: view
                                    )
                                }
                            }
                        },
                        UIAction(
                            title: String(localized: "Export Markdown"),
                            image: UIImage(systemName: "doc.richtext")
                        ) { _ in
                            ConversationManager.shared.exportConversation(identifier: conv.id, exportFormat: .markdown) { result in
                                switch result {
                                case let .success(content):
                                    DisposableExporter(
                                        data: Data(content.utf8),
                                        name: "Exported-\(Int(Date().timeIntervalSince1970))",
                                        pathExtension: "md",
                                        title: "Export Markdown"
                                    ).run(anchor: view, mode: .file)
                                case .failure:
                                    Indicator.present(
                                        title: "Export Failed",
                                        preset: .error,
                                        referencingView: view
                                    )
                                }
                            }
                        },
                    ]
                ),
            ]
        )

        let automationMenu = UIMenu(
            title: String(localized: "Automation"),
            options: [.displayInline],
            children: [
                UIAction(
                    title: String(localized: "Generate New Icon"),
                    image: UIImage(systemName: "arrow.clockwise")
                ) { _ in
                    Indicator.progress(
                        title: "Generating New Icon",
                        controller: controller
                    ) { completion in
                        let sessionManager = ConversationSessionManager.shared
                        let session = sessionManager.session(for: conv.id)
                        let emoji = await session.generateConversationIcon()
                        await completion {
                            if let emoji {
                                ConversationManager.shared.editConversation(identifier: conv.id) { conversation in
                                    let icon = emoji.textToImage(size: 128)?.pngData() ?? .init()
                                    conversation.update(\.icon, to: icon)
                                }
                            } else {
                                Indicator.present(
                                    title: "Unable to generate icon",
                                    preset: .error,
                                    referencingView: view
                                )
                            }
                        }
                    }
                },
                UIAction(
                    title: String(localized: "Generate New Title"),
                    image: UIImage(systemName: "arrow.clockwise")
                ) { _ in
                    Indicator.progress(
                        title: "Generating New Title",
                        controller: controller
                    ) { completion in
                        let sessionManager = ConversationSessionManager.shared
                        let session = sessionManager.session(for: conv.id)
                        let title = await session.generateConversationTitle()
                        await completion {
                            if let title {
                                ConversationManager.shared.editConversation(identifier: conv.id) { conversation in
                                    conversation.update(\.title, to: title)
                                }
                            } else {
                                Indicator.present(
                                    title: "Unable to generate title",
                                    preset: .error,
                                    referencingView: view
                                )
                            }
                        }
                    }
                },
            ].compactMap(\.self)
        )

        let managementGroup: [UIMenuElement] = [
            { () -> UIMenuElement? in
                if conv.isFavorite {
                    return UIAction(
                        title: String(localized: "Unfavorite"),
                        image: UIImage(systemName: "star.slash")
                    ) { _ in
                        ConversationManager.shared.editConversation(identifier: conv.id) {
                            $0.update(\.isFavorite, to: false)
                        }
                    }
                } else {
                    return nil
                }
            }(),
            { () -> UIMenuElement? in
                if !conv.isFavorite {
                    return UIAction(
                        title: String(localized: "Favorite"),
                        image: UIImage(systemName: "star")
                    ) { _ in
                        ConversationManager.shared.editConversation(identifier: conv.id) {
                            $0.update(\.isFavorite, to: true)
                        }
                    }
                } else {
                    return nil
                }
            }(),
            { () -> UIMenu? in
                if !convHasEmptyContent {
                    return savePictureMenu
                } else {
                    return nil
                }
            }(),
            { () -> UIMenu? in
                if convHasEmptyContent {
                    return nil
                } else {
                    return UIMenu(options: [.displayInline], children: [
                        UIAction(
                            title: String(localized: "Compress to New Chat"),
                            image: UIImage(systemName: "arrow.down.doc")
                        ) { _ in
                            let model = session.models.chat
                            let name = ModelManager.shared.modelName(identifier: model)
                            guard let model, !name.isEmpty else {
                                let alert = AlertViewController(
                                    title: "Model Not Available",
                                    message: "Please select a model to generate chat template."
                                ) { context in
                                    context.addAction(title: "OK", attribute: .accent) {
                                        context.dispose()
                                    }
                                }
                                controller.present(alert, animated: true)
                                return
                            }
                            let alert = AlertViewController(
                                title: "Compress to New Chat",
                                message: "This will use \(name) compress the current conversation into a short summary and create a new chat with it. The original conversation will remain unchanged."
                            ) { context in
                                context.addAction(title: "Cancel") {
                                    context.dispose()
                                }
                                context.addAction(title: "Compress", attribute: .accent) {
                                    context.dispose {
                                        Indicator.progress(
                                            title: "Compressing",
                                            controller: controller
                                        ) { completion in
                                            let result = await withCheckedContinuation { continuation in
                                                ConversationManager.shared.compressConversation(
                                                    identifier: conv.id,
                                                    model: model
                                                ) { convId in
                                                    suggestNewSelection(convId)
                                                } completion: { result in
                                                    continuation.resume(returning: result)
                                                }
                                            }

                                            switch result {
                                            case .success:
                                                await completion {
                                                    Indicator.present(
                                                        title: "Conversation Compressed",
                                                        preset: .done,
                                                        referencingView: view
                                                    )
                                                }
                                            case let .failure(failure):
                                                throw failure
                                            }
                                        }
                                    }
                                }
                            }
                            controller.present(alert, animated: true)
                        },
                        UIAction(
                            title: String(localized: "Generate Chat Template"),
                            image: UIImage(systemName: "wind")
                        ) { _ in
                            let model = session.models.chat
                            let name = ModelManager.shared.modelName(identifier: model)
                            guard let model, !name.isEmpty else {
                                let alert = AlertViewController(
                                    title: "Model Not Available",
                                    message: "Please select a model to generate chat template."
                                ) { context in
                                    context.addAction(title: "OK", attribute: .accent) {
                                        context.dispose()
                                    }
                                }
                                controller.present(alert, animated: true)
                                return
                            }
                            let alert = AlertViewController(
                                title: "Generate Chat Template",
                                message: "This will extract your requests from the current conversation using \(name) and save it as a template for later use. This may take some time."
                            ) { context in
                                context.addAction(title: "Cancel") {
                                    context.dispose()
                                }
                                context.addAction(title: "Generate", attribute: .accent) {
                                    context.dispose {
                                        Indicator.progress(
                                            title: "Generating Template",
                                            controller: controller
                                        ) { completion in
                                            let result = await withCheckedContinuation { continuation in
                                                ChatTemplateManager.shared.createTemplateFromConversation(conv, model: model) { result in
                                                    continuation.resume(returning: result)
                                                }
                                            }

                                            let template = try result.get()
                                            await completion {
                                                ChatTemplateManager.shared.addTemplate(template)
                                                let alert = AlertViewController(
                                                    title: "Template Generated",
                                                    message: "Template \(template.name) has been successfully generated and saved."
                                                ) { context in
                                                    context.addAction(title: "OK") {
                                                        context.dispose()
                                                    }
                                                    context.addAction(title: "Edit", attribute: .accent) {
                                                        context.dispose {
                                                            let setting = SettingController()
                                                            SettingController.setNextEntryPage(.chatTemplateEditor(templateIdentifier: template.id))
                                                            controller.present(setting, animated: true)
                                                        }
                                                    }
                                                }
                                                controller.present(alert, animated: true)
                                            }
                                        }
                                    }
                                }
                            }
                            controller.present(alert, animated: true)
                        },
                        UIAction(
                            title: String(localized: "Duplicate"),
                            image: UIImage(systemName: "doc.on.doc")
                        ) { _ in
                            if let id = ConversationManager.shared.duplicateConversation(identifier: conv.id) {
                                suggestNewSelection(id)
                            }
                        },
                    ])
                }
            }(),
            { () -> UIMenuElement? in
                if convHasEmptyContent {
                    return UIAction(
                        title: String(localized: "Delete"),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive
                    ) { _ in
                        ConversationManager.shared.deleteConversation(identifier: conv.id)
                        if let first = ConversationManager.shared.conversations.value.values.first?.id {
                            suggestNewSelection(first)
                        }
                    }
                } else {
                    return UIMenu(
                        title: String(localized: "Delete"),
                        options: [.displayInline],
                        children: [
                            { () -> UIAction? in
                                if !conv.icon.isEmpty {
                                    UIAction(
                                        title: String(localized: "Delete Icon"),
                                        image: UIImage(systemName: "trash"),
                                        attributes: .destructive
                                    ) { _ in
                                        ConversationManager.shared.editConversation(identifier: conv.id) {
                                            $0.update(\.icon, to: .init())
                                        }
                                    }
                                } else { nil }
                            }(),
                            UIAction(
                                title: String(localized: "Delete Conversation"),
                                image: UIImage(systemName: "trash"),
                                attributes: .destructive
                            ) { _ in
                                ConversationManager.shared.deleteConversation(identifier: conv.id)
                                if let first = ConversationManager.shared.conversations.value.values.first?.id {
                                    suggestNewSelection(first)
                                }
                            },
                        ].compactMap(\.self)
                    )
                }
            }(),
        ].compactMap(\.self)

        let management = UIMenu(
            title: String(localized: "Other"),
            image: UIImage(systemName: "ellipsis.circle"),
            options: managementGroup.count <= 1 ? .displayInline : [],
            children: managementGroup
        )

        var finalChildren: [UIMenuElement] = []

        if session.currentTask != nil {
            finalChildren.append(
                UIMenu(options: [.displayInline], children: [
                    UIAction(
                        title: String(localized: "Terminate"),
                        image: UIImage(systemName: "stop.circle"),
                        attributes: [.destructive]
                    ) { _ in
                        session.cancelCurrentTask {}
                    },
                ])
            )
        }

        finalChildren.append(mainMenu)
        if !convHasEmptyContent { finalChildren.append(automationMenu) }
        if !management.children.isEmpty { finalChildren.append(management) }

        return UIMenu(options: [.displayInline], children: finalChildren)
    }
}
