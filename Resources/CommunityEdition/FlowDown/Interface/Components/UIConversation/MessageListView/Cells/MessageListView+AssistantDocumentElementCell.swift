//
//  MessageListView+AssistantDocumentElementCell.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Combine
import MarkdownParser
import MarkdownParserCore
import MarkdownView
import UIKit

extension UIConversation.MessageListView {
    class AssistantDocumentElementCell: BaseCell {
        let markdownView = MarkdownView()
        var message: Conversation.Message?

        override func initializeContent() {
            super.initializeContent()

            containerView.addSubview(markdownView)
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            markdownView.prepareForReuse()
        }

        override func updateContent(
            object: any UIConversation.MessageListView.Element.ViewModel,
            originalObject: Element.UserObject?
        ) {
            guard let object = object as? ViewModel else {
                assertionFailure()
                return
            } // deinit might case this
            guard let message = originalObject as? Conversation.Message else {
                assertionFailure()
                return
            }
            _ = object
            self.message = message
        }

        override func layoutContent(cache: any UIConversation.MessageListView.TableLayoutEngine.LayoutCache) {
            super.layoutContent(cache: cache)
            guard let cache = cache as? LayoutCache else {
                assertionFailure()
                return
            }
            markdownView.frame = cache.markdownFrame

            UIView.performWithoutAnimation {
                markdownView.updateContentViews([cache.manifests])
            }
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

            let manifests = object.block.manifest(theme: object.theme)
            manifests.setLayoutTheme(.default)

//            if containerWidth < 500 {
            manifests.setLayoutWidth(containerWidth)
            manifests.layoutIfNeeded()
//            } else {
//                manifests.setLayoutWidth(containerWidth * 1)
//                manifests.layoutIfNeeded()
//            }
            let textRect = CGRect(
                x: 0,
                y: 0,
                width: manifests.size.width,
                height: manifests.size.height
            )
            cache.markdownFrame = textRect
            cache.manifests = manifests
            cache.height = textRect.maxY

            return cache
        }
    }
}

extension UIConversation.MessageListView.AssistantDocumentElementCell {
    class ViewModel: UIConversation.MessageListView.Element.ViewModel {
        var theme: Theme
        var block: BlockNode
        var groupIntrinsicWidth: CGFloat

        enum GroupLocation {
            case begin
            case center
            case end
        }

        var groupLocation: GroupLocation = .center

        init(theme: Theme = .default, block: BlockNode, groupIntrinsicWidth: CGFloat, groupLocation _: GroupLocation = .center) {
            self.theme = theme
            self.block = block
            self.groupIntrinsicWidth = groupIntrinsicWidth
        }

        func contentIdentifier(hasher: inout Hasher) {
            hasher.combine(block)
        }
    }
}

extension UIConversation.MessageListView.AssistantDocumentElementCell {
    class LayoutCache: UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
        var width: CGFloat = 0
        var height: CGFloat = 0

        var markdownFrame: CGRect = .zero
        var manifests: AnyBlockManifest = BlockView.Manifest()
    }
}
