//
//  MessageEditorView+ViewModel.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Foundation

extension UIConversation.MessageEditorView {
    class ViewModel {
        var message: String = ""
        var attachments: [Attachment] = []
    }
}

extension UIConversation.MessageEditorView.ViewModel {
    struct Attachment {
        var name: String
        var preview: UIImage
        var url: URL
    }
}

extension UIConversation.MessageEditorView.ViewModel {
    var isSendable: Bool {
        ![
            message.isEmpty,
            attachments.isEmpty
        ].allSatisfy(\.self)
    }
}
