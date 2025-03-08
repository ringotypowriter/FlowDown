//
//  MessageListView+UserCell.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Combine
import UIKit

extension UIConversation.MessageListView {
    class UserCell: BaseCell {
        let bubbleView = UIView()
        let textView = TextView()

        var message: Conversation.Message?

        override func initializeContent() {
            super.initializeContent()

            textView.isSelectable = true
            textView.isScrollEnabled = true
            textView.isEditable = false

            bubbleView.layerCornerRadius = 16
            bubbleView.backgroundColor = .accent.withAlphaComponent(0.1)

            containerView.addSubview(bubbleView)
            containerView.addSubview(textView)
        }

        override func updateContent(
            object: any UIConversation.MessageListView.Element.ViewModel,
            originalObject: Element.UserObject?
        ) {
            super.updateContent(object: object, originalObject: originalObject)
            guard let object = object as? ViewModel else {
                assertionFailure()
                return
            }
            guard let message = originalObject as? Conversation.Message else {
                assertionFailure()
                return
            }
            textView.attributedText = object.text
            self.message = message
        }

        override func layoutContent(cache: any UIConversation.MessageListView.TableLayoutEngine.LayoutCache) {
            super.layoutContent(cache: cache)
            guard let cache = cache as? LayoutCache else {
                assertionFailure()
                return
            }
            bubbleView.frame = cache.bubbleFrame
            textView.frame = cache.labelFrame
        }

        override class func layoutInsideContainer(
            containerWidth: CGFloat,
            object: any UIConversation.MessageListView.Element.ViewModel
        ) -> any UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
            guard let object = object as? ViewModel else {
                assertionFailure()
                return LayoutCache()
            }
            let cache = LayoutCache()
            cache.width = containerWidth

            let inset: CGFloat = 16
            let bubbleInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)

            let textAllowedLayoutFraction = 0.75
            let textWidth = min(
                object.text.measureWidth(),
                containerWidth * CGFloat(textAllowedLayoutFraction)
            )
            let textHeight = object.text.measureHeight(usingWidth: textWidth)
            let textRect = CGRect(
                x: containerWidth - textWidth - bubbleInset.right,
                y: bubbleInset.top,
                width: textWidth,
                height: textHeight
            )
            let bubbleRect = CGRect(
                x: textRect.minX - bubbleInset.left,
                y: textRect.minY - bubbleInset.top,
                width: textRect.width + bubbleInset.left + bubbleInset.right,
                height: textRect.height + bubbleInset.top + bubbleInset.bottom
            )
            cache.bubbleFrame = bubbleRect
            cache.labelFrame = textRect
            cache.height = bubbleRect.maxY
            return cache
        }
    }
}

extension UIConversation.MessageListView.UserCell {
    class ViewModel: UIConversation.MessageListView.Element.ViewModel {
        var text: NSAttributedString = .init()

        init(text: NSAttributedString) {
            self.text = text
        }

        convenience init(text: String) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .natural
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.body,
                .originalFont: UIFont.body,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle,
//                .underlineColor: UIColor.accent.withAlphaComponent(0.5),
//                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
            var text = text
            while text.contains("\n\n\n") {
                text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
            }
            self.init(text: NSMutableAttributedString(string: text, attributes: attributes))
        }

        func contentIdentifier(hasher: inout Hasher) {
            hasher.combine(text)
        }
    }
}

extension UIConversation.MessageListView.UserCell {
    class LayoutCache: UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
        var width: CGFloat = 0
        var height: CGFloat = 0

        var bubbleFrame: CGRect = .zero
        var labelFrame: CGRect = .zero
    }
}
