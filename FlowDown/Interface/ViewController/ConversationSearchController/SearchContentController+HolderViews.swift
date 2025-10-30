//
//  SearchContentController+HolderViews.swift
//  FlowDown
//
//  Created by 秋星桥 on 7/9/25.
//

import UIKit

extension SearchContentController {
    func setupNoResultsView() {
        noResultsView.backgroundColor = .clear

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: "moon.zzz")
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(64)
        }

        let titleLabel = UILabel()
        titleLabel.text = String(localized: "No Results")
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = String(localized: "Check the spelling or try a new search.")
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        noResultsView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }

        view.addSubview(noResultsView)
        noResultsView.snp.makeConstraints { make in
            make.edges.equalTo(tableView)
        }

        noResultsView.isHidden = true
    }

    func setupEmptyStateView() {
        emptyStateView.backgroundColor = .clear

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: "loupe")
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(64)
        }

        let titleLabel = UILabel()
        titleLabel.text = String(localized: "Search Conversations")
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = String(localized: "Find conversations by title or message")
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        emptyStateView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }

        view.addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints { make in
            make.edges.equalTo(tableView)
        }
    }
}

extension SearchContentController {
    func updateNoResultsView() {
        let hasQuery = !(searchBar.text ?? "").isEmpty
        let hasResults = !searchResults.isEmpty

        noResultsView.isHidden = !hasQuery || hasResults
        emptyStateView.isHidden = hasQuery
        tableView.isHidden = hasQuery && !hasResults
    }
}
