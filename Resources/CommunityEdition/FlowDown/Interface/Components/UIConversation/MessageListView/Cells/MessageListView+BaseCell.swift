//
//  MessageListView+BaseCell.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Combine
import UIKit

extension UIConversation.MessageListView {
    class BaseCell: UITableViewCell, UIConversation.MessageListView.TableLayoutEngine.LayoutableCell {
        var associatedObject: Element?
        var cancellable: Set<AnyCancellable> = []
        let containerView: UIView = .init()

        var layoutEngine: UIConversation.MessageListView.TableLayoutEngine?

        func layoutCache() -> UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
            guard let associatedObject, let engine = layoutEngine else {
                return UIConversation.MessageListView.TableLayoutEngine.ZeroLayoutCache()
            }
            let cache = engine.requestLayoutCacheFromCell(
                forElement: associatedObject,
                atWidth: bounds.width
            )
            return cache
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            commitInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commitInit()
        }

        private func commitInit() {
            selectionStyle = .none
            separatorInset = .zero
            contentView.addSubview(containerView)
            contentView.clipsToBounds = false
            clipsToBounds = false
            initializeContent()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let cache = layoutCache() as? LayoutCache else {
                assertionFailure()
                return
            }
            containerView.frame = cache.containerRect
            layoutContent(cache: cache.containerLayoutCache)
        }

        func registerViewModel(element: Element) {
            removeViewModelObject()
            associatedObject = element
            updateContent(object: element.viewModel, originalObject: element.object)
            setNeedsLayout()
        }

        func removeViewModelObject() {
            associatedObject = nil
            cancellable.forEach { $0.cancel() }
            cancellable.removeAll()
        }

        func initializeContent() {}
        func updateContent(object: any Element.ViewModel, originalObject: Element.UserObject?) {
            _ = object
            _ = originalObject
        }

        func layoutContent(cache: UIConversation.MessageListView.TableLayoutEngine.LayoutCache) {
            _ = cache
        }

        class func layoutInsideContainer(
            containerWidth: CGFloat,
            object: any Element.ViewModel
        ) -> UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
            _ = containerWidth
            _ = object
            assertionFailure("must override")
            return UIConversation.MessageListView.TableLayoutEngine.ZeroLayoutCache()
        }

        class func containerInset() -> UIEdgeInsets {
            let inset: CGFloat = 16
            let containerInset = UIEdgeInsets(top: inset / 2, left: inset, bottom: inset / 2, right: inset)
            return containerInset
        }
    }
}

extension UIConversation.MessageListView.BaseCell {
    class LayoutCache: UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
        var width: CGFloat
        var height: CGFloat
        var containerRect: CGRect
        var containerLayoutCache: any UIConversation.MessageListView.TableLayoutEngine.LayoutCache

        init(
            width: CGFloat,
            height: CGFloat,
            containerRect: CGRect,
            containerLayoutCache: any UIConversation.MessageListView.TableLayoutEngine.LayoutCache
        ) {
            self.width = width
            self.height = height
            self.containerRect = containerRect
            self.containerLayoutCache = containerLayoutCache
        }
    }

    class func resolveLayout(
        dataElement element: UIConversation.MessageListView.Element,
        contentWidth width: CGFloat
    ) -> any UIConversation.MessageListView.TableLayoutEngine.LayoutCache {
        let object = element.viewModel
        let containerInset = UIConversation.MessageListView.BaseCell.containerInset()
        let containerWidth = width - containerInset.left - containerInset.right
        let containerCache = Self.layoutInsideContainer(containerWidth: containerWidth, object: object)
        let cellHeight = containerCache.height + containerInset.top + containerInset.bottom
        let containerRect = CGRect(
            x: containerInset.left,
            y: containerInset.top,
            width: containerWidth,
            height: containerCache.height
        )
        let cache = LayoutCache(
            width: width,
            height: cellHeight,
            containerRect: containerRect,
            containerLayoutCache: containerCache
        )
        return cache
    }
}
