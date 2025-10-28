//
//  Updatable.swift
//  Storage
//
//  Created by king on 2025/10/28.
//

import Foundation

public protocol Updatable: AnyObject {
    var modified: Date { get set }

    @discardableResult
    func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Self, Value>, to newValue: Value) -> Bool
    func update(_ block: (Self) -> Void)
}
