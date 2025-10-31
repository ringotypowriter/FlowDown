//
//  JsonEditorController.swift
//  FlowDown
//
//  Created by Willow Zhang on 10/31/25.
//

import AlertController
import UIKit

class JsonEditorController: CodeEditorController {
    init(text: String) {
        super.init(language: "json", text: text)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func done() {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = "{}"
            super.done()
            return
        }
        guard let data = textView.text.data(using: .utf8) else {
            let alert = AlertViewController(
                title: "Error",
                message: "Unable to decode text into data."
            ) { context in
                context.addAction(title: "OK", attribute: .accent) {
                    context.dispose()
                }
            }
            present(alert, animated: true)
            return
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            // Ensure it's a dictionary (JSON object)
            guard object is [String: Any] else {
                throw NSError(
                    domain: "JSONValidation",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "JSON must be an object (dictionary), not an array or primitive.")]
                )
            }
            Logger.ui.infoFile("JsonEditorController done with valid JSON object")
        } catch {
            let alert = AlertViewController(
                title: "Error",
                message: "Unable to parse JSON: \(error.localizedDescription)"
            ) { context in
                context.addAction(title: "OK", attribute: .accent) {
                    context.dispose()
                }
            }
            present(alert, animated: true)
            return
        }
        super.done()
    }
}
