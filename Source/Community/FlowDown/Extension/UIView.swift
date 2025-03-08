//
//  UIView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import UIKit

extension UIView {
    func withAnimation(_ animation: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0.8,
            options: .curveEaseInOut,
            animations: {
                animation()
                self.layoutIfNeeded()
            },
            completion: completion
        )
    }
}

extension UIView {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIView.dismissKeyboard))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        endEditing(true)
    }
}
