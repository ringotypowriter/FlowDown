//
//  SettingContent+DataControl.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/24/25.
//

import AlertController
import Combine
import ConfigurableKit
import Digger
import Storage
import UIKit
import UniformTypeIdentifiers

extension SettingController.SettingContent {
    class DataControlController: StackScrollController {
        private var documentPickerImportHandler: (([URL]) -> Void)?

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

        override func setupContentViews() {
            super.setupContentViews()
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "iCloud Sync"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            let syncToggle = ConfigurableToggleActionView()
            syncToggle.configure(icon: UIImage(systemName: "icloud"))
            syncToggle.configure(title: "Enable iCloud Sync")
            syncToggle.configure(
                description: "Enable iCloud sync to keep data consistent across your devices. Turning off does not delete existing data."
            )
            syncToggle.boolValue = SyncEngine.isSyncEnabled
            syncToggle.actionBlock = { [weak self] value in
                guard let self else { return }
                if value {
                    SyncEngine.setSyncEnabled(true)
                    // After re‑enabling, force reload full state before continuing
                    Task {
                        try? await syncEngine.stopSyncIfNeeded()
                        try? await syncEngine.reloadDataForcefully()
                    }
                } else {
                    presentSyncDisableAlert { confirmed in
                        if confirmed {
                            SyncEngine.setSyncEnabled(false)
                            Task { await self.pauseSync() }
                            syncToggle.boolValue = false
                        } else {
                            syncToggle.boolValue = true
                        }
                    }
                }
            }
            stackView.addArrangedSubviewWithMargin(syncToggle)
            stackView.addArrangedSubview(SeparatorView())

            // Sync scope submenu
            let syncScopeMenu = ConfigurableObject(
                icon: "slider.horizontal.3",
                title: "Sync Scope",
                explain: "Configure which data groups sync with iCloud.",
                ephemeralAnnotation: .action { [weak self] _ in
                    guard let self else { return }
                    let controller = SyncScopePage()
                    navigationController?.pushViewController(controller, animated: true)
                }
            ).createView()
            stackView.addArrangedSubviewWithMargin(syncScopeMenu)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "When sync is off, no new changes are shared. Existing data remains intact. Re‑enable sync to fetch the latest state before resuming."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Database"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            let importDatabase = ConfigurableObject(
                icon: "square.and.arrow.down",
                title: "Import Database",
                explain: "Replace all local data with a previous database export.",
                ephemeralAnnotation: .action { [weak self] controller in
                    self?.presentImportConfirmation(from: controller)
                }
            ).createView()
            stackView.addArrangedSubviewWithMargin(importDatabase)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Database Export"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            var exportDatabaseReader: UIView?
            let exportDatabase = ConfigurableObject(
                icon: "square.and.arrow.up",
                title: "Export Database",
                explain: "Export the database file.",
                ephemeralAnnotation: .action { controller in
                    Indicator.progress(
                        title: "Exporting...",
                        controller: controller
                    ) { progressCompletion in
                        let result = sdb.exportZipFile()
                        let url = try result.get()
                        await progressCompletion {
                            DisposableExporter(deletableItem: url, title: "Export Database")
                                .run(anchor: exportDatabaseReader ?? controller.view)
                        }
                    }
                }
            ).createView()

