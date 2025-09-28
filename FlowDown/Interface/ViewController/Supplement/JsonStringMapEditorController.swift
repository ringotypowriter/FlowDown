//
//  JsonStringMapEditorController.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/30/25.
//

import AlertController
import UIKit

class JsonStringMapEditorController: CodeEditorController {
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
        let requiredDecodableType = [String: String].self
        guard let data = textView.text.data(using: .utf8) else {
            let alert = AlertViewController(
                title: String(localized: "Error"),
                message: String(localized: "Unable to decode text into data.")
            ) { context in
                context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                    context.dispose()
                }
            }
            present(alert, animated: true)
            return
        }
        do {
            let object = try JSONDecoder().decode(requiredDecodableType, from: data)
            print("[*] JsonStringMapEditorController: done with object: \(object)")
        } catch {
            let alert = AlertViewController(
                title: String(localized: "Error"),
                message: String(localized: "Unable to decode string key value map from text: \(error.localizedDescription)")
            ) { context in
                context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                    context.dispose()
                }
            }
            present(alert, animated: true)
            return
        }
        super.done()
    }
}
