import SwiftUI

extension Sequence<InlineNode> {
    func renderText(
        baseURL: URL?,
        textStyles: InlineTextStyles,
        images: [String: Image],
        softBreakMode: SoftBreak.Mode,
        attributes: AttributeContainer
    ) -> Text {
        var renderer = TextInlineRenderer(
            baseURL: baseURL,
            textStyles: textStyles,
            images: images,
            softBreakMode: softBreakMode,
            attributes: attributes
        )
        renderer.render(self)
        return renderer.result
    }
}

private struct TextInlineRenderer {
    var result = Text("")

    private let baseURL: URL?
    private let textStyles: InlineTextStyles
    private let images: [String: Image]
    private let softBreakMode: SoftBreak.Mode
    private let attributes: AttributeContainer
    private var shouldSkipNextWhitespace = false

    init(
        baseURL: URL?,
        textStyles: InlineTextStyles,
        images: [String: Image],
        softBreakMode: SoftBreak.Mode,
        attributes: AttributeContainer
    ) {
        self.baseURL = baseURL
        self.textStyles = textStyles
        self.images = images
        self.softBreakMode = softBreakMode
        self.attributes = attributes
    }

    mutating func render(_ inlines: some Sequence<InlineNode>) {
        for inline in inlines {
            render(inline)
        }
    }

    private mutating func render(_ inline: InlineNode) {
        switch inline {
        case let .text(content):
            renderText(content)
        case .softBreak:
            renderSoftBreak()
        case let .html(content):
            renderHTML(content)
        case let .image(source, _):
            renderImage(source)
        default:
            defaultRender(inline)
        }
    }

    private mutating func renderText(_ text: String) {
        var text = text

        if shouldSkipNextWhitespace {
            shouldSkipNextWhitespace = false
            text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
        }

        defaultRender(.text(text))
    }

    private mutating func renderSoftBreak() {
        switch softBreakMode {
        case .space where shouldSkipNextWhitespace:
            shouldSkipNextWhitespace = false
        case .space:
            defaultRender(.softBreak)
        case .lineBreak:
            shouldSkipNextWhitespace = true
            defaultRender(.lineBreak)
        }
    }

    private mutating func renderHTML(_ html: String) {
        let tag = HTMLTag(html)

        switch tag?.name.lowercased() {
        case "br":
            defaultRender(.lineBreak)
            shouldSkipNextWhitespace = true
        default:
            defaultRender(.html(html))
        }
    }

    private mutating func renderImage(_ source: String) {
        if let image = images[source] {
            result = result + Text(image)
        }
    }

    private mutating func defaultRender(_ inline: InlineNode) {
        result =
            result
                + Text(
                    inline.renderAttributedString(
                        baseURL: baseURL,
                        textStyles: textStyles,
                        softBreakMode: softBreakMode,
                        attributes: attributes
                    )
                )
    }
}
