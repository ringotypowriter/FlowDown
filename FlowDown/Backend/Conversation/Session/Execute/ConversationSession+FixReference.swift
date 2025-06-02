//
//  ConversationSession+FixReference.swift
//  FlowDown
//
//  Created by 秋星桥 on 3/19/25.
//

import ChatClientKit
import Foundation
import RegexBuilder
import Storage

extension ConversationSession {
    func fixWebReferenceIfPossible(
        in content: String,
        with contentLink: [Int: String],
    ) -> String {
        if content.isEmpty || contentLink.isEmpty { return content }

        var content = content

        let numberWithOptionalHat = Regex {
            ZeroOrMore(.whitespace)
            Optionally("^")
            OneOrMore(.digit)
            ZeroOrMore(.whitespace)
        }
        let regex = Regex {
            "["

            Capture {
                numberWithOptionalHat
                ZeroOrMore {
                    ","
                    numberWithOptionalHat
                }
            }

            "]"

            NegativeLookahead {
                "("
                ZeroOrMore(.any)
                ")"
            }

            Anchor.wordBoundary
        }

        let matches = content.matches(of: regex)
        var replaceMap: [Range<String.Index>: String] = [:]
        for match in matches {
            let source = match.output.1
                .replacingOccurrences(of: "^", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let numbers = source.components(separatedBy: ",").compactMap { Int($0) }
            var replacedLink: [String] = []
            for number in numbers where contentLink.keys.contains(number) {
                guard let result = contentLink[number] else { continue }
                replacedLink.append("[^\(number)](\(result))")
            }

            if replacedLink.isEmpty {
                // No valid reference found, removing this section.
                replaceMap[match.range] = ""
            } else {
                replaceMap[match.range] = replacedLink.joined(separator: " ")
            }
        }

        replaceMap
            .sorted { $0.key.lowerBound > $1.key.lowerBound }
            .forEach { range, replacement in
                content.replaceSubrange(range, with: replacement)
            }

        return content
    }
}
