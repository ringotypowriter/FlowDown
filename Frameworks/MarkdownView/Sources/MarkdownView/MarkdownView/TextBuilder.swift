//
//  Created by ktiays on 2025/1/20.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import CoreText
import Litext
import MarkdownNode
import MarkdownParser
import UIKit

final class TextBuilder {
    typealias DrawingCallback = (CGContext, CTLine, CGPoint) -> Void

    typealias BulletDrawingCallback = (CGContext, CTLine, CGPoint, Int) -> Void
    typealias NumberedDrawingCallback = (CGContext, CTLine, CGPoint, Int) -> Void
    typealias CheckboxDrawingCallback = (CGContext, CTLine, CGPoint, Bool) -> Void

    private let nodes: [MarkdownBlockNode]
    private let viewProvider: DrawingViewProvider
    private var theme: MarkdownTheme
    private let text: NSMutableAttributedString = .init()

    private var bulletDrawing: BulletDrawingCallback?
    private var numberedDrawing: NumberedDrawingCallback?
    private var checkboxDrawing: CheckboxDrawingCallback?
    private var thematicBreakDrawing: DrawingCallback?
    private var codeDrawing: DrawingCallback?
    private var tableDrawing: DrawingCallback?

    var listIndent: CGFloat = 20

    init(nodes: [MarkdownBlockNode], viewProvider: DrawingViewProvider) {
        self.nodes = nodes
        self.viewProvider = viewProvider
        theme = .default
    }

    func withTheme(_ theme: MarkdownTheme) -> TextBuilder {
        self.theme = theme
        return self
    }

    func withBulletDrawing(_ drawing: @escaping BulletDrawingCallback) -> TextBuilder {
        bulletDrawing = drawing
        return self
    }

    func withNumberedDrawing(_ drawing: @escaping NumberedDrawingCallback) -> TextBuilder {
        numberedDrawing = drawing
        return self
    }

    func withCheckboxDrawing(_ drawing: @escaping CheckboxDrawingCallback) -> TextBuilder {
        checkboxDrawing = drawing
        return self
    }

    func withThematicBreakDrawing(_ drawing: @escaping DrawingCallback) -> TextBuilder {
        thematicBreakDrawing = drawing
        return self
    }

    func withCodeDrawing(_ drawing: @escaping DrawingCallback) -> TextBuilder {
        codeDrawing = drawing
        return self
    }

    func withTableDrawing(_ drawing: @escaping DrawingCallback) -> TextBuilder {
        tableDrawing = drawing
        return self
    }

    func build() -> NSAttributedString {
        for node in nodes {
            text.append(processBlock(node))
        }
        return text
    }
}

struct RenderText {
    let attributedString: NSAttributedString
    let fullWidthAttachments: [LTXAttachment]
}

extension TextBuilder {
    private func withParagraph(
        modifier: (NSMutableParagraphStyle) -> Void = { _ in },
        content: () -> NSMutableAttributedString
    ) -> NSMutableAttributedString {
        let paragraphStyle: NSMutableParagraphStyle = .init()
        paragraphStyle.paragraphSpacing = 16
        paragraphStyle.lineSpacing = 4
        modifier(paragraphStyle)

        let string = content()
        string.addAttributes(
            [.paragraphStyle: paragraphStyle],
            range: .init(location: 0, length: string.length)
        )
        string.append(.init(string: "\n"))
        return string
    }

    private func processBlock(_ node: MarkdownBlockNode) -> NSAttributedString {
        switch node {
        case let .heading(level, contents):
            processHeading(level: level, contents: contents)
        case let .paragraph(contents):
            processParagraph(contents: contents)
        case let .bulletedList(_, items):
            processBulletedList(items: items)
        case let .numberedList(_, index, items):
            processNumberedList(startAt: index, items: items)
        case let .taskList(_, items):
            processTaskList(items: items)
        case .thematicBreak:
            processThematicBreak()
        case let .codeBlock(language, content):
            processCodeBlock(language: language, content: content)
        case let .blockquote(children):
            processBlockquote(children)
        case let .table(_, rows):
            processTable(rows: rows)
        }
    }

