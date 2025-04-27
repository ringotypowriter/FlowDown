//
//  MarkdownParser+Delegate.swift
//  FlowMarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import Foundation
import MarkdownParserCore

public extension MarkdownParser {
    protocol Delegate: AnyObject {
        func updateBlockNodes(_ blockNodes: [BlockNode])
    }
}
