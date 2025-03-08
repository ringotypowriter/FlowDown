//
//  MainController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import Combine
import ConfigurableKit
import UIKit

class MainController: UIViewController {
    lazy var largeContentController = LargeContentController()
    lazy var compactContentController = CompactContentController()

    var currentController: UIViewController = .init()

    func determineController() -> UIViewController {
        #if targetEnvironment(macCatalyst)
            return largeContentController
        #else
            if UIDevice().userInterfaceIdiom == .phone {
                return compactContentController
            }
            if view.bounds.width < 800 || view.bounds.height < 500 {
                return compactContentController
            }
            return largeContentController
        #endif
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .comfortableBackground
    }

    func setupControllerIfNeeded() {
        let controller = determineController()
        guard controller != currentController else { return }
        currentController.removeFromParent()
        currentController = controller
        addChildViewController(controller, toContainerView: view)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        setupControllerIfNeeded()
        currentController.view.frame = view.bounds
    }

    #if targetEnvironment(macCatalyst)
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            dispatchTouchAsWindowMovement()
        }
    #endif
}

#if targetEnvironment(macCatalyst)
    private extension UIResponder {
        func dispatchTouchAsWindowMovement() {
            guard let appType = NSClassFromString("NSApplication") as? NSObject.Type,
                  let nsApp = appType.value(forKey: "sharedApplication") as? NSObject,
                  let currentEvent = nsApp.value(forKey: "currentEvent") as? NSObject,
                  let nsWindow = currentEvent.value(forKey: "window") as? NSObject
            else { return }
            nsWindow.perform(
                NSSelectorFromString("performWindowDragWithEvent:"),
                with: currentEvent
            )
        }
    }
#endif
