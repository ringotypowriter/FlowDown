//
//  MCPController+Cell.swift
//  FlowDown
//
//  Created by LiBr on 6/30/25.
//

import ConfigurableKit
import Storage
import UIKit

extension SettingController.SettingContent.MCPController {
    class MCPClientCell: UITableViewCell {
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

        let configurableView = ConfigurableActionView(
            responseEverywhere: true,
            actionBlock: { _ in }
        )

        override func prepareForReuse() {
            super.prepareForReuse()
        }

        func configure(with clientId: ModelContextClient.ID) {
            guard let client = MCPService.shared.client(with: clientId) else {
                return
            }

            let icon = switch client.type {
            case .http:
                UIImage(systemName: "network") ?? UIImage()
            case .sse:
                UIImage(systemName: "antenna.radiowaves.left.and.right") ?? UIImage()
            }

            configurableView.configure(icon: icon)
            configurableView.configure(title: client.name.isEmpty ? String(localized: "Unnamed Client") : client.name)

            var descriptions: [String] = []
            descriptions.append(client.type.rawValue.uppercased())
            if !client.endpoint.isEmpty {
                descriptions.append(client.endpoint)
            }
            if !client.isEnabled {
                descriptions.append(String(localized: "Disabled"))
            }

            configurableView.configure(description: descriptions.joined(separator: " • "))
        }
    }
}
