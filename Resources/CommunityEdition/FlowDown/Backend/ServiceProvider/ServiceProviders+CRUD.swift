//
//  ServiceProviders+CRUD.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import ConfigurableKit
import Foundation

extension ServiceProviders {
    static func get() -> [ServiceProvider] {
        ConfigurableKit.value(
            forKey: .serviceProvider,
            defaultValue: []
        )
    }

    static func get(id: ServiceProvider.ID?) -> ServiceProvider? {
        guard let id else { return nil }
        return get().first { $0.id == id }
    }

    static func newName(forTemplate template: ServiceProvider.Template) -> String {
        let current: [ServiceProvider] = ConfigurableKit.value(
            forKey: .serviceProvider,
            defaultValue: []
        )
        let existingCount = current.count(where: { $0.template == template })
        if existingCount >= 1 {
            return "\(template.name) \(existingCount + 1)"
        } else {
            return template.name
        }
    }

    static func save(provider: ServiceProvider) {
        var current: [ServiceProvider] = ConfigurableKit.value(
            forKey: .serviceProvider,
            defaultValue: []
        )
        let index = current.firstIndex { $0.id == provider.id }
        if let index {
            current[index] = provider
        } else {
            current.append(provider)
        }
        ConfigurableKit.set(value: current, forKey: .serviceProvider)
    }

    static func delete(identifier pid: ServiceProvider.ID) {
        var current: [ServiceProvider] = ConfigurableKit.value(
            forKey: .serviceProvider,
            defaultValue: []
        )
        current.removeAll { $0.id == pid }
        ConfigurableKit.set(value: current, forKey: .serviceProvider)
    }
}
