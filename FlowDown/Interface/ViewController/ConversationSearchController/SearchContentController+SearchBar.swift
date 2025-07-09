//
//  SearchContentController+SearchBar.swift
//  FlowDown
//
//  Created by 秋星桥 on 7/9/25.
//

import UIKit

extension SearchContentController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        searchTimer?.invalidate()
        highlightedIndex = nil

        guard !searchText.isEmpty else {
            searchResults = []
            DispatchQueue.main.async { [weak self] in
                guard let self, view.window != nil, tableView.superview != nil else { return }
                tableView.reloadData()
                updateNoResultsView()
            }
            return
        }

        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.performSearch(query: searchText)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if !searchResults.isEmpty {
            let indexToSelect = highlightedIndex?.row ?? 0
            highlightedIndex = .init(row: indexToSelect, section: 0)
            handleEnterKey()
        }
    }

    func searchBarCancelButtonClicked(_: UISearchBar) {
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
