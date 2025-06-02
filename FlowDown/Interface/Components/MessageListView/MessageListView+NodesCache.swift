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

        struct MarkdownPackage {
            let blocks: [MarkdownBlockNode]
            let mathContent: [Int: String]
            let renderedContent: RenderContext
        }

        private var cache: [MessageIdentifier: MarkdownPackage] = [:]
        private var messageDidChanged: [MessageIdentifier: Int] = [:]

        func package(for message: MessageRepresentation, theme: MarkdownTheme) -> MarkdownPackage {
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

        private func updateCache(for message: MessageRepresentation, theme: MarkdownTheme) -> MarkdownPackage {
            let content = message.content
            let result = MarkdownParser().parse(content)
            let rendered = MarkdownTextView.prepareMathContent(
                result.mathContext,
                theme: theme
            )
            let package = MarkdownPackage(
                blocks: result.document,
                mathContent: result.mathContext,
                renderedContent: rendered
            )
            cache[message.id] = package
            messageDidChanged[message.id] = message.content.hashValue
            return package
        }
    }
}

extension MarkdownTextView {
    static func prepareMathContent(_ content: [Int: String], theme: MarkdownTheme) -> RenderContext {
        var renderedContexts: RenderContext = [:]
        for (key, value) in content {
            let image = MathRenderer.renderToImage(
                latex: value,
                fontSize: theme.fonts.body.pointSize,
                textColor: theme.colors.body
            )?.withRenderingMode(.alwaysTemplate)
            let renderedContext = RenderedItem(
                image: image,
                text: value
            )
            renderedContexts["math://\(key)"] = renderedContext
        }
        return renderedContexts
    }
}
