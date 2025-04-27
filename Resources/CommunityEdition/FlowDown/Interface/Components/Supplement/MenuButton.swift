//
//  MenuButton.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/6.
//

import UIKit

class MenuButton: UIButton {
    let createMenu: () -> UIMenu?

    init(createMenu: @escaping () -> (UIMenu?)) {
        self.createMenu = createMenu

        super.init(frame: .zero)

        setImage(UIImage(systemName: "ellipsis"), for: .normal)
        tintColor = .label
        imageView?.contentMode = .scaleAspectFit
        menu = .init(children: [UIDeferredMenuElement.uncached { [weak self] provider in
            let menu = self?.createMenu()
            provider(menu?.children ?? [])
        }])
        showsMenuAsPrimaryAction = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
