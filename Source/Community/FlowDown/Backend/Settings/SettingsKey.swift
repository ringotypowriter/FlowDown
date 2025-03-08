//
//  SettingsKey.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/6.
//

import Combine
import ConfigurableKit
import Foundation

enum SettingsKey: String {
    case theme = "wiki.qaq.theme"
    case serviceProvider = "wiki.qaq.service.provider"
    case defaultModelPrefix = "wiki.qaq.default.models"
}

extension ConfigurableKit {
    @inline(__always)
    static func set(
        value: (some Codable)?,
        forKey key: SettingsKey,
        storage: KeyValueStorage = storage
    ) {
        set(value: value, forKey: key.rawValue, storage: storage)
    }

    @inline(__always)
    static func value<T: Codable>(
        forKey key: SettingsKey,
        defaultValue: T,
        storage: KeyValueStorage = storage
    ) -> T {
        value(forKey: key, storage: storage) ?? defaultValue
    }

    @inline(__always)
    static func value<T: Codable>(
        forKey key: SettingsKey,
        storage: KeyValueStorage = storage
    ) -> T? {
        value(forKey: key.rawValue, storage: storage)
    }

    @inline(__always)
    static func publisher<T: Codable>(
        forKey key: SettingsKey,
        type _: T.Type,
        storage: KeyValueStorage = storage
    ) -> AnyPublisher<T?, Never> {
        publisher(forKey: key.rawValue, type: T.self, storage: storage)
    }
}
