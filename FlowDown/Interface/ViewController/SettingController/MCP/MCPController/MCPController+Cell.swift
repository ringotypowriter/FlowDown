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
    class MCPServerCell: UITableViewCell {
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

        func configure(with clientId: ModelContextServer.ID) {
            guard let client = MCPService.shared.server(with: clientId) else {
                return
            }

            let icon = switch client.type {
            case .http:
                UIImage(systemName: "network") ?? UIImage()
            case .sse:
                UIImage(systemName: "antenna.radiowaves.left.and.right") ?? UIImage()
            }

            configurableView.configure(icon: icon)
            if let url = URL(string: client.endpoint), let host = url.host {
                configurableView.configure(title: "@\(host)")
            } else {
                configurableView.configure(title: "Unknown Server")
            }

            var descriptions: [String] = []
            descriptions.append(client.type.rawValue.uppercased())

            if client.isEnabled {
                let connectionStatusText = getConnectionStatusText(client.connectionStatus)
                descriptions.append(connectionStatusText)

                configurableView.iconView.tintColor = getConnectionStatusColor(client.connectionStatus)
            } else {
                descriptions.append(String(localized: "Disabled"))
                configurableView.iconView.tintColor = .systemGray
            }

            configurableView.configure(description: descriptions.joined(separator: " • "))
        }

        private func getConnectionStatusText(_ status: ModelContextServer.ConnectionStatus) -> String {
            switch status {
            case .connected:
                String(localized: "Connected")
            case .connecting:
                String(localized: "Connecting...")
            case .disconnected:
                String(localized: "Disconnected")
            case .failed:
                String(localized: "Connection Failed")
            }
        }

        private func getConnectionStatusColor(_ status: ModelContextServer.ConnectionStatus) -> UIColor {
            switch status {
            case .connected:
                UIColor(red: 65 / 255.0, green: 190 / 255.0, blue: 171 / 255.0, alpha: 1.0)
            case .connecting:
                .systemOrange
            case .disconnected:
                .systemGray
            case .failed:
                .systemRed
            }
        }
    }
}
