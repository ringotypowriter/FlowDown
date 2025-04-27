//
//  Created by ktiays on 2025/2/11.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import MarkdownNode
import MarkdownParser
import Storage
import UIKit

extension MessageListView {
    final class MarkdownNodesCache {
        typealias MessageIdentifier = Message.ID

        private var cache: [MessageIdentifier: [MarkdownBlockNode]] = [:]
        private var contentCache: [MessageIdentifier: String] = [:]

        func nodes(for message: MessageRepresentation) -> [MarkdownBlockNode] {
            let id = message.id
            let cachedContent = contentCache[id]
            if cachedContent == message.content {
                if let nodes = cache[id] {
                    return nodes
                }
                return updateCache(for: message)
            }
            return updateCache(for: message)
        }

        private func updateCache(for message: MessageRepresentation) -> [MarkdownBlockNode] {
            let content = message.content
            let nodes = MarkdownParser().feed(content)
            cache[message.id] = nodes
            contentCache[message.id] = content
            return nodes
        }
    }
}
