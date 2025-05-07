import Foundation

extension Sequence<InlineNode> {
    func renderPlainText() -> String {
        collect { inline in
            switch inline {
            case let .text(content):
                [content]
            case .softBreak:
                [" "]
            case .lineBreak:
                ["\n"]
            case let .code(content):
                [content]
            case let .html(content):
                [content]
            default:
                []
            }
        }
        .joined()
    }
}
