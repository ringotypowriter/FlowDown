//
//  MessageEditorView+Delegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import Foundation

extension UIConversation.MessageEditorView {
    protocol Delegate: AnyObject {
        func messageEditorSubmitMessage(_ editor: UIConversation.MessageEditorView, message: ViewModel)
    }
}
