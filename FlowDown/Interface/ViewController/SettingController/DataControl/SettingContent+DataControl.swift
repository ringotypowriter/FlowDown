//
//  SettingContent+DataControl.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/24/25.
//

import AlertController
import ConfigurableKit
import Digger
import Storage
import UIKit

extension SettingController.SettingContent {
    class DataControlController: StackScrollController {
        init() {
            super.init(nibName: nil, bundle: nil)
            title = String(localized: "Data Control")
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .background
        }

        #if targetEnvironment(macCatalyst)
            var documentPickerExportTempItems: [URL] = []
        #endif

        override func setupContentViews() {
            super.setupContentViews()
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Database")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            var exportDatabaseReader: UIView?
            let exportDatabase = ConfigurableObject(
                icon: "square.and.arrow.up",
                title: String(localized: "Export Database"),
                explain: String(localized: "Export the database file."),
                ephemeralAnnotation: .action { controller in
                    guard let controller else { return }
                    Indicator.progress(
                        title: String(localized: "Exporting..."),
                        controller: controller
                    ) { progressCompletion in
                        let result = sdb.exportZipFile()
                        progressCompletion { [weak self] in
                            switch result {
                            case let .success(url):
                                #if targetEnvironment(macCatalyst)
                                    let documentPicker = UIDocumentPickerViewController(forExporting: [url])
                                    documentPicker.title = String(localized: "Export Model")
                                    documentPicker.delegate = self
                                    documentPicker.modalPresentationStyle = .formSheet
                                    controller.present(documentPicker, animated: true)
                                    self?.documentPickerExportTempItems.append(url)
                                #else
                                    let share = UIActivityViewController(
                                        activityItems: [url],
                                        applicationActivities: nil
                                    )
                                    share.popoverPresentationController?.sourceView = exportDatabaseReader ?? .init()
                                    share.popoverPresentationController?.sourceRect = exportDatabaseReader?.bounds ?? .zero
                                    share.completionWithItemsHandler = { _, _, _, _ in
                                        try? FileManager.default.removeItem(at: url)
                                    }
                                    controller.present(share, animated: true)
                                #endif
                            case let .failure(err):
                                let alert = AlertViewController(
                                    title: String(localized: "Error Occurred"),
                                    message: err.localizedDescription
                                ) { context in
                                    context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                                        context.dispose()
                                    }
                                }
                                controller.present(alert, animated: true)
                            }
                        }
                    }
                }
            ).createView()

            exportDatabaseReader = exportDatabase
            stackView.addArrangedSubviewWithMargin(exportDatabase)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "Exported database contains all conversations data and cloud model configurations, but does not include local model data, also known as weights, and application settings. To export local models, please go to the model management page. Application settings are not supported for export.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Conversation")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            let deleteAllConv = ConfigurableObject(
                icon: "trash",
                title: String(localized: "Delete All Conversations"),
                explain: String(localized: "Delete all conversations and related data."),
                ephemeralAnnotation: .action { controller in
                    let alert = AlertViewController(
                        title: String(localized: "Delete All Conversations"),
                        message: String(localized: "Are you sure you want to delete all conversations and related data?")
                    ) { context in
                        context.addAction(title: String(localized: "Cancel")) {
                            context.dispose()
                        }
                        context.addAction(title: String(localized: "Erase All"), attribute: .dangerous) {
                            context.dispose { ConversationManager.shared.eraseAll()
                                Indicator.present(
                                    title: String(localized: "Deleted"),
                                    referencingView: controller?.view
                                )
                            }
                        }
                    }
                    controller?.present(alert, animated: true)
                }
            ).createView()
            stackView.addArrangedSubviewWithMargin(deleteAllConv)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(ConversationManager.removeAllEditorObjects.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "These operations cannot be undone.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Cache")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            let downloadCache = ConfigurableObject(
                icon: "snowflake",
                title: String(localized: "Clean Cache"),
                explain: String(localized: "Clean image caches, remove partial downloads and more."),
                ephemeralAnnotation: .action { controller in
                    let alert = AlertViewController(
                        title: String(localized: "Clean Cache"),
                        message: String(localized: "Are you sure you want to clean the cache? This will also delete partial downloads.")
                    ) { context in
                        context.addAction(title: String(localized: "Cancel")) {
                            context.dispose()
                        }
                        context.addAction(title: String(localized: "Clear"), attribute: .dangerous) {
                            DiggerCache.cleanDownloadFiles()
                            DiggerCache.cleanDownloadTempFiles()
                            Indicator.present(
                                title: String(localized: "Cleaned"),
                                referencingView: controller?.view
                            )
                            context.dispose {}
                        }
                    }
                    controller?.present(alert, animated: true)
                }
            ).createView()

            stackView.addArrangedSubviewWithMargin(downloadCache)
            stackView.addArrangedSubview(SeparatorView())

            let removeTempDir = ConfigurableObject(
                icon: "folder.badge.minus",
                title: String(localized: "Reset Temporary Items"),
                explain: String(localized: "This will remove all contents inside temporary directory."),
                ephemeralAnnotation: .action { controller in
                    let alert = AlertViewController(
                        title: String(localized: "Reset Temporary Items"),
                        message: String(localized: "Are you sure you want to remove all content inside temporary directory?")
                    ) { context in
                        context.addAction(title: String(localized: "Cancel")) {
                            context.dispose()
                        }
                        context.addAction(title: String(localized: "Reset"), attribute: .dangerous) {
                            context.dispose {
                                let tempDir = FileManager.default.temporaryDirectory
                                try? FileManager.default.removeItem(at: tempDir)
                                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                                Indicator.present(
                                    title: String(localized: "Done"),
                                    referencingView: controller?.view
                                )
                            }
                        }
                    }
                    controller?.present(alert, animated: true)
                }
            ).createView()

            stackView.addArrangedSubviewWithMargin(removeTempDir)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "Usually, you don't need to clean caches and temporary files. But if you have any issues, try these.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Reset")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            let resetApp = ConfigurableObject(
                icon: "arrow.counterclockwise",
                title: String(localized: "Reset App"),
                explain: String(localized: "If you encounter any issues, you can try to reset the app. This will remove all content and reset the entire database."),
                ephemeralAnnotation: .action { controller in
                    let alert = AlertViewController(
                        title: String(localized: "Reset App"),
                        message: String(localized: "Are you sure you want to remove all content and reset the entire database? App will close after reset.")
                    ) { context in
                        context.addAction(title: String(localized: "Cancel")) {
                            context.dispose()
                        }
                        context.addAction(title: String(localized: "Reset"), attribute: .dangerous) {
                            context.dispose {
                                try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory)
                                try? FileManager.default.removeItem(at: ModelManager.shared.localModelDir)
                                sdb.reset()
                                // close the app
                                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    exit(0)
                                }
                            }
                        }
                    }
                    controller?.present(alert, animated: true)
                }
            ).createView()

            stackView.addArrangedSubviewWithMargin(resetApp)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "These operations cannot be undone.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())
        }
    }
}

#if targetEnvironment(macCatalyst)
    extension SettingController.SettingContent.DataControlController: UIDocumentPickerDelegate {
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            for cleanableURL in documentPickerExportTempItems {
                try? FileManager.default.removeItem(at: cleanableURL)
            }
            documentPickerExportTempItems.removeAll()
        }
    }
#endif
