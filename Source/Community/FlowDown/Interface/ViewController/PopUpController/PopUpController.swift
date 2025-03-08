//
//  PopUpController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import UIKit

class PopUpController: UIViewController {
    let contentView = createContentView()

    #if !targetEnvironment(macCatalyst)
        let backgroundView = UIView()
    #endif

    required init(sourceView: UIView) {
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .popover
        modalPresentationStyle = .popover
        preferredContentSize = CGSize(width: 400, height: 300)
        popoverPresentationController?.delegate = self
        popoverPresentationController?.sourceView = sourceView
        let padding: CGFloat = 4
        popoverPresentationController?.sourceRect = .init(
            x: -padding,
            y: -padding,
            width: sourceView.frame.width + padding * 2,
            height: sourceView.frame.height + padding * 2
        )
        popoverPresentationController?.permittedArrowDirections = Self.permittedArrowDirections()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        #if !targetEnvironment(macCatalyst)
            view.addSubview(backgroundView)
            backgroundView.backgroundColor = .systemBackground
            backgroundView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(-32)
            }
        #endif
    }

    class func permittedArrowDirections() -> UIPopoverArrowDirection {
        .any
    }

    class func createContentView() -> UIView {
        .init()
    }
}

extension PopUpController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(
        for _: UIPresentationController,
        traitCollection _: UITraitCollection
    ) -> UIModalPresentationStyle {
        .none
    }
}
