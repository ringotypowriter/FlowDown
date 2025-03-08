//
//  ServiceProviderController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/6.
//

import Combine
import ConfigurableKit
import UIKit

class ServiceProviderController: UIViewController {
    let dataSourcePublisher = ConfigurableKit.publisher(
        forKey: SettingsKey.serviceProvider.rawValue,
        type: [ServiceProvider].self
    )

    enum TableViewSection: String {
        case main
    }

    typealias DataSource = UITableViewDiffableDataSource<TableViewSection, ServiceProvider>
    typealias Snapshot = NSDiffableDataSourceSnapshot<TableViewSection, ServiceProvider>

    let tableView: UITableView
    let dataSource: DataSource
    let placeholderLabel = PlaceholderView(
        text: NSLocalizedString("No Service Provider", comment: "")
    ).then { $0.alpha = 0.25 }
    var cancellable: Set<AnyCancellable> = []

    init() {
        let tableView = UITableView(frame: .zero, style: .plain)
        self.tableView = tableView
        tableView.register(
            ServiceProviderPreviewCell.self,
            forCellReuseIdentifier: NSStringFromClass(ServiceProviderPreviewCell.self)
        )
        dataSource = .init(tableView: tableView, cellProvider: Self.cellProvider)

        super.init(nibName: nil, bundle: nil)

        title = NSLocalizedString("Service Provider", comment: "")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .comfortableBackground

        let menuItems = UIDeferredMenuElement.uncached { [weak self] provider in
            provider(self?.menu() ?? [])
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .add,
            menu: UIMenu(options: [.displayInline], children: [menuItems])
        )

        dataSource.defaultRowAnimation = .fade
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = SeparatorView.color
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.alwaysBounceVertical = true
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(placeholderLabel)
        placeholderLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dataSourcePublisher
            .ensureMainThread()
            .map { $0 ?? [] }
            .sink { [weak self] output in
                self?.updateSnapshot(output)
            }
            .store(in: &cancellable)
    }

    func menu(forTemplate template: ServiceProvider.Template) -> UIAction {
        UIAction(title: template.name) { [weak self] _ in
            let editingPrivider = template.new()
            let viewController = AddServiceProviderViewController(initialEditing: editingPrivider)
            self?.navigationController?.pushViewController(viewController, animated: true)
        }
    }

    func menu() -> [UIMenuElement] { [
        UIMenu(
            title: NSLocalizedString("Generic Endpoints", comment: ""),
            options: [.displayInline],
            children: [
                menu(forTemplate: .openAPI),
            ]
        ),
        UIMenu(
            title: NSLocalizedString("Templates", comment: ""),
            options: [.displayInline],
            children: ServiceProvider.Template.allCases
                .filter { $0 != .openAPI }
                .map { menu(forTemplate: $0) }
        ),
    ] }

    func updateSnapshot(_ input: [ServiceProvider]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(input, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)

        placeholderLabel.isHidden = !input.isEmpty
    }
}

extension ServiceProviderController {
    static let cellProvider: DataSource.CellProvider = { tableView, indexPath, dataElement in
        let cell = tableView.dequeueReusableCell(
            withIdentifier: NSStringFromClass(ServiceProviderPreviewCell.self),
            for: indexPath
        )
        cell.contentView.isUserInteractionEnabled = false
        if let cell = cell as? ServiceProviderPreviewCell {
            cell.registerViewModel(element: dataElement)
        }
        return cell
    }
}

extension ServiceProviderController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let provider = dataSource.itemIdentifier(for: indexPath) else { return }
        let controller = AddServiceProviderViewController(initialEditing: provider)
        navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let provider = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let delete = UIContextualAction(
            style: .destructive,
            title: NSLocalizedString("Delete", comment: "")
        ) { _, _, completion in
            ServiceProviders.delete(identifier: provider.id)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    func tableView(_: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point _: CGPoint) -> UIContextMenuConfiguration? {
        guard let provider = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard var referenceView: UIView = tableView.cellForRow(at: indexPath) else {
            return nil
        }
        if let cell = referenceView as? ServiceProviderPreviewCell {
            referenceView = cell.contentView
        }
        guard let menu = provider.createMenu(referencingView: referenceView) else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            menu
        }
    }
}
