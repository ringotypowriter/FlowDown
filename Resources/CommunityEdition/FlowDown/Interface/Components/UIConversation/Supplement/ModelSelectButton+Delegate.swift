//
//  ModelSelectButton+Delegate.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import Foundation

extension UIConversation.ModelSelectButton {
    protocol Delegate: AnyObject {
        func modelPickerDidPick(
            provider: ServiceProvider,
            modelType: ServiceProvider.ModelType,
            modelIdentifier: String
        )
    }
}
