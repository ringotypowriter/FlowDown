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

    override public init() {
        super.init()
    }

    public func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation _: CGPoint
    ) -> UIContextMenuConfiguration? {
        action?()
        return nil
    }

    public func install(on view: UIView, action: @escaping () -> Void) {
        assert(self.action == nil, "RightClickFinder can only be installed once")
        self.action = action
        view.isUserInteractionEnabled = true
        view.addInteraction(interaction)
    }
}
