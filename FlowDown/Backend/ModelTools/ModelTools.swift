//
//  ModelTools.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/27/25.
//

import ChatClientKit
import ConfigurableKit
import Foundation
import UIKit

class ModelTool: NSObject {
    var functionName: String {
        guard case let .function(name, _, _, _) = definition else {
            assertionFailure()
            return UUID().uuidString
        }
        return name
    }

    var shortDescription: String {
        fatalError("must be overriden")
    }

    var interfaceName: String {
        fatalError("must be overriden")
    }

    var definition: ChatRequestBody.Tool {
        fatalError("must be overridden")
    }

    class var controlObject: ConfigurableObject {
        fatalError("must be overridden")
    }

    func createConfigurableObjectView() -> UIView {
        Self.controlObject.createView()
    }

    var isEnabled: Bool {
        ConfigurableKit.value(forKey: Self.controlObject.key) ?? true
    }

    nonisolated
    func execute(with input: String, anchorTo _: UIView) async throws -> String {
        _ = input
        throw NSError()
    }
}
