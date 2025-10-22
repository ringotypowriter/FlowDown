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
        #if targetEnvironment(macCatalyst)
            var documentPickerExportTempItems: [URL] = []
        #endif
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

        var deletedSeverDataCancellable: AnyCancellable?
        var deletedSeverDataCompletionHandler: Indicator.CompletionHandler?
        var pullSeverDataCompletionHandler: Indicator.CompletionHandler?
        override func setupContentViews() {
            super.setupContentViews()
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "iCloud Sync")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            // Per-group sync toggles
            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Sync Scope")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            func addGroupToggle(icon: String, title: String, desc: String, group: SyncPreferences.Group) {
                let toggle = ConfigurableToggleActionView()
                toggle.configure(icon: UIImage(systemName: icon))
                toggle.configure(title: title)
                toggle.configure(description: desc)
                toggle.boolValue = SyncPreferences.isGroupEnabled(group)
                toggle.actionBlock = { value in
                    SyncPreferences.setGroup(group, enabled: value)
                    if value, SyncEngine.isSyncEnabled {
                        // Ensure we fetch fresh state when re-enabling a group
                        Task {
                            try? await syncEngine.reloadDataForcefully()
                        }
                    }
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

            let syncToggle = ConfigurableToggleActionView()
            syncToggle.configure(icon: UIImage(systemName: "icloud"))
            syncToggle.configure(title: String(localized: "Enable iCloud Sync"))
            syncToggle.configure(
                description: String(localized: "Enable iCloud sync to keep data consistent across your devices. Turning off does not delete existing data.")
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

            // Manual refresh mode toggle (disables automatic background sync)
            let manualToggle = ConfigurableToggleActionView()
            manualToggle.configure(icon: UIImage(systemName: "arrow.triangle.2.circlepath.icloud"))
            manualToggle.configure(title: String(localized: "Manual Refresh Mode"))
            manualToggle.configure(
                description: String(localized: "Pause automatic background syncing. Use Refresh to pull changes when needed.")
            )
            manualToggle.boolValue = SyncPreferences.isManualSyncEnabled
            manualToggle.actionBlock = { value in
                SyncPreferences.isManualSyncEnabled = value
                Task {
                    // Recreate underlying CKSyncEngine with new automaticallySync flag
                    try? await syncEngine.stopSyncIfNeeded()
                    if !value, SyncEngine.isSyncEnabled {
                        // Resume automatic syncing by fetching changes once
                        try? await syncEngine.fetchChanges()
                    }
                }
            }
            stackView.addArrangedSubviewWithMargin(manualToggle)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "When sync is off, no new changes are shared. Existing data remains intact. Re‑enable sync to fetch the latest state before resuming.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            // Dangerous: remove iCloud data option disabled per requirements
            // Keeping UI out to avoid accidental usage

            // Incremental pull disabled per requirements; replaced with explicit manual refresh
            /* let icloudIncrementPull = ConfigurableObject(
                 icon: "icloud.and.arrow.down",
                 title: String(localized: "Incremental Sync from iCloud"),
                 explain: String(localized: "Fetch only the new and updated data from iCloud."),
                 ephemeralAnnotation: .action { [weak self] controller in
                     guard let controller else { return }

                     guard SyncEngine.isSyncEnabled else {
                         self?.showAlert(controller: controller, title: String(localized: "Error Occurred"), message: String(localized: "iCloud synchronization is not enabled"))
                         return
                     }

                     Indicator.progress(title: String(localized: "Pull from iCloud ..."), controller: controller) { [weak self] completionHandler in
                         self?.pullSeverDataCompletionHandler = completionHandler
                     }

                     Task { @MainActor in
                         do {
                             try await syncEngine.fetchChanges()
                             self?.handlePullSeverData(controller: controller, error: nil)
                         } catch {
                             self?.handlePullSeverData(controller: controller, error: error)
                         }
                     }
                 }
             ).createView()
             stackView.addArrangedSubviewWithMargin(icloudIncrementPull)
             stackView.addArrangedSubview(SeparatorView()) */

            let icloudManualRefresh = ConfigurableObject(
                icon: "arrow.clockwise.icloud",
                title: String(localized: "Refresh from iCloud"),
                explain: String(localized: "Manually fetch the latest changes from iCloud."),
                ephemeralAnnotation: .action { [weak self] controller in
                    guard let controller else { return }

                    guard SyncEngine.isSyncEnabled else {
                        self?.showAlert(controller: controller, title: String(localized: "Error Occurred"), message: String(localized: "iCloud synchronization is not enabled"))
                        return
                    }

                    Indicator.progress(title: String(localized: "Refreshing..."), controller: controller) { [weak self] completionHandler in
                        self?.pullSeverDataCompletionHandler = completionHandler
                    }

                    Task { @MainActor in
                        do {
                            try await syncEngine.fetchChanges()
                            self?.handlePullSeverData(controller: controller, error: nil)
                        } catch {
                            self?.handlePullSeverData(controller: controller, error: error)
                        }
                    }
                }
            ).createView()
            stackView.addArrangedSubviewWithMargin(icloudManualRefresh)
            stackView.addArrangedSubview(SeparatorView())

            let icloudForcePull = ConfigurableObject(
                icon: "icloud.and.arrow.down",
                title: String(localized: "Full Refresh from iCloud"),
                explain: String(localized: "Rebuild sync state and fetch everything new from iCloud. Local data is preserved."),
                ephemeralAnnotation: .action { [weak self] controller in
                    guard let controller else { return }

                    guard SyncEngine.isSyncEnabled else {
                        self?.showAlert(controller: controller, title: String(localized: "Error Occurred"), message: String(localized: "iCloud synchronization is not enabled"))
                        return
                    }

                    Indicator.progress(title: String(localized: "Refreshing..."), controller: controller) { [weak self] completionHandler in
                        self?.pullSeverDataCompletionHandler = completionHandler
                    }

                    Task { @MainActor in
                        do {
                            try await syncEngine.reloadDataForcefully()
                            self?.handlePullSeverData(controller: controller, error: nil)
                        } catch {
                            self?.handlePullSeverData(controller: controller, error: error)
                        }
                    }
                }
            ).createView()
            stackView.addArrangedSubviewWithMargin(icloudForcePull)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Database")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            let importDatabase = ConfigurableObject(
                icon: "square.and.arrow.down",
                title: String(localized: "Import Database"),
                explain: String(localized: "Replace all local data with a previous database export."),
                ephemeralAnnotation: .action { [weak self] controller in
                    guard let controller else { return }
                    self?.presentImportConfirmation(from: controller)
                }
            ).createView()
            stackView.addArrangedSubviewWithMargin(importDatabase)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Database Export")
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
                                Task {
                                    /// 停掉同步,避免同步继续执行会占用db连接，导致后面无法关闭db
                                    try? await syncEngine.stopSyncIfNeeded()
                                    SyncEngine.resetCachedState()

                                    await MainActor.run {
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
                title: String(localized: "Importing..."),
                controller: controller
            ) { progressCompletion in
                Task.detached(priority: .userInitiated) {
                    let securityScoped = url.startAccessingSecurityScopedResource()
                    defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

                    // 停止同步
                    try? await syncEngine.stopSyncIfNeeded()

                    sdb.importDatabase(from: url) { result in
                        progressCompletion { [weak self] in
                            switch result {
                            case .success:
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
                            case let .failure(error):
                                let alert = AlertViewController(
                                    title: String(localized: "Error Occurred"),
                                    message: error.localizedDescription
                                ) { context in
                                    context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                                        context.dispose()
                                    }
                                }
                                controller.present(alert, animated: true)
                                self?.documentPickerImportHandler = nil
                            }
                        }
                    }
                }
            }
        }

        private func showAlert(controller: UIViewController, title: String, message: String) {
            let alert = AlertViewController(
                title: title,
                message: message
            ) { context in
                context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                    context.dispose()
                }
            }
            controller.present(alert, animated: true)
        }

        @MainActor
        private func handleServerDataDeleted(controller: UIViewController, success: Bool, error: Error?) {
            deletedSeverDataCancellable = nil
            deletedSeverDataCompletionHandler? {
                guard !success else {
                    return
                }

                let message = if let error {
                    error.localizedDescription
                } else {
                    String(localized: "Failed to delete iCloud data. Please try again later")
                }

                let alert = AlertViewController(
                    title: String(localized: "Error Occurred"),
                    message: message
                ) { context in
                    context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                        context.dispose()
                    }
                }
                controller.present(alert, animated: true)
            }

            deletedSeverDataCompletionHandler = nil
        }

        @MainActor
        private func handlePullSeverData(controller: UIViewController, error: Error?) {
            pullSeverDataCompletionHandler? {
                guard let error else { return }
                let alert = AlertViewController(
                    title: String(localized: "Error Occurred"),
                    message: error.localizedDescription
                ) { context in
                    context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                        context.dispose()
                    }
                }
                controller.present(alert, animated: true)
            }

            pullSeverDataCompletionHandler = nil
        }
    }
}

extension SettingController.SettingContent.DataControlController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        documentPickerImportHandler?(urls)
        documentPickerImportHandler = nil
        cleanupExportTempItems()
    }

    func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        documentPickerImportHandler = nil
        cleanupExportTempItems()
    }

    private func cleanupExportTempItems() {
        #if targetEnvironment(macCatalyst)
            for cleanableURL in documentPickerExportTempItems {
                try? FileManager.default.removeItem(at: cleanableURL)
            }
            documentPickerExportTempItems.removeAll()
        #endif
    }
}
