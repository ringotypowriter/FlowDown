//
//  ServiceProviderPreviewCell.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/7.
//

import ConfigurableKit
import UIKit

extension ServiceProviderController {
    class ServiceProviderPreviewCell: UITableViewCell {
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            let margin = AutoLayoutMarginView(configurableView)
            contentView.addSubview(margin)
            margin.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            separatorInset = .zero
            selectionStyle = .none
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        var associatedObject: ServiceProvider?

        let configurableView = ConfigurableActionView(
            responseEverywhere: true,
            actionBlock: { _ in }
        )

        override func prepareForReuse() {
            super.prepareForReuse()
            associatedObject = nil
        }

        func registerViewModel(element: ServiceProvider) {
            #if DEBUG
                if let parentViewController {
                    assert(parentViewController.navigationController != nil)
                }
            #endif
            associatedObject = element
            configurableView.configure(icon: .init(systemName: "server.rack"))
            configurableView.configure(title: element.name)
            configurableView.configure(description: element.interfaceDescription)
        }
    }
}
