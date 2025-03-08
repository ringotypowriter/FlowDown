//
//  TitleBarView+Delegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/13.
//

import UIKit

extension UIConversation.TitleBarView {
    protocol Delegate: AnyObject {
        func titleBarCreateContextMenu() -> [UIMenuElement]
    }
}
