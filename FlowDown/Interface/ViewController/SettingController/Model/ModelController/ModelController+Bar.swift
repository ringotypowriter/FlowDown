//
//  ModelController+Bar.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/27/25.
//

import AlertController
import ConfigurableKit
import MLX
import Storage
import UIKit
import UniformTypeIdentifiers

extension SettingController.SettingContent.ModelController {
    private func createCloudModelMenuItems() -> [UIMenuElement] {
        [
            UIMenu(
                title: String(localized: "pollinations.ai (free)"),
                image: .init(systemName: "network"),
                children: CloudModel.BuiltinModel.allCases.map(\.model).map { model in
                    UIAction(
                        title: model.model_identifier,
                        image: .init(systemName: "network")
                    ) { [weak self] _ in
                        _ = ModelManager.shared.newCloudModel(profile: model)
                        Indicator.present(
                            title: "Model Added",
                            preset: .done,
                            referencingView: self?.view
                        )
                    }
                }
            ),
            UIAction(
                title: String(localized: "Empty Model"),
                image: .init(systemName: "square.dashed")
            ) { [weak self] _ in
                guard let self else { return }
                let profile = CloudModel(deviceId: Storage.deviceId)
                _ = ModelManager.shared.newCloudModel(profile: profile)
                let controller = CloudModelEditorController(identifier: profile.id)
                navigationController?.pushViewController(controller, animated: true)
            },
        ]
    }

    private func createLocalModelMenuItems() -> [UIMenuElement] {
        [
            UIAction(
                title: String(localized: "Download @ Hugging Face"),
                image: .init(systemName: "icloud.and.arrow.down")
            ) { [weak self] _ in
                guard MLX.GPU.isSupported else {
                    let alert = AlertViewController(
                        title: "Unsupported",
                        message: "Your device does not support MLX."
                    ) { context in
                        context.addAction(title: "OK", attribute: .accent) {
                            context.dispose()
                        }
                    }
                    self?.present(alert, animated: true)
                    return
                }
                guard let nav = self?.navigationController else { return }
                nav.pushViewController(HubModelDownloadController(), animated: true)
            },
            UIAction(
                title: String(localized: "Connect @ OLLAMA"),
                image: .init(systemName: "cable.connector.horizontal")
            ) { [weak self] _ in
                let profile = CloudModel(deviceId: Storage.deviceId)
                _ = ModelManager.shared.newCloudModel(profile: profile)
                let controller = CloudModelEditorController(identifier: profile.id)
                self?.navigationController?.pushViewController(controller, animated: true)
            },
            UIAction(
                title: String(localized: "Connect @ LM Studio"),
                image: .init(systemName: "cable.connector.horizontal")
            ) { [weak self] _ in
                let profile = CloudModel(deviceId: Storage.deviceId)
                _ = ModelManager.shared.newCloudModel(profile: profile)
                let controller = CloudModelEditorController(identifier: profile.id)
                self?.navigationController?.pushViewController(controller, animated: true)
            },
        ]
    }

    func createAddModelMenuItems() -> [UIMenuElement] {
        [
            UIMenu(
                title: String(localized: "Cloud Model"),
                options: [.displayInline],
                children: createCloudModelMenuItems()
            ),
            UIMenu(
                title: String(localized: "Local Model"),
                options: [.displayInline],
                children: createLocalModelMenuItems()
            ),
            UIMenu(
                title: String(localized: "Import Model"),
                options: [.displayInline],
                children: [
                    UIAction(
                        title: String(localized: "Import from File"),
                        image: .init(systemName: "arrow.down.doc")
                    ) { [weak self] _ in
                        guard let self else { return }
                        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
                            .zip, .propertyList, UTType(filenameExtension: "fdmodel") ?? .data,
                        ], asCopy: true)
                        picker.title = String(localized: "Import Model")
                        picker.delegate = self
                        picker.allowsMultipleSelection = true
                        picker.modalPresentationStyle = .formSheet
                        present(picker, animated: true)
                    },
                ]
            ),
        ]
    }

    func createFilterMenuItems() -> [UIMenuElement] {
        [
            UIAction(
                title: String(localized: "Show Local Models"),
                state: showLocalModels ? .on : .off
            ) { [weak self] _ in
                self?.showLocalModels.toggle()
            },
            UIAction(
                title: String(localized: "Show Cloud Models"),
                state: showCloudModels ? .on : .off
            ) { [weak self] _ in
                self?.showCloudModels.toggle()
            },
        ]
    }
}
