//
//  ChatTemplateEditorController.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import UIKit

class ChatTemplateEditorController: StackScrollController {
    let templateIdentifier: ChatTemplate.ID
    init(templateIdentifier: ChatTemplate.ID) {
        self.templateIdentifier = templateIdentifier
        super.init()
        title = NSLocalizedString("Edit Template", comment: "")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
