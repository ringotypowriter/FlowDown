//
//  NewConversationPickerController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import UIKit

class NewConversationPickerController: PopUpController {
    override class func permittedArrowDirections() -> UIPopoverArrowDirection {
        .up
    }

    override class func createContentView() -> UIView {
        UIView()
    }
}
