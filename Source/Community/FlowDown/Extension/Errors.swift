//
//  Errors.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import Foundation

enum Errors {
    static func throwText(_ error: String) throws -> Never {
        throw NSError(
            domain: NSLocalizedString("Error", comment: ""),
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: error,
            ]
        )
    }
}
