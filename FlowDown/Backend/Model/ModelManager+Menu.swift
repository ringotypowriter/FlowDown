//
//  ModelManager+Menu.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/3/25.
//

import AlertController
import ConfigurableKit
import Foundation
import Storage
import UIKit

extension ModelManager {
    private func openModelManagementPage(controller: UIViewController?) {
        guard let controller else { return }
        if let nav = controller.navigationController {
            let controller = SettingController.SettingContent.ModelController()
            nav.pushViewController(controller, animated: true)
        } else {
            let setting = SettingController()
            SettingController.setNextEntryPage(.modelManagement)
            controller.present(setting, animated: true)
        }
    }

    func buildModelSelectionMenu(
        currentSelection: ModelIdentifier? = nil,
        requiresCapabilities: Set<ModelCapabilities> = [],
        allowSelectionWithNone: Bool = false,
        onCompletion: @escaping (ModelIdentifier) -> Void
    ) -> [UIMenuElement] {
        let localModels = ModelManager.shared.localModels.value.filter {
            !$0.model_identifier.isEmpty
        }.filter { requiresCapabilities.isSubset(of: $0.capabilities) }
        let cloudModels = ModelManager.shared.cloudModels.value.filter {
            !$0.model_identifier.isEmpty
        }.filter { requiresCapabilities.isSubset(of: $0.capabilities) }

        var appleIntelligenceAvailable = false
        if #available(iOS 26.0, macCatalyst 26.0, *),
           AppleIntelligenceModel.shared.isAvailable,
           requiresCapabilities.isSubset(of: modelCapabilities(
               identifier: AppleIntelligenceModel.shared.modelIdentifier
           ))
        {
            appleIntelligenceAvailable = true
        }

        if localModels.isEmpty, cloudModels.isEmpty, !appleIntelligenceAvailable {
            return []
        }

        var localBuildSections: [String: [(String, LocalModel)]] = [:]
        for item in localModels {
            localBuildSections[item.scopeIdentifier, default: []]
                .append((item.modelDisplayName, item))
        }
        var cloudBuildSections: [String: [(String, CloudModel)]] = [:]
        for item in cloudModels {
            cloudBuildSections[item.auxiliaryIdentifier, default: []]
                .append((item.modelDisplayName, item))
        }

        var localMenuChildren: [UIMenuElement] = []
        var localMenuChildrenOptions: UIMenu.Options = []
        if localModels.count < 4 { localMenuChildrenOptions.insert(.displayInline) }
        var cloudMenuChildren: [UIMenuElement] = []
        var cloudMenuChildrenOptions: UIMenu.Options = []
        if cloudModels.count < 4 { cloudMenuChildrenOptions.insert(.displayInline) }

        for key in localBuildSections.keys.sorted() {
            let items = localBuildSections[key] ?? []
            guard !items.isEmpty else { continue }
            let key = key.isEmpty ? String(localized: "Ungrouped") : key
            localMenuChildren.append(UIMenu(
                title: key,
                image: UIImage(systemName: "folder"),
                options: localMenuChildrenOptions,
                children: items.map { item in
                    UIAction(title: item.0, state: item.1.id == currentSelection ? .on : .off) { _ in
                        onCompletion(item.1.id)
                    }
                }
            ))
        }

        for key in cloudBuildSections.keys.sorted() {
            let items = cloudBuildSections[key] ?? []
            guard !items.isEmpty else { continue }
            let key = key.isEmpty ? String(localized: "Ungrouped") : key
            cloudMenuChildren.append(UIMenu(
                title: key,
                image: UIImage(systemName: "folder"),
                options: cloudMenuChildrenOptions,
                children: items.map { item in
                    UIAction(title: item.0, state: item.1.id == currentSelection ? .on : .off) { _ in
                        onCompletion(item.1.id)
                    }
                }
            ))
        }

        var finalChildren: [UIMenuElement] = []
        var finalOptions: UIMenu.Options = []
        if localMenuChildren.isEmpty || cloudMenuChildren.isEmpty || localMenuChildren.count + cloudMenuChildren.count < 10 {
            finalOptions.insert(.displayInline)
        }

        if allowSelectionWithNone {
            finalChildren.append(UIAction(
                title: "Use None",
                image: .init(systemName: "circle.dashed")
            ) { _ in
                onCompletion("")
            })
        }

        if #available(iOS 26.0, macCatalyst 26.0, *) {
            if appleIntelligenceAvailable {
                finalChildren.append(UIAction(
                    title: AppleIntelligenceModel.shared.modelDisplayName,
                    image: UIImage(systemName: "apple.intelligence"),
                    state: currentSelection == AppleIntelligenceModel.shared.modelIdentifier ? .on : .off
                ) { _ in
                    onCompletion(AppleIntelligenceModel.shared.modelIdentifier)
                })
            }
        }

        if !localMenuChildren.isEmpty {
            finalChildren.append(UIMenu(
                title: String(localized: "Local Models"),
                image: .modelLocal,
                options: finalOptions,
                children: localMenuChildren
            ))
        }
        if !cloudMenuChildren.isEmpty {
            finalChildren.append(UIMenu(
                title: String(localized: "Cloud Models"),
                image: .modelCloud,
                options: finalOptions,
                children: cloudMenuChildren
            ))
        }

        return finalChildren
    }
}
