//
//  Then.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import Foundation

public protocol Then {}

public extension Then where Self: Any {
    @inlinable
    @discardableResult
    func with(_ block: (inout Self) throws -> Void) rethrows -> Self {
        var copy = self
        try block(&copy)
        return copy
    }

    @inlinable
    func `do`(_ block: (Self) throws -> Void) rethrows {
        try block(self)
    }
}

public extension Then where Self: AnyObject {
    @inlinable
    @discardableResult
    func then(_ block: (Self) throws -> Void) rethrows -> Self {
        try block(self)
        return self
    }
}

extension NSObject: Then {}

extension Array: Then {}
extension Dictionary: Then {}
extension Set: Then {}
extension JSONDecoder: Then {}
extension JSONEncoder: Then {}
