//
//  Settings+Model.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import ConfigurableKit
import Foundation

extension Settings {
    static func modelDefaultValue(
        modelIdentifier: ServiceProvider.ModelIdentifier,
        withType type: ServiceProvider.ModelType,
        serviceProvider provider: ServiceProvider
    ) -> String {
        [
            provider.id.uuidString,
            type.rawValue,
            modelIdentifier,
        ].joined(separator: ";")
    }

    private static var defaultModelMenu: [ConfigurableObject] = {
        var ret = [ConfigurableObject]()
        for modelType in ServiceProvider.ModelType.allCases {
            let configObject = ConfigurableObject(
                icon: modelType.icon,
                title: modelType.interfaceText,
                explain: modelType.description,
                key: modelType.defaultKey,
                defaultValue: "",
                annotation: .list {
                    var ret: [ListAnnotation.ValueItem] = []
                    for provider in ServiceProviders.get() {
                        provider.enabledModels[.textCompletion]?.forEach { identifier in
                            ret.append(.init(
                                title: identifier,
                                section: provider.name,
                                rawValue: modelDefaultValue(
                                    modelIdentifier: identifier,
                                    withType: modelType,
                                    serviceProvider: provider
                                )
                            ))
                        }
                    }
                    ret.append(.init(
                        title: NSLocalizedString("Unspecified", comment: ""),
                        rawValue: ""
                    ))
                    return ret
                }
            )
            ret.append(configObject)
        }
        return ret
    }()

    static let modelSettings: ConfigurableObject = .init(
        icon: "server.rack",
        title: NSLocalizedString("Service", comment: ""),
        ephemeralAnnotation: .submenu { [
            ConfigurableObject(
                icon: "star",
                title: NSLocalizedString("Default Models", comment: ""),
                explain: NSLocalizedString("Configure default mode for various works.", comment: ""),
                ephemeralAnnotation: .submenu {
                    defaultModelMenu
                }
            ),
            ConfigurableObject(
                icon: "list.bullet",
                title: NSLocalizedString("Service Providers", comment: ""),
                explain: NSLocalizedString("Configure language model providers.", comment: ""),
                ephemeralAnnotation: .page { ServiceProviderController() }
            ),
        ] }
    )

    static func checkOrRevokeDefaultModel() {
        let providers = ServiceProviders.get()
        for modelType in ServiceProvider.ModelType.allCases {
            guard let identifier = modelType.getDefault() else { continue }

            var found = false

            for provider in providers where !found {
                for mid in provider.models[modelType, default: []] where !found {
                    let match = modelDefaultValue(
                        modelIdentifier: mid,
                        withType: modelType,
                        serviceProvider: provider
                    )
                    if match == identifier { found = true }
                }
            }

            if !found { modelType.removeDefault() }
        }
    }
}