    private func processHeading(level: Int, contents: [MarkdownInlineNode]) -> NSAttributedString {
        let string = contents.render(theme: theme)
        var supposedFont: UIFont = theme.fonts.title
        if level <= 1 {
            supposedFont = theme.fonts.largeTitle
        }
        string.addAttributes(
            [
                .font: supposedFont,
                .foregroundColor: theme.colors.body,
            ],
            range: .init(location: 0, length: string.length)
        )
        return withParagraph {
            string
        }
    }

    private func processParagraph(contents: [MarkdownInlineNode]) -> NSAttributedString {
        withParagraph {
            contents.render(theme: theme)
        }
    }

    private func processThematicBreak() -> NSAttributedString {
        withParagraph {
            let drawingCallback = self.thematicBreakDrawing
            return .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: .init(string: "\n\n")),
                .ltxLineDrawingCallback: LTXLineDrawingAction(action: { context, line, lineOrigin in
                    drawingCallback?(context, line, lineOrigin)
                }),
            ])
        }
    }

    private func processCodeBlock(language: String?, content: String) -> NSAttributedString {
        withParagraph { paragraph in
            let height = CodeView.intrinsicHeight(for: content, theme: theme)
            paragraph.minimumLineHeight = height
        } content: {
            let codeView = viewProvider.acquireCodeView()
            let theme = theme
            let ignoreSet = viewProvider.ignoresCharacterSetSuffixForCodeHighlighting
            var lang = language ?? "plaintext"
            if lang.isEmpty { lang = "plaintext" }
            let content = content.trimmingCharacters(in: .whitespacesAndNewlines)

            codeView.ignoresCharacterSetSuffixForHighlighting = ignoreSet
            codeView.theme = theme
            codeView.content = content
            codeView.language = lang

            let codeDrawing = self.codeDrawing
            return .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: .init(string: content + "\n")),
                .ltxLineDrawingCallback: LTXLineDrawingAction(action: { context, line, lineOrigin in
                    // avoid data conflict on racing conditions
                    // TODO: FIND THE ROOT CASE
                    codeView.ignoresCharacterSetSuffixForHighlighting = ignoreSet
                    codeView.theme = theme
                    codeView.content = content
                    codeView.language = lang
                    codeDrawing?(context, line, lineOrigin)
                }),
                .contextView: codeView,
            ])
        }
    }

    private func processBlockquote(_ children: [MarkdownBlockNode]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in children {
            result.append(processBlock(child))
        }
        return result
    }

    private func processTable(rows: [RawTableRow]) -> NSAttributedString {
        let tableView = viewProvider.acquireTableView()
        let contents = rows.map {
            $0.cells.map { rawCell in
                rawCell.content.render(theme: theme)
            }
        }
        tableView.contents = contents
        return withParagraph { paragraph in
            paragraph.minimumLineHeight = tableView.intrinsicContentHeight
        } content: {
            let drawingCallback = self.tableDrawing
            return .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: .init(string: contents.map {
                    $0.map(\.string).joined(separator: "\t")
                }.joined(separator: "\n") + "\n")),
                .ltxLineDrawingCallback: LTXLineDrawingAction(action: { context, line, lineOrigin in
                    // avoid data conflict on racing conditions
                    // TODO: FIND THE ROOT CASE
                    tableView.contents = contents
                    drawingCallback?(context, line, lineOrigin)
                }),
                .contextView: tableView,
            ])
        }
    }
}

extension TextBuilder {
    private func processBulletedList(items: [RawListItem]) -> NSAttributedString {
        let items = flatList(.bulleted(items), currentDepth: 0)
        return renderListItems(items)
    }

    private func processNumberedList(startAt index: Int, items: [RawListItem]) -> NSAttributedString {
        let items = flatList(.numbered(index, items), currentDepth: 0)
        return renderListItems(items)
    }

