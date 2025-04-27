//
//  MessageEditorView+TextEditorView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Foundation

extension UIConversation.MessageEditorView {
    class TextEditorView: TextView {
        var returnKeyPressed: () -> Void = {}

        override var keyCommands: [UIKeyCommand]? {
            [
                UIKeyCommand(input: "\r", modifierFlags: .alternate, action: #selector(insertNewLine)),
                UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(returnPressed)),
            ]
        }

        @objc func returnPressed() {
            returnKeyPressed()
        }

        @objc func insertNewLine() {
            insertText("\n")
        }

        override func commitInit() {
            super.commitInit()
            clipsToBounds = true
        }
    }
}
