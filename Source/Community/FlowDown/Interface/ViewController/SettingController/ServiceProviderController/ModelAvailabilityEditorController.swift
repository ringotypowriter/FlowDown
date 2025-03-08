//
//  ModelAvailabilityEditorController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/8.
//

import ConfigurableKit
import OrderedCollections
import UIKit

class ModelAvailabilityEditorController: UIViewController {
    let values: [ServiceProvider.ModelType: [CellViewModel]]
    var onUpdateBlock: ((ServiceProvider.Models) -> Void)?

    typealias TableViewSection = ServiceProvider.ModelType

    let tableView: UITableView

    var searchKey: String = "" {
        didSet { updateDataSource() }
    }

    init(dataSource: ServiceProvider.Models, currentEnabledModels: ServiceProvider.Models) {
        values = dataSource.mapKeysAndValues { key, value in
            let current = Set(currentEnabledModels[key, default: []])
            return (key, value.sorted().map {
                CellViewModel(modelType: key, modelIdentifier: $0, bool: current.contains($0))
            })
        }
        let tableView = UITableView(frame: .zero, style: .plain)
        self.tableView = tableView
        tableView.register(
            Cell.self,
            forCellReuseIdentifier: NSStringFromClass(Cell.self)
        )
        tableView.register(headerFooterViewClassWith: Header.self)

        super.init(nibName: nil, bundle: nil)

        tableView.dataSource = self

        title = NSLocalizedString("Edit Model Availability", comment: "")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .comfortableBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(done)
            ),
        ]

        navigationItem.searchController = .init(searchResultsController: nil)
        navigationItem.searchController?.searchBar.delegate = self
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.searchController?.searchBar.placeholder = NSLocalizedString("Search...", comment: "")
        navigationItem.searchController?.searchBar.autocapitalizationType = .none
        navigationItem.searchController?.searchBar.autocorrectionType = .no
        navigationItem.searchController?.searchBar.spellCheckingType = .no

        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = SeparatorView.color
        tableView.separatorInset = .zero
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.alwaysBounceVertical = true
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        tableView.allowsSelection = false
        tableView.allowsFocus = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        updateDataSource()
    }

    func updateDataSource() {
        for item in values {
            for item in item.value {
                item.highlight = searchKey
            }
        }
        tableView.reloadData()
    }

    @objc func done() {
        updateEnableModelsToBlock()
        navigationController?.popViewController(animated: true)
    }

    func update(identifier: CellViewModel.ID, to newValue: Bool) {
        values.values
            .flatMap(\.self)
            .filter { $0.id == identifier }
            .forEach { $0.bool = newValue }
        updateEnableModelsToBlock()
    }

    func updateEnableModelsToBlock() {
        var result: ServiceProvider.Models = .init()
        for (type, values) in values {
            result[type] = .init(
                values
                    .filter(\.bool)
                    .filter { $0.modelType == type }
                    .map(\.modelIdentifier)
                    .sorted()
            )
        }
        onUpdateBlock?(result)
    }
}

extension ModelAvailabilityEditorController: UITableViewDelegate, UITableViewDataSource {
    var searchResult: [CellViewModel] {
        values.values.flatMap(\.self).filter {
            searchKey.isEmpty || $0.modelIdentifier.localizedCaseInsensitiveContains(searchKey)
        }
    }

    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        searchResult.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: NSStringFromClass(Cell.self),
            for: indexPath
        )
        if let cell = cell as? Cell {
            cell.configure(with: searchResult[indexPath.row])
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

//    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let header = tableView.dequeueReusableHeaderFooterView(withClass: Header.self)
//
//        header.configure(with: value.interfaceText)
//        return header
//    }
}

extension ModelAvailabilityEditorController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        searchKey = searchText
    }
}

// extension ModelAvailabilityEditorController {
//    static let cellProvider: DataSource.CellProvider = { tableView, indexPath, item in
//        let cell = tableView.dequeueReusableCell(
//            withIdentifier: NSStringFromClass(Cell.self),
//            for: indexPath
//        )
//        if let cell = cell as? Cell {
//            cell.configure(with: item)
//        }
//        return cell
//    }
// }
