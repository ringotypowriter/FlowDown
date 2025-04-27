//
//  Annotation+ChidoriMenu.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/26/25.
//

import ChidoriMenu
import ConfigurableKit
import Foundation
import GlyphixTextFx
import UIKit

open class ChidoriListAnnotation: ConfigurableObject.AnnotationProtocol {
    let selections: () -> [ListAnnotation.ValueItem]
    init(selections: @escaping (() -> [ListAnnotation.ValueItem])) {
        self.selections = selections
    }

    public func createView(fromObject object: ConfigurableObject) -> ConfigurableView {
        ConfigurableChidoriMenuView(storage: object.__value, selection: selections)
    }
}

class ConfigurableChidoriMenuView: ConfigurableMenuView {
    class ChidoriMenuButton: EasyHitButton {
        var chidoriMenu: UIMenu? = nil
        override var menu: UIMenu? {
            set { chidoriMenu = newValue }
            get { nil }
        }

        init() {
            super.init(frame: .zero)
            addTarget(self, action: #selector(showMenu), for: .touchUpInside)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override var showsMenuAsPrimaryAction: Bool {
            get { false }
            set { /* pass */ }
        }

        @objc func showMenu() {
            guard let menu = chidoriMenu, !menu.children.isEmpty else {
                shake()
                return
            }
            present(menu: menu)
        }
    }

    override var button: EasyHitButton { contentView as! ChidoriMenuButton }

    override class func createContentView() -> UIView {
        ChidoriMenuButton()
    }
}
