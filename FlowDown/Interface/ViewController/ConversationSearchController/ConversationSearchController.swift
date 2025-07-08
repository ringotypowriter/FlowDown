//
//  ConversationSearchController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/5/25.
//

import AlertController
import SnapKit
import Storage
import UIKit

#if targetEnvironment(macCatalyst)
    class ConversationSearchController: AlertBaseController {
        init(callback: @escaping SearchCallback) {
            super.init(
                rootViewController: NavigationController(callback: callback),
                preferredWidth: 660,
                preferredHeight: 420
            )
            shouldDismissWhenTappedAround = true
            shouldDismissWhenEscapeKeyPressed = true
        }

        override func contentViewDidLoad() {
            super.contentViewDidLoad()
            contentView.backgroundColor = .background
        }

        class NavigationController: UINavigationController {
            init(callback: @escaping SearchCallback) {
                super.init(rootViewController: ContentController(callback: callback))
                navigationBar.isHidden = true
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError()
            }
        }
    }
#else
    class ConversationSearchController: UINavigationController {
        init(callback: @escaping SearchCallback) {
            super.init(rootViewController: ContentController(callback: callback))
            navigationBar.isHidden = true
            modalPresentationStyle = .formSheet
            modalTransitionStyle = .coverVertical
            preferredContentSize = .init(width: 550, height: 550)
            view.backgroundColor = .background
            isModalInPresentation = false
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }
    }
#endif

extension ConversationSearchController {
    typealias SearchCallback = (Conversation.ID?) -> Void
}

// MARK: - UITableViewDataSource
extension ConversationSearchController.ContentController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return searchResults.isEmpty ? 0 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as? SearchResultCell else {
            assertionFailure("Failed to dequeue SearchResultCell")
            return UITableViewCell()
        }
        let result = searchResults[indexPath.row]
        let searchTerm = searchBar.text ?? ""
        cell.configure(with: result, searchTerm: searchTerm)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ConversationSearchController.ContentController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let result = searchResults[indexPath.row]
        let conversationId = result.conversation.id
        
        // Dismiss the search controller
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


// MARK: - UISearchBarDelegate
extension ConversationSearchController.ContentController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Invalidate any existing timer
        searchTimer?.invalidate()
        
        guard !searchText.isEmpty else {
            searchResults = []
            tableView.reloadData()
            updateNoResultsView()
            return
        }
        
        // Start a new timer for debounced search
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.performSearch(query: searchText)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Immediately dismiss the controller
        if let navController = navigationController {
            navController.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension ConversationSearchController {
    class ContentController: UIViewController {
        var callback: ((Conversation.ID) -> Void) = { _ in }
        
        let searchBar = UISearchBar()
        let tableView = UITableView(frame: .zero, style: .plain)
        let noResultsView = UIView()
        let emptyStateView = UIView()
        
        var searchResults: [SearchResult] = []
        private var searchTimer: Timer?

        init(callback: @escaping SearchCallback) {
            super.init(nibName: nil, bundle: nil)
            self.callback = { [weak self] in
                callback($0)
                self?.callback = { _ in }
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            searchTimer?.invalidate()
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            view.backgroundColor = .background
            
            // Setup search bar
            searchBar.placeholder = String(localized: "Search")
            searchBar.delegate = self
            searchBar.showsCancelButton = true
            searchBar.searchBarStyle = .minimal
            
            // Add search bar directly to the view
            view.addSubview(searchBar)
            searchBar.snp.makeConstraints { make in
                make.top.equalTo(view.safeAreaLayoutGuide)
                make.left.right.equalToSuperview()
                make.height.equalTo(56)
            }
            
            // Keep keyboard visible while scrolling for better search experience
            tableView.keyboardDismissMode = .none
            
            // Setup table view below search bar
            view.addSubview(tableView)
            tableView.snp.makeConstraints { make in
                make.top.equalTo(searchBar.snp.bottom)
                make.left.right.bottom.equalToSuperview()
            }
            tableView.delegate = self
            tableView.dataSource = self
            tableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
            tableView.backgroundColor = .clear
            tableView.separatorStyle = .singleLine
            tableView.separatorInset = .zero
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 60
            
            // Setup no results view
            setupNoResultsView()
            
            // Setup empty state view
            setupEmptyStateView()
            
            // Adjust for keyboard
            setupKeyboardHandling()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // Pre-focus keyboard before view appears
            searchBar.becomeFirstResponder()
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Ensure keyboard is shown if not already
            if !searchBar.isFirstResponder {
                searchBar.becomeFirstResponder()
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
        }
        
        func performSearch(query: String) {
            searchResults = ConversationManager.shared.searchConversations(query: query)
            tableView.reloadData()
            updateNoResultsView()
        }
        
        func setupNoResultsView() {
            noResultsView.backgroundColor = .clear
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 12
            stackView.alignment = .center
            
            // Icon
            let iconView = UIImageView()
            iconView.image = UIImage(systemName: "moon.zzz")
            iconView.tintColor = .secondaryLabel
            iconView.contentMode = .scaleAspectFit
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(64)
            }
            
            // Title
            let titleLabel = UILabel()
            titleLabel.text = String(localized: "No Results")
            titleLabel.font = .preferredFont(forTextStyle: .headline)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            
            // Subtitle
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
                make.bottom.equalToSuperview()
            }
            
            noResultsView.isHidden = true
        }
        
        func updateNoResultsView() {
            let hasQuery = !(searchBar.text ?? "").isEmpty
            let hasResults = !searchResults.isEmpty
            
            noResultsView.isHidden = !hasQuery || hasResults
            emptyStateView.isHidden = hasQuery
            tableView.isHidden = hasQuery && !hasResults
        }
        
        func setupEmptyStateView() {
            emptyStateView.backgroundColor = .clear
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 12
            stackView.alignment = .center
            
            // Icon
            let iconView = UIImageView()
            iconView.image = UIImage(systemName: "loupe")
            iconView.tintColor = .secondaryLabel
            iconView.contentMode = .scaleAspectFit
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(64)
            }
            
            // Title
            let titleLabel = UILabel()
            titleLabel.text = String(localized: "Search Conversations")
            titleLabel.font = .preferredFont(forTextStyle: .headline)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            
            // Subtitle
            let subtitleLabel = UILabel()
            subtitleLabel.text = String(localized: "Find conversations by title or message")
            subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
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
                make.top.equalTo(searchBar.snp.bottom)
                make.left.right.equalToSuperview()
                make.bottom.equalToSuperview()
            }
        }
        
        func setupKeyboardHandling() {
            // Adjust content when keyboard appears
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow(_:)),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide(_:)),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }
        
        @objc func keyboardWillShow(_ notification: Notification) {
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let keyboardHeight = keyboardFrame.height
            
            // Adjust no results view to be above keyboard
            noResultsView.snp.updateConstraints { make in
                make.bottom.equalToSuperview().offset(-keyboardHeight)
            }
            
            // Adjust empty state view to be above keyboard
            emptyStateView.snp.updateConstraints { make in
                make.bottom.equalToSuperview().offset(-keyboardHeight)
            }
            
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
        @objc func keyboardWillHide(_ notification: Notification) {
            // Reset constraints
            noResultsView.snp.updateConstraints { make in
                make.bottom.equalToSuperview()
            }
            
            // Reset empty state view constraints
            emptyStateView.snp.updateConstraints { make in
                make.bottom.equalToSuperview()
            }
            
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
    }
}
