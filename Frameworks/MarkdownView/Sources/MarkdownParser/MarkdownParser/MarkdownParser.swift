//
//  MarkdownParser.swift
//  FlowMarkdownView
//
//  Created by 秋星桥 on 2025/1/2.
//

import cmark_gfm
import cmark_gfm_extensions
import Foundation
import MarkdownNode

public class MarkdownParser {
    public init() {}

    func withOnetimeDisposableParser<T>(parserBlock: (UnsafeMutablePointer<cmark_parser>) -> T) -> T {
        let parser = cmark_parser_new(CMARK_OPT_DEFAULT)!
        setupExtensions(parser: parser)
        defer { cmark_parser_free(parser) }
        return parserBlock(parser)
    }

    public func feed(_ text: String) -> [MarkdownBlockNode] {
        withOnetimeDisposableParser { parser in
            cmark_parser_feed(parser, text, text.utf8.count)
            let node = cmark_parser_finish(parser)
            defer { cmark_node_free(node) }
            return dumpBlocks(root: node)
        }
    }
}
