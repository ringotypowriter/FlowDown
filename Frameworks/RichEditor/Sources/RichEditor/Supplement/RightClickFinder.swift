//
//  RightClickFinder.swift
//  RichEditor
//
//  Created by 秋星桥 on 3/1/25.
//

import UIKit

public class RightClickFinder: NSObject, UIContextMenuInteractionDelegate {
    private lazy var interaction = UIContextMenuInteraction(delegate: self)
    private var action: (() -> Void)? = nil
    private weak var targetView: UIView?
    private var contextMenuWillShow = false

    override public init() {
        super.init()
    }

    public func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation _: CGPoint
    ) -> UIContextMenuConfiguration? {
        contextMenuWillShow = true
        action?()
        return nil
    }

    public func contextMenuInteraction(
        _: UIContextMenuInteraction,
        willDisplayMenuFor _: UIContextMenuConfiguration,
        animator _: UIContextMenuInteractionAnimating?
    ) {
        contextMenuWillShow = true
    }

    public func contextMenuInteraction(
        _: UIContextMenuInteraction,
        willEndFor _: UIContextMenuConfiguration,
        animator _: UIContextMenuInteractionAnimating?
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.contextMenuWillShow = false
        }
    }

    public var isContextMenuActive: Bool {
        contextMenuWillShow
    }

    public func install(on view: UIView, action: @escaping () -> Void) {
        assert(self.action == nil, "RightClickFinder can only be installed once")
        self.action = action
        targetView = view
        view.isUserInteractionEnabled = true
        view.addInteraction(interaction)
    }
}
