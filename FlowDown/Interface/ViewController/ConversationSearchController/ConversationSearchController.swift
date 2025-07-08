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
        let isHighlighted = highlightedIndex == indexPath.row
        cell.configure(with: result, searchTerm: searchTerm, isHighlighted: isHighlighted)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ConversationSearchController.ContentController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("ConversationSearch: Table view cell selected at row \(indexPath.row)")
        tableView.deselectRow(at: indexPath, animated: true)
        selectResult(at: indexPath)
    }
}

// MARK: - UITableViewDataSourcePrefetching
@available(iOS 10.0, *)
extension ConversationSearchController.ContentController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        // Pre-load any heavy content if needed
        // For now, this is mostly handled by the attributed string creation
        // which happens in cellForRowAt
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        // Cancel any prefetching operations if needed
    }
}


// MARK: - UISearchBarDelegate
extension ConversationSearchController.ContentController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Invalidate any existing timer
        searchTimer?.invalidate()
        
        // Reset highlighted index and cached cell when search changes
        highlightedIndex = nil
        currentHighlightedCell = nil
        
        guard !searchText.isEmpty else {
            searchResults = []
            if view.window != nil {
                tableView.reloadData()
                updateNoResultsView()
            }
            return
        }
        
        // Start a new timer for debounced search
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.performSearch(query: searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Handle enter key press on search bar - select first result if available
        searchBar.resignFirstResponder()
        if !searchResults.isEmpty {
            let indexToSelect = highlightedIndex ?? 0
            highlightedIndex = indexToSelect
            handleEnterKey()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Immediately dismiss the controller
        if let navController = navigationController {
            navController.dismiss(animated: true) { [weak self] in
                self?.callback(nil)
            }
        } else {
            dismiss(animated: true) { [weak self] in
                self?.callback(nil)
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension ConversationSearchController.ContentController: UITextFieldDelegate {
    // This is used for capturing keyboard events
}

// MARK: - Keyboard Navigation Protocol
protocol KeyboardNavigationDelegate: AnyObject {
    func didPressUpArrow()
    func didPressDownArrow()
    func didPressEnter()
}

// MARK: - Custom Search Bar with Keyboard Navigation
class KeyboardNavigationSearchBar: UISearchBar {
    weak var keyboardNavigationDelegate: KeyboardNavigationDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupKeyboardHandling()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboardHandling()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeyboardHandling()
    }
    
    private func setupKeyboardHandling() {
        // Find the text field inside the search bar
        if let textField = self.value(forKey: "searchField") as? UITextField {
            textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        }
    }
    
    @objc private func textFieldDidChange() {
        // This will be called when text changes
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            
            switch key.keyCode {
            case .keyboardReturnOrEnter:
                keyboardNavigationDelegate?.didPressEnter()
                return
            case .keyboardUpArrow:
                keyboardNavigationDelegate?.didPressUpArrow()
                return
            case .keyboardDownArrow:
                keyboardNavigationDelegate?.didPressDownArrow()
                return
            default:
                break
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

// MARK: - Keyboard Navigation Delegate
extension ConversationSearchController.ContentController: KeyboardNavigationDelegate {
    func didPressUpArrow() {
        handleUpArrow()
    }
    
    func didPressDownArrow() {
        handleDownArrow()
    }
    
    func didPressEnter() {
        handleEnterKey()
    }
}

extension ConversationSearchController {
    class ContentController: UIViewController {
        var callback: SearchCallback
        
        let searchBar = KeyboardNavigationSearchBar()
        let tableView = UITableView(frame: .zero, style: .plain)
        let noResultsView = UIView()
        let emptyStateView = UIView()
        
        var searchResults: [SearchResult] = []
        private var searchTimer: Timer?
        private var highlightedIndex: Int? = nil // Track highlighted row for keyboard navigation
        private weak var currentHighlightedCell: SearchResultCell? // Cache current highlighted cell for performance

        init(callback: @escaping SearchCallback) {
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
            
            // Setup search bar
            searchBar.placeholder = String(localized: "Search")
            searchBar.delegate = self
            searchBar.showsCancelButton = true
            searchBar.searchBarStyle = .minimal
            searchBar.keyboardNavigationDelegate = self
            
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
            
            // Enable prefetching for better performance
            if #available(iOS 10.0, *) {
                tableView.prefetchDataSource = self
            }
            
            setupNoResultsView()
            setupEmptyStateView()
            setupKeyboardHandling()
            setupKeyboardNavigation()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // Don't try to become first responder here, let the search bar handle it
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            // Ensure search bar gets and keeps focus with a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                if !self.searchBar.isFirstResponder {
                    self.searchBar.becomeFirstResponder()
                }
            }
            
            tableView.reloadData()
            updateNoResultsView()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
        }
        
        func performSearch(query: String) {
            searchResults = ConversationManager.shared.searchConversations(query: query)
            
            // Reset highlighted index and cached cell when search results change
            highlightedIndex = nil
            currentHighlightedCell = nil
            
            if view.window != nil {
                tableView.reloadData()
                updateNoResultsView()
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.view.window != nil else { return }
                    self.tableView.reloadData()
                    self.updateNoResultsView()
                }
            }
        }
        
        // MARK: - Keyboard Navigation
        
        func setupKeyboardNavigation() {
            // Set up the search bar to handle keyboard events
            searchBar.returnKeyType = .search
            
            // Add a subtle hint about keyboard navigation
            let inputAccessoryToolbar = UIToolbar()
            inputAccessoryToolbar.barStyle = .default
            inputAccessoryToolbar.isTranslucent = true
            inputAccessoryToolbar.sizeToFit()
            
            // Create flexible space items
            let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            
            // Create info button to show keyboard shortcuts
            let infoButton = UIBarButtonItem(
                title: "↑↓ Navigate • Enter Select",
                style: .plain,
                target: nil,
                action: nil
            )
            infoButton.isEnabled = false
            infoButton.setTitleTextAttributes([
                .foregroundColor: UIColor.secondaryLabel,
                .font: UIFont.systemFont(ofSize: 12)
            ], for: .disabled)
            
            inputAccessoryToolbar.setItems([flexibleSpace, infoButton, flexibleSpace], animated: false)
            searchBar.inputAccessoryView = inputAccessoryToolbar
        }
        
        override var canBecomeFirstResponder: Bool {
            return false // Don't steal focus from search bar
        }
        
        private func handleEnterKey() {
            guard !searchResults.isEmpty else { return }
            
            // If no specific row is highlighted, use the first one
            let indexToSelect = highlightedIndex ?? 0
            guard indexToSelect >= 0 && indexToSelect < searchResults.count else { return }
            
            let indexPath = IndexPath(row: indexToSelect, section: 0)
            
            // Update highlighted index if needed
            if highlightedIndex != indexToSelect {
                updateHighlightedIndex(indexToSelect)
            }
            
            // Brief visual feedback, then navigate
            if let cell = tableView.cellForRow(at: indexPath) as? SearchResultCell {
                // Quick scale animation to show selection
                UIView.animate(withDuration: 0.1, animations: {
                    cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                }) { _ in
                    UIView.animate(withDuration: 0.1, animations: {
                        cell.transform = .identity
                    }) { _ in
                        self.selectResult(at: indexPath)
                    }
                }
            } else {
                selectResult(at: indexPath)
            }
        }
        
        private func handleUpArrow() {
            guard !searchResults.isEmpty else { return }
            
            if let currentIndex = highlightedIndex {
                let newIndex = max(0, currentIndex - 1)
                updateHighlightedIndex(newIndex)
            } else {
                // If nothing is highlighted, select the last item
                updateHighlightedIndex(searchResults.count - 1)
            }
        }
        
        private func handleDownArrow() {
            guard !searchResults.isEmpty else { return }
            
            if let currentIndex = highlightedIndex {
                let newIndex = min(searchResults.count - 1, currentIndex + 1)
                updateHighlightedIndex(newIndex)
            } else {
                // If nothing is highlighted, select the first item
                updateHighlightedIndex(0)
            }
        }
        
        private func updateHighlightedIndex(_ newIndex: Int) {
            let oldIndex = highlightedIndex
            highlightedIndex = newIndex
            
            // Efficiently update cell appearances using cached reference
            if let oldIndex = oldIndex, oldIndex != newIndex {
                if let oldCell = currentHighlightedCell {
                    oldCell.updateHighlightState(false)
                }
            }
            
            // Get and cache the new highlighted cell
            if let newCell = tableView.cellForRow(at: IndexPath(row: newIndex, section: 0)) as? SearchResultCell {
                newCell.updateHighlightState(true)
                currentHighlightedCell = newCell
            }
            
            // Scroll to visible if needed
            let newIndexPath = IndexPath(row: newIndex, section: 0)
            tableView.scrollToRow(at: newIndexPath, at: .none, animated: true)
        }
        
        private func selectResult(at indexPath: IndexPath) {
            guard indexPath.row < searchResults.count else { 
                print("ConversationSearch: Invalid index \(indexPath.row) for \(searchResults.count) results")
                return 
            }
            
            let result = searchResults[indexPath.row]
            let conversationId = result.conversation.id
            
            print("ConversationSearch: Selecting conversation '\(result.conversation.title)' with ID: \(conversationId)")
            
            // Dismiss the search controller and call the callback
            if let navController = navigationController {
                navController.dismiss(animated: true) { [weak self] in
                    print("ConversationSearch: Calling callback with ID: \(conversationId)")
                    self?.callback(conversationId)
                }
            } else {
                dismiss(animated: true) { [weak self] in
                    print("ConversationSearch: Calling callback with ID: \(conversationId)")
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

