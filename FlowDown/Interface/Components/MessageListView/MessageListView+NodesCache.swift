//
//  Created by ktiays on 2025/2/11.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import MarkdownParser
import MarkdownView
import Storage
import UIKit

extension MessageListView {
    final class MarkdownPackageCache {
        typealias MessageIdentifier = Message.ID

        private var cache: [MessageIdentifier: MarkdownTextView.PreprocessedContent] = [:]
        private var messageDidChanged: [MessageIdentifier: Int] = [:]

        func package(for message: MessageRepresentation, theme: MarkdownTheme) -> MarkdownTextView.PreprocessedContent {
            let id = message.id
            let cachedContent = messageDidChanged[id]
            if cachedContent == message.content.hashValue {
                if let nodes = cache[id] {
                    return nodes
                }
                return updateCache(for: message, theme: theme)
            }
            return updateCache(for: message, theme: theme)
        }

        private func updateCache(for message: MessageRepresentation, theme: MarkdownTheme) -> MarkdownTextView.PreprocessedContent {
            let content = message.content
            let result = MarkdownParser().parse(content)
            let package = MarkdownTextView.PreprocessedContent(parserResult: result, theme: theme)
            cache[message.id] = package
            messageDidChanged[message.id] = message.content.hashValue
            return package
        }
    }
}