            exportDatabaseReader = exportDatabase
            stackView.addArrangedSubviewWithMargin(exportDatabase)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "Exported database contains all conversations data and cloud model configurations, but does not include local model data, also known as weights, and application settings. To export local models, please go to the model management page. Application settings are not supported for export."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Conversation"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            let deleteAllConv = ConfigurableObject(
                icon: "trash",
                title: "Delete All Conversations",
                explain: "Delete all conversations and related data.",
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
                                    title: "Deleted",
                                    referencingView: controller.view
                                )
                            }
                        }
                    }
                    controller.present(alert, animated: true)
                }
            ).createView()
            stackView.addArrangedSubviewWithMargin(deleteAllConv)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(ConversationManager.removeAllEditorObjects.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "These operations cannot be undone."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Cache"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            let downloadCache = ConfigurableObject(
                icon: "snowflake",
                title: "Clean Cache",
                explain: "Clean image caches, remove partial downloads and more.",
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
                                title: "Cleaned",
                                referencingView: controller.view
                            )
                            context.dispose {}
                        }
                    }
                    controller.present(alert, animated: true)
                }
            ).createView()

            stackView.addArrangedSubviewWithMargin(downloadCache)
            stackView.addArrangedSubview(SeparatorView())

            let removeTempDir = ConfigurableObject(
                icon: "folder.badge.minus",
                title: "Reset Temporary Items",
                explain: "This will remove all contents inside temporary directory.",
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
                                    title: "Done",
                                    referencingView: controller.view
                                )
                            }
                        }
                    }
                    controller.present(alert, animated: true)
                }
            ).createView()

            stackView.addArrangedSubviewWithMargin(removeTempDir)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "Usually, you don't need to clean caches and temporary files. But if you have any issues, try these."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Reset"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            // Bring back Delete iCloud Data (dangerous)
            let deleteICloud = ConfigurableObject(
                icon: "icloud.slash",
                title: "Delete iCloud Data ...",
                explain: "Delete data stored in iCloud.",
                ephemeralAnnotation: .action { controller in
                    guard SyncEngine.isSyncEnabled else {
                        let alert = AlertViewController(
                            title: String(localized: "Error Occurred"),
                            message: String(localized: "iCloud synchronization is not enabled")
                        ) { context in
                            context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                                context.dispose()
                            }
                        }
                        controller.present(alert, animated: true)
                        return
                    }

                    let alert = AlertViewController(
                        title: String(localized: "Delete iCloud Data"),
                        message: String(localized: "This will remove your synced data from iCloud for this app. Local data on this device will remain.")
                    ) { context in
                        context.addAction(title: String(localized: "Cancel")) {
                            context.dispose()
                        }
                        context.addAction(title: String(localized: "Delete"), attribute: .dangerous) {
                            context.dispose {
                                Indicator.progress(title: "Deleting...", controller: controller) { completion in
                                    try await syncEngine.deleteServerData()
                                    await completion {}
                                }
                            }
                        }
                    }
                    controller.present(alert, animated: true)
                }
            ).createView()
            stackView.addArrangedSubviewWithMargin(deleteICloud)
            stackView.addArrangedSubview(SeparatorView())

            let resetApp = ConfigurableObject(
                icon: "arrow.counterclockwise",
                title: "Reset App",
                explain: "If you encounter any issues, you can try to reset the app. This will remove all content and reset the entire database.",
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
                                /// 停掉同步,避免同步继续执行会占用db连接，导致后面无法关闭db
                                try? await syncEngine.stopSyncIfNeeded()
                                SyncEngine.resetCachedState()
                                try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory)
                                try? FileManager.default.removeItem(at: ModelManager.shared.localModelDir)

                                /// 在主线程中释放db链接
                                sdb.reset()
                                // close the app
                                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    exit(0)
                                }
                            }
                        }
                    }
                    controller.present(alert, animated: true)
                }
            ).createView()

            stackView.addArrangedSubviewWithMargin(resetApp)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "These operations cannot be undone."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())
        }

        private func presentSyncDisableAlert(confirmHandler: @escaping (Bool) -> Void) {
            let alert = AlertViewController(
                title: String(localized: "Disable iCloud Sync"),
                message: String(localized: "Turning off sync only pauses future updates. Existing data stays in place. Re‑enable later to fetch and resume syncing.")
            ) { context in
                context.addAction(title: String(localized: "Keep Enabled")) {
                    context.dispose { confirmHandler(false) }
                }
                context.addAction(title: String(localized: "Disable"), attribute: .dangerous) {
                    context.dispose { confirmHandler(true) }
                }
            }
            present(alert, animated: true)
        }

        private func resumeSyncIfNeeded() {
            Task {
                try? await syncEngine.resumeSyncIfNeeded()
            }
        }

        private func pauseSync() async {
            try? await syncEngine.stopSyncIfNeeded()
        }

        private func presentImportConfirmation(from controller: UIViewController) {
            let alert = AlertViewController(
                title: String(localized: "Import Database"),
                message: String(localized: "Importing a database backup will replace all current conversations, memories, and cloud model settings. This action cannot be undone.")
            ) { [weak self] context in
                context.addAction(title: String(localized: "Cancel")) {
                    context.dispose()
                }
                context.addAction(title: String(localized: "Import"), attribute: .dangerous) {
                    context.dispose { self?.presentImportPicker(from: controller) }
                }
            }
            controller.present(alert, animated: true)
        }

        private func presentImportPicker(from controller: UIViewController) {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.zip], asCopy: true)
            picker.allowsMultipleSelection = false
            picker.delegate = self
            documentPickerImportHandler = { [weak self, weak controller] urls in
                guard let url = urls.first, let controller else { return }
                self?.performDatabaseImport(from: url, controller: controller)
            }
            controller.present(picker, animated: true)
        }

        private func performDatabaseImport(from url: URL, controller: UIViewController) {
            Indicator.progress(
                title: "Importing...",
                controller: controller
            ) { progressCompletion in
                let securityScoped = url.startAccessingSecurityScopedResource()
                defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

                // 停止同步
                try? await syncEngine.stopSyncIfNeeded()

                let result = await withCheckedContinuation { continuation in
                    sdb.importDatabase(from: url) { result in
                        continuation.resume(returning: result)
                    }
                }

                try result.get()
                await progressCompletion { [weak self] in
                    let alert = AlertViewController(
                        title: String(localized: "Import Complete"),
                        message: String(localized: "FlowDown will restart to apply the imported database.")
                    ) { context in
                        context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                            SyncEngine.resetCachedState()
                            context.dispose {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    exit(0)
                                }
                            }
                        }
                    }
                    controller.present(alert, animated: true)
                    self?.documentPickerImportHandler = nil
                }
            }
        }
    }
}

extension SettingController.SettingContent.DataControlController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        documentPickerImportHandler?(urls)
        documentPickerImportHandler = nil
    }

    func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        documentPickerImportHandler = nil
    }
}
