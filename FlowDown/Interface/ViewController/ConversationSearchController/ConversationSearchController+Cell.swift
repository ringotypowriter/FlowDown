//
//  ConversationSearchController+Cell.swift
//  FlowDown
//
//  Created by Alan Ye on 7/8/25.
//

import Storage
import UIKit

extension ConversationSearchController.ContentController {
    class SearchResultCell: UITableViewCell {
        let iconView = UIImageView()
        let titleLabel = UILabel()
        let subtitleLabel = UILabel()
        let dateLabel = UILabel()
        let stackView = UIStackView()
        let textStackView = UIStackView()
        let titleDateStackView = UIStackView()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            backgroundColor = .clear
            accessoryType = .disclosureIndicator

            // Icon setup
            iconView.contentMode = .scaleAspectFit
            iconView.layer.cornerRadius = 6
            iconView.clipsToBounds = true
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(28)
            }

            // Title label
            titleLabel.font = .preferredFont(forTextStyle: .body)
            titleLabel.textColor = .label
            titleLabel.numberOfLines = 1
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            // Date label
            dateLabel.font = .preferredFont(forTextStyle: .caption2)
            dateLabel.textColor = .secondaryLabel
            dateLabel.setContentHuggingPriority(.required, for: .horizontal)
            dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            dateLabel.numberOfLines = 1

            // Title and date stack
            titleDateStackView.axis = .horizontal
            titleDateStackView.spacing = 8
            titleDateStackView.alignment = .center
            titleDateStackView.distribution = .fill
            titleDateStackView.addArrangedSubview(titleLabel)
            titleDateStackView.addArrangedSubview(dateLabel)

            // Subtitle label
            subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
            subtitleLabel.textColor = .secondaryLabel
            subtitleLabel.numberOfLines = 2

            // Text stack
            textStackView.axis = .vertical
            textStackView.spacing = 4
            textStackView.addArrangedSubview(titleDateStackView)
            // Note: subtitleLabel is added dynamically in configure method

            // Main stack
            stackView.axis = .horizontal
            stackView.spacing = 12
            stackView.alignment = .center
            stackView.addArrangedSubview(iconView)
            stackView.addArrangedSubview(textStackView)

            contentView.addSubview(stackView)
            stackView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            
            // Reset highlight state when cell is reused
            backgroundColor = .clear
            transform = .identity
            
            // Clear cached content
            titleLabel.attributedText = nil
            titleLabel.text = nil
            subtitleLabel.attributedText = nil
            
            // Remove subtitle if it was added
            if textStackView.arrangedSubviews.contains(subtitleLabel) {
                textStackView.removeArrangedSubview(subtitleLabel)
                subtitleLabel.removeFromSuperview()
            }
        }

        func configure(with result: SearchResult, searchTerm: String, isHighlighted: Bool = false) {
            iconView.image = result.conversation.interfaceImage

            // Highlight search term in title
            if result.matchType == .title && !searchTerm.isEmpty {
                titleLabel.attributedText = NSAttributedString.highlightedString(
                    text: result.conversation.title,
                    searchTerm: searchTerm,
                    baseAttributes: [.font: UIFont.preferredFont(forTextStyle: .body)],
                    highlightAttributes: [.backgroundColor: UIColor.systemYellow.withAlphaComponent(0.3)]
                )
            } else {
                titleLabel.text = result.conversation.title
            }

            // Set date
            dateLabel.text = formatDate(result.conversation.creation)

            // Show/hide subtitle based on message preview
            if result.matchType == .message, let preview = result.messagePreview {
                if textStackView.arrangedSubviews.count == 1 {
                    textStackView.addArrangedSubview(subtitleLabel)
                }

                // Clean up the preview text by removing newlines and extra whitespace
                let cleanedPreview = preview
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")

                subtitleLabel.attributedText = NSAttributedString.highlightedString(
                    text: cleanedPreview,
                    searchTerm: searchTerm,
                    baseAttributes: [
                        .font: UIFont.preferredFont(forTextStyle: .caption1),
                        .foregroundColor: UIColor.secondaryLabel
                    ],
                    highlightAttributes: [.backgroundColor: UIColor.systemYellow.withAlphaComponent(0.3)]
                )
            } else {
                textStackView.removeArrangedSubview(subtitleLabel)
                subtitleLabel.removeFromSuperview()
            }
            
            // Apply highlighting after all content is set
            updateHighlightState(isHighlighted)
        }
        
        func updateHighlightState(_ isHighlighted: Bool) {
            // Use smooth animation for highlight changes with better performance
            let animationDuration: TimeInterval = 0.12
            let backgroundColor = isHighlighted ? UIColor.systemBlue.withAlphaComponent(0.1) : .clear
            let transform = isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            
            // Only animate if the state actually changed
            guard self.backgroundColor != backgroundColor || self.transform != transform else { return }
            
            UIView.animate(
                withDuration: animationDuration,
                delay: 0,
                options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState]
            ) {
                self.backgroundColor = backgroundColor
                self.transform = transform
            }
        }

        private func formatDate(_ date: Date) -> String {
            let calendar = Calendar.current
            let now = Date()

            if calendar.isDateInToday(date) {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return formatter.string(from: date)
            } else if calendar.isDateInYesterday(date) {
                return String(localized: "Yesterday")
            } else if let dayDifference = calendar.dateComponents([.day], from: date, to: now).day, dayDifference < 7 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"  // Day of week
                return formatter.string(from: date)
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
        }
    }
}
