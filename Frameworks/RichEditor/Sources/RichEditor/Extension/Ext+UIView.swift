//
//  Ext+UIView.swift
//  RichEditor
//
//  Created by 秋星桥 on 2025/1/11.
//

import UIKit

extension UIView {
    var parentViewController: UIViewController? {
        weak var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }

    func withAnimation(duration: TimeInterval = 0.5, _ execute: @escaping () -> Void, completion: @escaping () -> Void = {}) {
        layoutIfNeeded()
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0,
            options: .curveEaseInOut
        ) {
            execute()
            self.layoutIfNeeded()
        } completion: { _ in
            completion()
        }
    }

    func puddingAnimate() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        transform = CGAffineTransform(scaleX: 0.975, y: 0.975)
        layoutIfNeeded()
        withAnimation { self.transform = .identity }
    }
}
