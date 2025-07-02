//
//  MCPController+Bar.swift
//  FlowDown
//
//  Created by LiBr on 6/30/25.
//

import Storage
import UIKit

extension SettingController.SettingContent.MCPController {
    @objc func addClientTapped() {
        let client = MCPService.shared.newMCPClient()
        let controller = MCPEditorController(clientId: client.id)
        navigationController?.pushViewController(controller, animated: true)
    }
}
