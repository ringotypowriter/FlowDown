//
//  ModelTools.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/27/25.
//

import ChatClientKit
import ConfigurableKit
import Foundation
import RichEditor
import UIKit

/// 工具执行结果（支持附件）
struct ModelToolExecutionResult {
    let textContent: String
    let attachments: [RichEditorView.Object.Attachment]

    init(text: String) {
        textContent = text
        attachments = []
    }

    init(text: String, attachments: [RichEditorView.Object.Attachment]) {
        textContent = text
        self.attachments = attachments
    }
}

class ModelTool: NSObject, @unchecked Sendable {
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

    var interfaceIcon: String {
        Self.controlObject.icon
    }

    var definition: ChatRequestBody.Tool {
        fatalError("must be overridden")
    }

    class var controlObject: ConfigurableObject {
        fatalError("must be overridden")
    }

    nonisolated func createConfigurableObjectView() -> UIView {
        MainActor.assumeIsolated {
            Self.controlObject.createView()
        }
    }

    var isEnabled: Bool {
        get { ConfigurableKit.value(forKey: Self.controlObject.key) ?? true }
        set { ConfigurableKit.set(value: newValue, forKey: Self.controlObject.key) }
    }

    nonisolated func execute(with input: String, anchorTo _: UIView) async throws -> String {
        _ = input
        throw NSError()
    }

    nonisolated func executeWithAttachments(
        with input: String,
        anchorTo view: UIView
    ) async throws -> ModelToolExecutionResult {
        // 默认实现：调用旧方法保持向后兼容
        let text = try await execute(with: input, anchorTo: view)
        return ModelToolExecutionResult(text: text)
    }
}
