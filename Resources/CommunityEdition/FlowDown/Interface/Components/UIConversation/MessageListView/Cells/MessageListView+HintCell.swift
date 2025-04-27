//
//  MessageListView+HintCell.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Combine
import UIKit

extension UIConversation.MessageListView {
    class HintCell: BaseCell {
        let label = UILabel().then { view in
            view.font = .footnote
            view.alpha = 0.5
            view.numberOfLines = 0
        }

        override func initializeContent() {
            super.initializeContent()
            containerView.addSubview(label)
        }

        override func updateContent(
            object: any UIConversation.MessageListView.Element.ViewModel,
            originalObject: Element.UserObject?
        ) {
            super.updateContent(object: object, originalObject: originalObject)
            guard let object = object as? ViewModel else { return }
            label.attributedText = object.hint
        }

        override func layoutContent(cache: any UIConversation.MessageListView.TableLayoutEngine.LayoutCache) {
            super.layoutContent(cache: cache)
            guard let cache = cache as? LayoutCache else {
                assertionFailure()
                return
            }
            label.frame = cache.labelFrame
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
            cache.height = object.hint.measureHeight(usingWidth: containerWidth)
            cache.labelFrame = .init(x: 0, y: 0, width: containerWidth, height: cache.height)
            return cache
        }
    }
}

extension UIConversation.MessageListView.HintCell {
    class ViewModel: UIConversation.MessageListView.Element.ViewModel {
        var hint: NSAttributedString = .init()

        init(hint: NSAttributedString) {
            self.hint = hint
        }

        convenience init(hint: String) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.footnote,
                .originalFont: UIFont.footnote,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle,
            ]
            let text = NSMutableAttributedString(string: hint, attributes: attributes)
            self.init(hint: text)
        }

        func contentIdentifier(hasher: inout Hasher) {
            hasher.combine(hint)
        }
    }
}

extension UIConversation.MessageListView.HintCell {
    class LayoutCache: UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
        var width: CGFloat = 0
        var height: CGFloat = 0

        var labelFrame: CGRect = .zero
    }
}
