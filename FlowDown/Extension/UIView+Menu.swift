//
//  UIView+Menu.swift
//  FlowDown
//
//  Created by AI Assistant
//

import UIKit

extension UIView {
    /// Present a UIMenu at a specific anchor point using UIContextMenuInteraction
    /// This is a replacement for ChidoriMenu's present(menu:anchorPoint:) method
    func present(
        menu: UIMenu,
        anchorPoint: CGPoint? = nil,
        controllerDidLoad: @escaping (UIViewController) -> Void = { _ in },
        controllerDidPresent: @escaping (UIViewController) -> Void = { _ in }
    ) {
        // For UINavigationBar, use a different approach
        if let navigationBar = self as? UINavigationBar {
            presentMenuOnNavigationBar(navigationBar, menu: menu, anchorPoint: anchorPoint)
            return
        }
        
        // Create a temporary button at the anchor point
        let button = UIButton(type: .system)
        button.frame = CGRect(
            x: anchorPoint?.x ?? bounds.midX,
            y: anchorPoint?.y ?? bounds.midY,
            width: 1,
            height: 1
        )
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        button.alpha = 0 // Make it invisible
        
        addSubview(button)
        
        // Trigger the menu
        DispatchQueue.main.async {
            button.sendActions(for: .menuActionTriggered)
            
            // Remove the button after a delay to allow the menu to appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                button.removeFromSuperview()
            }
        }
    }
    
    private func presentMenuOnNavigationBar(
        _ navigationBar: UINavigationBar,
        menu: UIMenu,
        anchorPoint: CGPoint?
    ) {
        // For navigation bar, we need to use a different approach
        // Create a temporary bar button item
        let button = UIButton(type: .system)
        button.frame = CGRect(
            x: anchorPoint?.x ?? navigationBar.bounds.maxX - 20,
            y: anchorPoint?.y ?? navigationBar.bounds.midY,
            width: 1,
            height: 1
        )
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        button.alpha = 0
        
        navigationBar.addSubview(button)
        
        DispatchQueue.main.async {
            button.sendActions(for: .menuActionTriggered)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                button.removeFromSuperview()
            }
        }
    }
}

extension UIButton {
    /// Present the button's menu programmatically
    /// This is a replacement for ChidoriMenu's presentMenu() method
    func presentMenu(
        controllerDidLoad: @escaping (UIViewController) -> Void = { _ in },
        controllerDidPresent: @escaping (UIViewController) -> Void = { _ in }
    ) {
        guard menu != nil else { return }
        sendActions(for: .menuActionTriggered)
    }
}
