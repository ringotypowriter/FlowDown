//
//  Updatable.swift
//  Storage
//
//  Created by king on 2025/10/28.
//

import Foundation

public protocol Updatable: AnyObject {
    @discardableResult
    func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Self, Value>, to newValue: Value) -> Bool

    @discardableResult
    func update<Value: Equatable>(_ keyPath: KeyPath<Self, Value>, to newValue: Value) -> Bool
}

public extension Updatable {
    @discardableResult
    func update<Value: Equatable>(_ keyPath: KeyPath<Self, Value>, to newValue: Value) -> Bool {
        guard let writable = keyPath as? ReferenceWritableKeyPath<Self, Value> else {
            assertionFailure("❌ Attempted to update a read-only keyPath: \(keyPath)")
            return false
        }
        return update(writable, to: newValue)
    }
}
