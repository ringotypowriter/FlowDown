//
//  Value+MarkdownTheme.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/26/25.
//

import Combine
import ConfigurableKit
import Foundation
import MarkdownView

extension MarkdownTheme.FontScale {
    var title: String {
        switch self {
        case .tiny: NSLocalizedString("Tiny", comment: "Font Size")
        case .small: NSLocalizedString("Small", comment: "Font Size")
        case .middle: NSLocalizedString("Middle", comment: "Font Size")
        case .large: NSLocalizedString("Large", comment: "Font Size")
        case .huge: NSLocalizedString("Huge", comment: "Font Size")
        }
    }
}

extension MarkdownTheme {
    static let storageKey = "app.appearance.MarkdownTheme.font.scale"
    private static var cancellables: Set<AnyCancellable> = []

    static let fontScaleDidChange = PassthroughSubject<Void, Never>()

    static let configurableObject: ConfigurableObject = .init(
        icon: "wand.and.rays",
        title: String(localized: "Font Size"),
        explain: String(localized: "Adjust the font size of the markdown content."),
        key: storageKey,
        defaultValue: MarkdownTheme.FontScale.middle.rawValue,
        annotation: .list {
            MarkdownTheme.FontScale.allCases.map { input in
                ListAnnotation.ValueItem(
                    icon: "circle",
                    title: input.title,
                    rawValue: input.rawValue
                )
            }
        }
    )

    static func subscribeToConfigurableItem() {
        assert(cancellables.isEmpty)
        ConfigurableKit.publisher(forKey: storageKey, type: String.self)
            .sink { input in
                guard let input,
                      let scale = MarkdownTheme.FontScale(rawValue: input)
                else { return }
                Logger.ui.debugFile("applying font scale to markdown fonts: \(scale)")
                MarkdownTheme.default.scaleFont(by: scale)
                fontScaleDidChange.send(())
            }
            .store(in: &cancellables)
    }
}
