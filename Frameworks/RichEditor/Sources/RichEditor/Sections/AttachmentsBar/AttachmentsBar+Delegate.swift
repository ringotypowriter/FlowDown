//
//  AttachmentsBar+Delegate.swift
//  RichEditor
//
//  Created by 秋星桥 on 1/17/25.
//

import Foundation

public extension AttachmentsBar {
    protocol Delegate: AnyObject {
        func attachmentBarDidUpdateAttachments(_ attachments: [Item])
    }
}
