import Foundation

extension InlineNode {
    func renderAttributedString(
        baseURL: URL?,
        textStyles: InlineTextStyles,
        softBreakMode: SoftBreak.Mode,
        attributes: AttributeContainer
    ) -> AttributedString {
        var renderer = AttributedStringInlineRenderer(
            baseURL: baseURL,
            textStyles: textStyles,
            softBreakMode: softBreakMode,
            attributes: attributes
        )
        renderer.render(self)
        return renderer.result.resolvingFonts()
    }
}

private struct AttributedStringInlineRenderer {
    var result = AttributedString()

    private let baseURL: URL?
    private let textStyles: InlineTextStyles
    private let softBreakMode: SoftBreak.Mode
    private var attributes: AttributeContainer
    private var shouldSkipNextWhitespace = false

    init(
        baseURL: URL?,
        textStyles: InlineTextStyles,
        softBreakMode: SoftBreak.Mode,
        attributes: AttributeContainer
    ) {
        self.baseURL = baseURL
        self.textStyles = textStyles
        self.softBreakMode = softBreakMode
        self.attributes = attributes
    }

    mutating func render(_ inline: InlineNode) {
        switch inline {
        case let .text(content):
            renderText(content)
        case .softBreak:
            renderSoftBreak()
        case .lineBreak:
            renderLineBreak()
        case let .code(content):
            renderCode(content)
        case let .html(content):
            renderHTML(content)
        case let .emphasis(children):
            renderEmphasis(children: children)
        case let .strong(children):
            renderStrong(children: children)
        case let .strikethrough(children):
            renderStrikethrough(children: children)
        case let .link(destination, children):
            renderLink(destination: destination, children: children)
        case let .image(source, children):
            renderImage(source: source, children: children)
        }
    }

    private mutating func renderText(_ text: String) {
        var text = text

        if shouldSkipNextWhitespace {
            shouldSkipNextWhitespace = false
            text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
        }

        result += .init(text, attributes: attributes)
    }

    private mutating func renderSoftBreak() {
        switch softBreakMode {
        case .space where shouldSkipNextWhitespace:
            shouldSkipNextWhitespace = false
        case .space:
            result += .init(" ", attributes: attributes)
        case .lineBreak:
            renderLineBreak()
        }
    }

    private mutating func renderLineBreak() {
        result += .init("\n", attributes: attributes)
    }

    private mutating func renderCode(_ code: String) {
        result += .init(code, attributes: textStyles.code.mergingAttributes(attributes))
    }

    private mutating func renderHTML(_ html: String) {
        let tag = HTMLTag(html)

        switch tag?.name.lowercased() {
        case "br":
            renderLineBreak()
            shouldSkipNextWhitespace = true
        default:
            renderText(html)
        }
    }

    private mutating func renderEmphasis(children: [InlineNode]) {
        let savedAttributes = attributes
        attributes = textStyles.emphasis.mergingAttributes(attributes)

        for child in children {
            render(child)
        }

        attributes = savedAttributes
    }

    private mutating func renderStrong(children: [InlineNode]) {
        let savedAttributes = attributes
        attributes = textStyles.strong.mergingAttributes(attributes)

        for child in children {
            render(child)
        }

        attributes = savedAttributes
    }

    private mutating func renderStrikethrough(children: [InlineNode]) {
        let savedAttributes = attributes
        attributes = textStyles.strikethrough.mergingAttributes(attributes)

        for child in children {
            render(child)
        }

        attributes = savedAttributes
    }

    private mutating func renderLink(destination: String, children: [InlineNode]) {
        let savedAttributes = attributes
        attributes = textStyles.link.mergingAttributes(attributes)
        attributes.link = URL(string: destination, relativeTo: baseURL)

        for child in children {
            render(child)
        }

        attributes = savedAttributes
    }

    private mutating func renderImage(source _: String, children _: [InlineNode]) {
        // AttributedString does not support images
    }
}

private extension TextStyle {
    func mergingAttributes(_ attributes: AttributeContainer) -> AttributeContainer {
        var newAttributes = attributes
        _collectAttributes(in: &newAttributes)
        return newAttributes
    }
}
