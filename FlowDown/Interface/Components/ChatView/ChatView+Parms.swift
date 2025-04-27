//
//  ChatView+Parms.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/2/25.
//

import ConfigurableKit
import Foundation

extension ChatView {
    enum EditorModelNameStyle: String, CaseIterable, Codable {
        case full
        case trimmed
        case none

        var icon: String {
            switch self {
            case .full: "text.quote"
            case .trimmed: "text.alignleft"
            case .none: "minus"
            }
        }

        var title: String {
            switch self {
            case .full: String(localized: "Unique Model Name")
            case .trimmed: String(localized: "Model Name Only")
            case .none: String(localized: "Do Not Display")
            }
        }
    }

    static let editorModelNameStyle: ConfigurableObject = .init(
        icon: "increase.quotelevel",
        title: String(localized: "Model Name Style"),
        explain: String(localized: "Show full model name and information in the quick setting bar under the input box or not."),
        key: "app.chat.model.picker.style",
        defaultValue: EditorModelNameStyle.trimmed.rawValue,
        annotation: ChidoriListAnnotation {
            EditorModelNameStyle.allCases.map {
                .init(
                    icon: $0.icon,
                    title: $0.title,
                    rawValue: $0.rawValue
                )
            }
        }
    )

    static let editorApplyModelToDefault: ConfigurableObject = .init(
        icon: "checkmark.seal",
        title: String(localized: "Select as Default"),
        explain: String(localized: "When selecting a new chat model, also set it as the default model."),
        key: "app.chat.model.picker.apply.to.default",
        defaultValue: true,
        annotation: .boolean
    )
}