    private func processTaskList(items: [RawTaskListItem]) -> NSAttributedString {
        let items = flatList(.task(items), currentDepth: 0)
        return renderListItems(items)
    }

    private func renderListItem(_ item: ListItem, reduceLineSpacing: Bool = false) -> NSAttributedString {
        withParagraph { paragraphStyle in
            if reduceLineSpacing {
                paragraphStyle.paragraphSpacing = 8
            }
            let indent = CGFloat(item.depth + 1) * listIndent
            paragraphStyle.firstLineHeadIndent = indent
            paragraphStyle.headIndent = indent
        } content: {
            let bulletDrawing = self.bulletDrawing
            let numberedDrawing = self.numberedDrawing
            let checkboxDrawing = self.checkboxDrawing
            let string = NSMutableAttributedString()
            string.append(.init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxLineDrawingCallback: LTXLineDrawingAction(action: { context, line, lineOrigin in
                    if item.ordered {
                        numberedDrawing?(context, line, lineOrigin, item.index)
                    } else if item.isTask {
                        checkboxDrawing?(context, line, lineOrigin, item.isDone)
                    } else {
                        bulletDrawing?(context, line, lineOrigin, item.depth)
                    }
                }),
            ]))
            string.append(item.paragraph.render(theme: theme))
            return string
        }
    }

    private func renderListItems(_ items: [ListItem]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, item) in items.enumerated() {
            let rendered = renderListItem(item, reduceLineSpacing: index != items.count - 1)
            result.append(rendered)
        }
        return result
    }
}

extension TextBuilder {
    private enum List {
        case bulleted([RawListItem])
        case numbered(Int, [RawListItem])
        case task([RawTaskListItem])
    }

    private struct ListItem {
        let depth: Int
        let ordered: Bool
        let index: Int
        let isTask: Bool
        let isDone: Bool
        let paragraph: [MarkdownInlineNode]

        init(depth: Int, ordered: Bool, index: Int = 0, isTask: Bool = false, isDone: Bool = false, paragraph: [MarkdownInlineNode]) {
            self.depth = depth
            self.ordered = ordered
            self.index = index
            self.isTask = isTask
            self.isDone = isDone
            self.paragraph = paragraph
        }
    }

    private func flatList(_ list: List, currentDepth: Int) -> [ListItem] {
        var result: [ListItem] = []
        var index = 0
        var isOrdered = false

        struct MappedItem {
            let isDone: Bool?
            let nodes: [MarkdownBlockNode]
        }

        func handle(_ items: [MappedItem]) {
            for item in items {
                for child in item.nodes {
                    switch child {
                    case let .paragraph(contents):
                        let isTask = item.isDone != nil
                        let isDone = item.isDone ?? false
                        result.append(.init(depth: currentDepth, ordered: isOrdered, index: index, isTask: isTask, isDone: isDone, paragraph: contents))
                        index += 1
                    case let .bulletedList(_, sublist):
                        result.append(contentsOf: flatList(.bulleted(sublist), currentDepth: currentDepth + 1))
                    case let .numberedList(_, start, sublist):
                        result.append(contentsOf: flatList(.numbered(start, sublist), currentDepth: currentDepth + 1))
                    case let .taskList(_, sublist):
                        result.append(contentsOf: flatList(.task(sublist), currentDepth: currentDepth + 1))
                    default:
                        print("WARNING: Unhandled list item: \(child)")
                    }
                }
            }
        }

        switch list {
        case let .bulleted(items):
            let mapped: [MappedItem] = items.map {
                .init(isDone: nil, nodes: $0.children)
            }
            isOrdered = false
            handle(mapped)
        case let .numbered(startAt, items):
            let mapped: [MappedItem] = items.map {
                .init(isDone: nil, nodes: $0.children)
            }
            isOrdered = true
            index = startAt
            handle(mapped)
        case let .task(items):
            let mapped: [MappedItem] = items.map {
                .init(isDone: $0.isCompleted, nodes: $0.children)
            }
            isOrdered = false
            handle(mapped)
        }

        return result
    }
}
