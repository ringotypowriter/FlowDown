//
//  SearchContentController.swift
//  FlowDown
//
//  Created by 秋星桥 on 7/9/25.
//

import UIKit

class SearchContentController: UIViewController {
    var callback: ConversationSearchController.SearchCallback

    let searchBar = KeyboardNavigationSearchBar()
    let tableView = UITableView(frame: .zero, style: .plain)
    let noResultsView = UIView()
    let emptyStateView = UIView()

    var searchResults: [ConversationSearchResult] = []
    var searchTimer: Timer?
    var highlightedIndex: IndexPath?
    var currentHighlightedCell: SearchResultCell? {
        guard let highlightedIndex else { return nil }
        return tableView.cellForRow(at: highlightedIndex) as? SearchResultCell
    }

    var hasKeyboard = false

    init(callback: @escaping ConversationSearchController.SearchCallback) {
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        searchTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .background

        searchBar.placeholder = String(localized: "Search")
        searchBar.delegate = self
        searchBar.showsCancelButton = true
        searchBar.searchBarStyle = .minimal
        searchBar.keyboardNavigationDelegate = self

        view.addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
            make.height.equalTo(56)
        }

        tableView.keyboardDismissMode = .none

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(self.view.keyboardLayoutGuide.snp.top)
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = .zero
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60

        setupNoResultsView()
        setupEmptyStateView()
        setupKeyboardNavigation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // For touch devices, focus immediately for fast keyboard popup
        #if !targetEnvironment(macCatalyst)
            if traitCollection.userInterfaceIdiom == .phone {
                searchBar.becomeFirstResponder()
            }
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
        updateNoResultsView()
        searchBar.becomeFirstResponder()
    }

    func performSearch(query: String) {
        searchResults = ConversationManager.shared.searchConversations(query: query)
        highlightedIndex = nil

        DispatchQueue.main.async { [weak self] in
            guard let self, view.window != nil, tableView.superview != nil else { return }
            tableView.reloadData()
            updateNoResultsView()
        }
    }

    func setupKeyboardNavigation() {
        searchBar.returnKeyType = .search
    }

    func handleEnterKey() {
        guard !searchResults.isEmpty else { return }

        let selectionIndexPath = highlightedIndex ?? tableView.indexPathForSelectedRow
        guard let selectionIndexPath else { return }

        if highlightedIndex != selectionIndexPath {
            updateHighlightedIndex(selectionIndexPath.row)
        }
        currentHighlightedCell?.puddingAnimate()
        selectResult(at: selectionIndexPath)
    }

    func handleUpArrow() {
        guard !searchResults.isEmpty else { return }

        if let currentIndex = highlightedIndex {
            let newIndex = max(0, currentIndex.row - 1)
            updateHighlightedIndex(newIndex)
        } else {
            updateHighlightedIndex(searchResults.count - 1)
        }
    }

    func handleDownArrow() {
        guard !searchResults.isEmpty else { return }

        if let currentIndex = highlightedIndex {
            let newIndex = min(searchResults.count - 1, currentIndex.row + 1)
            updateHighlightedIndex(newIndex)
        } else {
            updateHighlightedIndex(0)
        }
    }

    func updateHighlightedIndex(_ newIndex: Int) {
        highlightedIndex = .init(row: newIndex, section: 0)

        // Clear all visible cells' highlight state first to prevent double highlighting
        for visibleCell in tableView.visibleCells {
            if let searchCell = visibleCell as? SearchResultCell {
                searchCell.updateHighlightState(false)
            }
        }

        // Update the new highlighted cell
        let newIndexPath = IndexPath(row: newIndex, section: 0)
        if let newCell = tableView.cellForRow(at: newIndexPath) as? SearchResultCell {
            newCell.updateHighlightState(true)
        }

        tableView.scrollToRow(at: newIndexPath, at: .none, animated: true)
    }

    func selectResult(at indexPath: IndexPath) {
        guard indexPath.row < searchResults.count else { return }

        let result = searchResults[indexPath.row]
        let conversationId = result.conversation.id

        if let navController = navigationController {
            navController.dismiss(animated: true) { [weak self] in
                self?.callback(conversationId)
            }
        } else {
            dismiss(animated: true) { [weak self] in
                self?.callback(conversationId)
            }
        }
    }

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
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = String(localized: "Check the spelling or try a new search.")
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
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
            make.top.equalTo(searchBar.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }

        noResultsView.isHidden = true
    }
}
