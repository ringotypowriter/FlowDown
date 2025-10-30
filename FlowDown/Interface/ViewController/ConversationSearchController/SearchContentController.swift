//
//  SearchContentController.swift
//  FlowDown
//
//  Created by 秋星桥 on 7/9/25.
//

import Combine
import UIKit

class SearchContentController: UIViewController {
    var callback: ConversationSearchController.SearchCallback

    let searchController = UISearchController(searchResultsController: nil)
    let tableView = UITableView(frame: .zero, style: .plain)
    let noResultsView = UIView()
    let emptyStateView = UIView()

    private var currentSearchToken: UUID = .init()
    var searchResults: [ConversationSearchResult] = [] {
        didSet {
            currentSearchToken = .init()
            updateNoResultsView()
            tableView.reloadData()
        }
    }

    var highlightedIndex: IndexPath?
    var currentHighlightedCell: SearchResultCell? {
        guard let highlightedIndex else { return nil }
        return tableView.cellForRow(at: highlightedIndex) as? SearchResultCell
    }

    var searchBar: UISearchBar {
        searchController.searchBar
    }

    init(callback: @escaping ConversationSearchController.SearchCallback) {
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = String(localized: "Search Conversations")

        view.backgroundColor = .background

        searchController.searchBar.placeholder = String(localized: "Search")
        searchController.searchBar.delegate = self
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.returnKeyType = .search
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false

        if let keyboardNavBar = searchController.searchBar as? KeyboardNavigationSearchBar {
            keyboardNavBar.keyboardNavigationDelegate = self
        }

        navigationItem.searchController = searchController
        navigationItem.preferredSearchBarPlacement = .stacked
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        tableView.keyboardDismissMode = .none

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        #if !targetEnvironment(macCatalyst)
            searchController.searchBar.becomeFirstResponder()
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.searchController.searchBar.becomeFirstResponder()
        }
    }

    private let searchQueue = DispatchQueue(
        label: "SearchContentController.searchQueue",
        qos: .userInitiated
    )

    @objc func performSearch(query: String) {
        let token = UUID()
        currentSearchToken = token
        // serial queue to handle requests so we are doing only the latest one
        searchQueue.async { [weak self] in
            guard let self, currentSearchToken == token else { return }
            let searchResults = ConversationManager.shared.searchConversations(query: query)
            DispatchQueue.main.async { [weak self] in
                guard let self, currentSearchToken == token else { return }
                self.searchResults = searchResults
            }
        }
    }

    func handleEnterKey() {
        guard !searchResults.isEmpty else { return }

        let selectionIndexPath = highlightedIndex ?? tableView.indexPathForSelectedRow
        guard let selectionIndexPath else { return }

        if highlightedIndex != selectionIndexPath {
            updateHighlightedIndex(selectionIndexPath)
        }
        currentHighlightedCell?.puddingAnimate()
        selectResultAndDismiss(at: selectionIndexPath)
    }

    func handleUpArrow() {
        guard !searchResults.isEmpty else { return }

        if var currentIndex = highlightedIndex {
            currentIndex.row -= 1
            currentIndex.row = max(currentIndex.row, 0)
            updateHighlightedIndex(currentIndex)
        } else {
            updateHighlightedIndex(.init(row: searchResults.count - 1, section: 0))
        }
    }

    func handleDownArrow() {
        guard !searchResults.isEmpty else { return }

        if var currentIndex = highlightedIndex {
            currentIndex.row += 1
            currentIndex.row = min(currentIndex.row, searchResults.count - 1)
            updateHighlightedIndex(currentIndex)
        } else {
            updateHighlightedIndex(.init(row: 0, section: 0))
        }
    }

    func updateHighlightedIndex(_ newIndex: IndexPath) {
        highlightedIndex = newIndex

        let cells = tableView.visibleCells.compactMap { $0 as? SearchResultCell }
        for visibleCell in cells {
            let shouldHighlight = tableView.indexPath(for: visibleCell) == newIndex
            visibleCell.updateHighlightState(shouldHighlight)
        }

        tableView.scrollToRow(at: newIndex, at: .none, animated: true)
    }

    func selectResultAndDismiss(at indexPath: IndexPath) {
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
}
