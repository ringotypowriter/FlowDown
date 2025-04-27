//
//  Created by ktiays on 2025/2/19.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import GlyphixTextFx
import ScrubberKit
import SnapKit
import Storage
import UIKit

final class WebSearchStateView: MessageListRowView {
    private let searchIndicatorView: SearchIndicatorView = .init()
    private var results: [Message.WebSearchStatus.SearchResult] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(searchIndicatorView)
        searchIndicatorView.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }

        searchIndicatorView.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        searchIndicatorView.addGestureRecognizer(gesture)
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
                        let shareSheet = UIActivityViewController(activityItems: [result.url], applicationActivities: nil)
                        shareSheet.popoverPresentationController?.sourceView = self
                        shareSheet.popoverPresentationController?.sourceRect = .init(
                            origin: .init(x: center.x, y: center.y - 4),
                            size: .init(width: 8, height: 8)
                        )
                        parentViewController?.present(shareSheet, animated: true)
                    },
                    UIAction(
                        title: String(localized: "Open in Safari"),
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
            addSubview(magnifyImageView)
            magnifyImageView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Self.horizontalPadding)
                make.centerY.equalToSuperview()
            }

            textLabel.countsDown = false
            textLabel.textAlignment = .leading
            addSubview(textLabel)
            textLabel.snp.makeConstraints { make in
                make.leading.equalTo(magnifyImageView.snp.trailing).offset(Self.spacing)
                make.top.bottom.centerY.equalToSuperview()
                make.trailing.equalToSuperview().offset(-Self.horizontalPadding).priority(.low)
            }

            progressBar.isHidden = true
            progressBar.backgroundColor = .accent
            progressBar.layer.cornerRadius = 1
            addSubview(progressBar)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
            withAnimation { self.updateProgressBarFrame() }
        }

        static func intrinsicHeight(withLabelFont labelFont: UIFont) -> CGFloat {
            2 * verticalPadding + labelFont.lineHeight
        }

        func update(with phase: Message.WebSearchStatus) {
            setNeedsLayout()

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

            progressFraction = phase.proccessProgress
        }
    }
}
