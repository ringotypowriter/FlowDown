//
//  MessageListView+SpacerCell.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/12.
//

import Combine
import UIKit

extension UIConversation.MessageListView {
    class SpacerCell: BaseCell {
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
            cache.height = object.height
            return cache
        }
    }
}

extension UIConversation.MessageListView.SpacerCell {
    class ViewModel: UIConversation.MessageListView.Element.ViewModel {
        var height: CGFloat
        init(height: CGFloat) {
            self.height = height
        }

        func contentIdentifier(hasher: inout Hasher) {
            hasher.combine(height)
        }
    }
}

extension UIConversation.MessageListView.SpacerCell {
    class LayoutCache: UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
}
