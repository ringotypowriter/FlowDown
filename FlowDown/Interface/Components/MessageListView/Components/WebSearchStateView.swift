//
//  Created by ktiays on 2025/2/19.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import GlyphixTextFx
import ScrubberKit
import Storage
import UIKit

final class WebSearchStateView: MessageListRowView {
    private let searchIndicatorView: SearchIndicatorView = .init()
    private var results: [Message.WebSearchStatus.SearchResult] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(searchIndicatorView)

        searchIndicatorView.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        searchIndicatorView.addGestureRecognizer(gesture)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let indicatorSize = searchIndicatorView.intrinsicContentSize
        searchIndicatorView.frame = CGRect(
            x: 0,
            y: 0,
            width: min(indicatorSize.width, contentView.bounds.width),
            height: contentView.bounds.height
        )
    }

    @available(*, unavailable)
    @MainActor required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func intrinsicHeight(withLabelFont labelFont: UIFont) -> CGFloat {
        SearchIndicatorView.intrinsicHeight(withLabelFont: labelFont)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        results = []
    }

    func update(with phase: Message.WebSearchStatus) {
        if phase != searchIndicatorView.phase {
            searchIndicatorView.phase = phase
        }
        results = phase.searchResults
    }

    override func themeDidUpdate() {
        super.themeDidUpdate()
        searchIndicatorView.textLabel.font = theme.fonts.body
    }

    @objc func didTap() {
        guard !results.isEmpty else { return }
        let menu = UIMenu(title: String(localized: "Search Results"), children: results.map { result in
            UIMenu(title: result.title, children: [
                UIAction(
                    title: String(localized: "View"),
                    image: UIImage(systemName: "eye")
                ) { [weak self] _ in
                    Indicator.present(result.url, referencedView: self)
                },
                UIMenu(title: String(localized: "Share") + " " + (result.url.host ?? ""), options: [.displayInline], children: [
                    UIAction(title: String(localized: "Share"), image: UIImage(systemName: "safari")) { [weak self] _ in
                        guard let self else { return }
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("txt")
                        try? result.url.absoluteString.write(to: tempURL, atomically: true, encoding: .utf8)
                        DisposableExporter(
                            item: tempURL
                        ).run(anchor: self)
                    },
                    UIAction(
                        title: String(localized: "Open in Default Browser"),
                        image: UIImage(systemName: "safari")
                    ) { [weak self] _ in
                        guard let self else { return }
                        Indicator.open(result.url, referencedView: self)
                    },
                ]),
            ])
        })
        searchIndicatorView.present(menu: menu, anchorPoint: .init(
            x: searchIndicatorView.frame.midX,
            y: searchIndicatorView.frame.maxY + 16
        ))
    }
}

extension WebSearchStateView {
    private final class SearchIndicatorView: UIView {
        static let spacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let barHeight: CGFloat = 2

        var phase: Message.WebSearchStatus = .init() {
            didSet { update(with: phase) }
        }

        var progressFraction: CGFloat = 0 {
            didSet { layoutProgressWithAnimationIfNeeded(oldValue: oldValue) }
        }

        let textLabel: GlyphixTextLabel = .init().with {
            $0.isBlurEffectEnabled = false
        }

        private var magnifyImageView: UIImageView!
        private let progressBar: UIView = .init()

        override init(frame: CGRect) {
            super.init(frame: frame)

            clipsToBounds = true
            backgroundColor = .secondarySystemFill.withAlphaComponent(0.08)
            layer.cornerRadius = 14
            layer.cornerCurve = .continuous

            let imageConfiguration = UIImage.SymbolConfiguration(scale: .small)
            let magnifyImageView = UIImageView(
                image: .init(
                    systemName: "rectangle.and.text.magnifyingglass",
                    withConfiguration: imageConfiguration
                )
            )
            magnifyImageView.tintColor = .label
            self.magnifyImageView = magnifyImageView
            addSubview(magnifyImageView)

            textLabel.countsDown = false
            textLabel.textAlignment = .leading
            addSubview(textLabel)

            progressBar.isHidden = true
            progressBar.backgroundColor = .accent
            progressBar.layer.cornerRadius = 1
            addSubview(progressBar)

            progressBar.alpha = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.doWithAnimation {
                    self.progressBar.alpha = 1
                }
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            let imageSize = magnifyImageView.intrinsicContentSize
            magnifyImageView.frame = CGRect(
                x: Self.horizontalPadding,
                y: (bounds.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )

            let textX = magnifyImageView.frame.maxX + Self.spacing
            textLabel.frame = CGRect(
                x: textX,
                y: 0,
                width: bounds.width - textX - Self.horizontalPadding,
                height: bounds.height
            )

            updateProgressBarFrame()
        }

        func updateProgressBarFrame() {
            progressBar.frame = .init(
                x: 0,
                y: bounds.height - Self.barHeight,
                width: bounds.width * progressFraction,
                height: Self.barHeight
            )
        }

        func layoutProgressWithAnimationIfNeeded(oldValue _: CGFloat) {
            if progressFraction == 0 || progressBar.isHidden {
                updateProgressBarFrame()
                return
            }
            doWithAnimation {
                self.updateProgressBarFrame()
            }
        }

        static func intrinsicHeight(withLabelFont labelFont: UIFont) -> CGFloat {
            2 * verticalPadding + labelFont.lineHeight
        }

        override var intrinsicContentSize: CGSize {
            let imageSize = magnifyImageView.intrinsicContentSize
            let textSize = textLabel.intrinsicContentSize
            let width = Self.horizontalPadding + imageSize.width + Self.spacing + textSize.width + Self.horizontalPadding
            let height = 2 * Self.verticalPadding + (textLabel.font?.pointSize ?? 0)
            return CGSize(width: width, height: height)
        }

        func update(with phase: Message.WebSearchStatus) {
            setNeedsLayout()
            invalidateIntrinsicContentSize()

            let keyword: String? = phase.queries[safe: phase.currentQuery]
            let numberOfResults = phase.numberOfResults
            let numberOfWebsites = phase.numberOfWebsites
            progressBar.isHidden = numberOfResults > 0

            let text = if phase.proccessProgress < 0 {
                String(localized: "Failed to search")
            } else if numberOfResults > 0 {
                String(localized: "Browsed \(numberOfResults) website(s)")
            } else if phase.proccessProgress > 0, numberOfWebsites > 0 {
                String(localized: "Searched \(numberOfWebsites) website(s), fetching them") + "..."
            } else if let keyword {
                String(localized: "Browsing \(keyword)") + "..."
            } else {
                String(localized: "Determining search keywords") + "..."
            }

            textLabel.text = text

            if phase.proccessProgress > 0 || progressFraction < 1 {
                doWithAnimation {
                    self.progressFraction = phase.proccessProgress
                }
            } else {
                progressFraction = phase.proccessProgress
            }
        }
    }
}
