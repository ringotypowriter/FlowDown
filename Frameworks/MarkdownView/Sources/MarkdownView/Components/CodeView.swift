//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext
import Splash
import UIKit

final class CodeView: UIView {
    var theme: MarkdownTheme = .default {
        didSet {
            languageLabel.font = theme.fonts.code
            let codeTheme = theme.codeTheme(withFont: theme.fonts.code)
            syntaxFormat = .init(theme: codeTheme)
        }
    }

    var language: String = "" {
        didSet {
            languageLabel.text = language
        }
    }

    /// A character set that will be ignored when highlighting the code content.
    var ignoresCharacterSetSuffixForHighlighting: CharacterSet?

    var previewAction: ((String?, NSAttributedString) -> Void)?

    private var _content: String?
    var content: String? {
        set {
            if _content != newValue {
                var oldValue = _content
                _content = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)

                var taskContent = _content
                if let characterSet = ignoresCharacterSetSuffixForHighlighting {
                    // Removes the suffix characters that should be ignored.
                    oldValue = oldValue?.trimmingCharacters(in: characterSet.union(.whitespacesAndNewlines))
                    taskContent = taskContent?.trimmingCharacters(in: characterSet.union(.whitespacesAndNewlines))
                }

                if let oldValue, !oldValue.isEmpty, taskContent?.contains(oldValue) == true {
                    // Incremental modification, delay the highlight task.
                    // Since the highlight task cannot be canceled and it takes a long time to complete,
                    // for highlight tasks triggered by incremental code changes, delay their execution by a certain amount of time.
                    // If the task version has changed after the delay, cancel the current task directly.
                    highlightTaskDelays = 0.1
                } else {
                    highlightTaskDelays = 0
                    // Non-incremental modification, clear historical highlight results.
                    calculatedAttributes.removeAll()
                }
                updateHighlightedContent()
                calculateHighlight(with: taskContent)
            }
        }
        get { _content }
    }

    private var calculatedAttributes: [NSRange: UIColor] = [:]

    private var syntaxFormat: AttributedStringOutputFormat?

    private lazy var barView: UIView = .init()
    private lazy var scrollView: UIScrollView = .init()
    private lazy var languageLabel: UILabel = .init()
    private lazy var textView: LTXLabel = .init()
    private lazy var copyButton: UIButton = .init()
    private lazy var previewButton: UIButton = .init()

    private static let barPadding: CGFloat = 8
    private static let codePadding: CGFloat = 8
    private static let codeLineSpacing: CGFloat = 6

    private lazy var highlightQueue: DispatchQueue = .global(qos: .background)
    private var highlightTaskVersion: Int64 = 0
    private var highlightTaskDelays: TimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func intrinsicHeight(for content: String?, theme: MarkdownTheme = .default) -> CGFloat {
        let font = theme.fonts.code
        let lineHeight = font.lineHeight
        let barHeight = lineHeight + barPadding * 2
        let numberOfRows = content?.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).count ?? 0
        let codeHeight = lineHeight * CGFloat(numberOfRows)
            + codePadding * 2
            + codeLineSpacing * CGFloat(max(numberOfRows - 1, 0))
        return ceil(barHeight + codeHeight)
    }

    private func configureSubviews() {
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        clipsToBounds = true
        backgroundColor = .gray.withAlphaComponent(0.05)

        barView.backgroundColor = .gray.withAlphaComponent(0.05)
        addSubview(barView)
        barView.addSubview(languageLabel)

        let previewImage = UIImage(systemName: "eye", withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        previewButton.setImage(previewImage, for: .normal)
        previewButton.addTarget(self, action: #selector(handlePreview(_:)), for: .touchUpInside)
        barView.addSubview(previewButton)

        previewButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewButton.centerYAnchor.constraint(equalTo: barView.centerYAnchor),
            previewButton.trailingAnchor.constraint(equalTo: barView.trailingAnchor, constant: -Self.barPadding),
        ])

        let copyImage = UIImage(systemName: "doc.on.doc", withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        copyButton.setImage(copyImage, for: .normal)
        copyButton.addTarget(self, action: #selector(handleCopy(_:)), for: .touchUpInside)
        barView.addSubview(copyButton)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copyButton.centerYAnchor.constraint(equalTo: barView.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: previewButton.leadingAnchor, constant: -12),
        ])

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        addSubview(scrollView)

        textView.backgroundColor = .clear
        textView.preferredMaxLayoutWidth = .infinity
        textView.isSelectable = true
        scrollView.addSubview(textView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labelSize = languageLabel.intrinsicContentSize
        let barHeight = max(languageLabel.font.lineHeight, labelSize.height) + Self.barPadding * 2
        barView.frame = .init(origin: .zero, size: .init(width: bounds.width, height: barHeight))
        languageLabel.frame = .init(origin: .init(x: Self.barPadding, y: Self.barPadding), size: labelSize)

        let textContentSize = textView.intrinsicContentSize
        scrollView.frame = .init(
            x: 0,
            y: barHeight,
            width: bounds.width,
            height: bounds.height - barHeight
        )
        textView.frame = .init(
            x: Self.codePadding,
            y: Self.codePadding,
            width: textContentSize.width,
            height: textContentSize.height
        )
        scrollView.contentSize = .init(
            width: textContentSize.width + Self.codePadding * 2,
            height: 0 // disable vertical scrolling to fix rarer bug
        )
    }

    override var intrinsicContentSize: CGSize {
        let labelSize = languageLabel.intrinsicContentSize
        let barHeight = labelSize.height + Self.barPadding * 2
        let textSize = textView.intrinsicContentSize
        // TODO: FIND WHY THE HEIGHT IS NOT CALCULATED CORRECT
        let supposeToHaveHeight = Self.intrinsicHeight(for: content, theme: theme)
        return .init(
            width: max(labelSize.width + Self.barPadding * 2, textSize.width + Self.codePadding * 2),
            height: max(barHeight + textSize.height + Self.codePadding * 2, supposeToHaveHeight)
        )
    }

    @objc
    private func handleCopy(_: UIButton) {
        UIPasteboard.general.string = content
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @objc
    private func handlePreview(_: UIButton) {
        previewAction?(language, textView.attributedText)
    }

    private func calculateHighlight(with code: String?) {
        highlightTaskVersion += 1
        let taskVersion = highlightTaskVersion
        highlightQueue.async { [weak self] in
            guard let code, !code.isEmpty, let format = self?.syntaxFormat else {
                return
            }

            if let delays = self?.highlightTaskDelays, delays > 0 {
                Thread.sleep(forTimeInterval: delays)
                if taskVersion != self?.highlightTaskVersion {
                    // The task is outdated.
                    return
                }
            }

            let result: NSMutableAttributedString?
            switch self?.language.lowercased() {
            case "swift":
                let splash = SyntaxHighlighter(format: format, grammar: SwiftGrammar())
                result = splash.highlight(code).mutableCopy() as? NSMutableAttributedString
            default:
                let splash = SyntaxHighlighter(format: format)
                result = splash.highlight(code).mutableCopy() as? NSMutableAttributedString
            }
            guard let result else {
                return
            }
            var attributes: [NSRange: UIColor] = [:]
            let nsResult = result.string as NSString
            result.enumerateAttribute(.foregroundColor, in: .init(location: 0, length: result.length)) { value, range, _ in
                if range.length == 1 {
                    if let char = nsResult.substring(with: range).first {
                        if char.isWhitespace {
                            return
                        }
                    }
                }
                guard let color = value as? UIColor else {
                    return
                }

                attributes[range] = color
            }

            if taskVersion != self?.highlightTaskVersion {
                // The task is outdated.
                return
            }

            DispatchQueue.main.async { [weak self] in
                if attributes.count > self?.calculatedAttributes.count ?? 0 {
                    self?.calculatedAttributes = attributes
                    self?.updateHighlightedContent()
                }
            }
        }
    }

    private func updateHighlightedContent() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = Self.codeLineSpacing

        guard let content = _content else {
            textView.attributedText = .init()
            return
        }

        let plainTextColor = theme.colors.code
        let attributedContent: NSMutableAttributedString = .init(
            string: content,
            attributes: [
                .font: theme.fonts.code,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: plainTextColor,
            ]
        )
        let length = attributedContent.length
        for attribute in calculatedAttributes {
            if attribute.key.upperBound >= length || attribute.value == plainTextColor {
                continue
            }
            let part = attributedContent.attributedSubstring(from: attribute.key).string
            if part.allSatisfy(\.isWhitespace) {
                continue
            }
            attributedContent.addAttributes([
                .foregroundColor: attribute.value,
            ], range: attribute.key)
        }
        textView.attributedText = attributedContent
    }
}

extension CodeView: LTXAttributeStringRepresentable {
    func attributedStringRepresentation() -> NSAttributedString {
        textView.attributedText
    }
}
