//
//  Storage+Instance.swift
//  Conversation
//
//  Created by 秋星桥 on 1/21/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    static func db() throws -> Storage {
        if let instance { return instance }
        let new = try Storage()
        instance = new
        return new
    }

    private static var instance: Storage?
}
