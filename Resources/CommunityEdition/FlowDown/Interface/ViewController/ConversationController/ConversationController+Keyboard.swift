//
//  ConversationController+Keyboard.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/11.
//

import UIKit

extension ConversationController {
    @objc func keyboardWillAppear(_ notification: Notification) {
        let info = notification.userInfo ?? [:]
        let keyboardHeight = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue
            .height ?? 0
        // get messageEditor frame maxY size in window
        let messageEditorMaxY = view.convert(messageEditor.frame, to: nil).maxY
        // get keyboard minY size in window
        let keyboardMinY = UIScreen.main.bounds.height - keyboardHeight
        // get moving offset
        let offset = messageEditorMaxY - keyboardMinY
        animateWithKeyboard(userInfo: info) {
            self.keyboardAdapter.snp.updateConstraints { make in
                make.height.equalTo(offset)
            }
            self.messageList.tableView.contentOffset.y += offset
            self.view.layoutIfNeeded()
        }
    }

    @objc func keyboardWillDisappear(_ notification: Notification) {
        let info = notification.userInfo ?? [:]
        animateWithKeyboard(userInfo: info) {
            self.keyboardAdapter.snp.updateConstraints { make in
                make.height.equalTo(0)
            }
            self.view.layoutIfNeeded()
        }
    }

    private func animateWithKeyboard(userInfo info: [AnyHashable: Any], executing: @escaping () -> Void) {
        let keyboardAnimationDuration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?
            .doubleValue ?? 0
        let keyboardAnimationCurve = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?
            .uintValue ?? 0
        UIView.animate(
            withDuration: keyboardAnimationDuration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: keyboardAnimationCurve),
            animations: {
                executing()
                self.view.layoutIfNeeded()
            },
            completion: nil
        )
    }
}
