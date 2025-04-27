//
//  MessageEditorView+UITextViewDelegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import UIKit

extension UIConversation.MessageEditorView: UITextViewDelegate {
    func suggestedEditorHeight(_ textView: UITextView) -> CGFloat {
        var height = textView.contentSize.height
        height = max(50, height)
        height = min(250, height)
        return height
    }

    func textViewDidBeginEditing(_: UITextView) {
        updateContentStatus()
    }

    func textViewDidEndEditing(_: UITextView) {
        updateContentStatus()
        clearTextAttribute()
    }

    func textViewDidChange(_: UITextView) {
        updateContentStatus()
    }

    func clearTextAttribute() {
        let text = textView.text
        textView.attributedText = nil
        textView.text = text
        textView.font = .body
        textView.textColor = .label
    }
}
