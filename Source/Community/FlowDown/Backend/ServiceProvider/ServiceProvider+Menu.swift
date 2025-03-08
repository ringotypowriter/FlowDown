//
//  ServiceProvider+Menu.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/7.
//

import ConfigurableKit
import UIKit

extension ServiceProvider {
    func createMenu(referencingView view: UIView) -> UIMenu? {
        .init(children: [
            UIMenu(title: "Metadata", options: [.displayInline], children: [
                UIAction(
                    title: NSLocalizedString("Copy Name", comment: ""),
                    image: UIImage(systemName: "doc.on.doc"),
                    handler: { _ in
                        UIPasteboard.general.string = self.name
                    }
                ),
                UIAction(
                    title: NSLocalizedString("Copy Base Endpoint", comment: ""),
                    image: UIImage(systemName: "doc.on.doc"),
                    handler: { _ in
                        UIPasteboard.general.string = self.baseEndpoint.url?.absoluteString ?? ""
                    }
                ),
                UIAction(
                    title: NSLocalizedString("Copy Token", comment: ""),
                    image: UIImage(systemName: "doc.on.doc"),
                    handler: { _ in
                        UIPasteboard.general.string = self.token
                    }
                ),
                UIAction(
                    title: NSLocalizedString("Copy Model List", comment: ""),
                    image: UIImage(systemName: "doc.on.doc"),
                    handler: { _ in
                        UIPasteboard.general.string = self.modelTextList
                    }
                ),
                UIAction(
                    title: NSLocalizedString("Copy Enabled Model List", comment: ""),
                    image: UIImage(systemName: "doc.on.doc"),
                    handler: { _ in
                        UIPasteboard.general.string = self.enabledModelTextList
                    }
                ),
            ]),
            UIMenu(title: "Operations", options: [.displayInline], children: [
                UIAction(
                    title: NSLocalizedString("Duplicate", comment: ""),
                    image: UIImage(systemName: "doc.on.doc")
                ) { _ in
                    var new = self
                    new.id = .init()
                    new.name += " " + NSLocalizedString("Copied", comment: "")
                    ServiceProviders.save(provider: new)
                },
                UIAction(
                    title: NSLocalizedString("Delete Service Provider", comment: ""),
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { _ in
                    let alert = UIAlertController(
                        title: NSLocalizedString("Delete Service Provider", comment: ""),
                        message: NSLocalizedString("Are you sure to delete this service provider?", comment: ""),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(
                        title: NSLocalizedString("Delete", comment: ""),
                        style: .destructive
                    ) { _ in
                        ServiceProviders.delete(identifier: self.id)
                    })
                    alert.addAction(UIAlertAction(
                        title: NSLocalizedString("Cancel", comment: ""),
                        style: .cancel,
                        handler: nil
                    ))
                    view.parentViewController?.present(alert, animated: true)
                },
            ]),
        ].compactMap(\.self))
    }
}
