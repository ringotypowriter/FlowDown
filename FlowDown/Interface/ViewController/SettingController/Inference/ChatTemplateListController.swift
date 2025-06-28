//
//  ChatTemplateListController.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import Combine
import ConfigurableKit
import Foundation
import UIKit

class ChatTemplateListController: UIViewController {
    private var cancellables = Set<AnyCancellable>()

    let tableView = UITableView(frame: .zero, style: .plain)

    enum Section {
        case main
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    lazy var dataSource = UITableViewDiffableDataSource<
        Section,
        ChatTemplate.ID
    >(tableView: tableView) { tableView, _, itemIdentifier in
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "Cell"
        ) as! Cell
        cell.load(itemIdentifier)
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = .zero
        tableView.backgroundColor = .clear
        tableView.allowsMultipleSelection = false
        dataSource.defaultRowAnimation = .fade
        tableView.register(
            Cell.self,
            forCellReuseIdentifier: "Cell"
        )
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTemplate)
        )

        ChatTemplateManager.shared.$templates
            .dropFirst()
            .ensureMainThread()
            .sink { [weak self] templates in
                guard let self else { return }
                reload(items: .init(templates.keys), animated: true)
            }
            .store(in: &cancellables)
        reload(items: .init(ChatTemplateManager.shared.templates.keys), animated: false)
    }

    func reload(items: [ChatTemplate.ID], animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ChatTemplate.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items)
        dataSource.apply(snapshot, animatingDifferences: animated)
        DispatchQueue.main.async { [self] in
            var snapshot = dataSource.snapshot()
            snapshot.reconfigureItems(tableView.indexPathsForVisibleRows?.compactMap {
                dataSource.itemIdentifier(for: $0)
            } ?? [])
            dataSource.apply(snapshot, animatingDifferences: animated)
        }
    }

    @objc func addTemplate() {
        var template = ChatTemplate()
        template.name = String(localized: "Template \(ChatTemplateManager.shared.templates.count + 1)")
        ChatTemplateManager.shared.addTemplate(template)

        DispatchQueue.main.async {
            let controller = ChatTemplateEditorController(templateIdentifier: template.id)
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
}

extension ChatTemplateListController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let itemIdentifier = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        let delete = UIContextualAction(
            style: .destructive,
            title: String(localized: "Delete")
        ) { _, _, completion in
            guard let template = ChatTemplateManager.shared.template(for: itemIdentifier) else {
                completion(false)
                return
            }
            ChatTemplateManager.shared.remove(for: itemIdentifier)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

extension ChatTemplateListController {
    class Cell: UITableViewCell, UIContextMenuInteractionDelegate {
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        var identifier: ChatTemplate.ID?
        lazy var view = ConfigurablePageView {
            guard let identifier = self.identifier else { return nil }
            return ChatTemplateEditorController(templateIdentifier: identifier)
        }

        func commonInit() {
            selectionStyle = .none
            contentView.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(20)
            }
            view.descriptionLabel.numberOfLines = 1
            view.descriptionLabel.lineBreakMode = .byTruncatingTail
            contentView.addInteraction(UIContextMenuInteraction(delegate: self))
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            identifier = nil
        }

        func load(_ template: ChatTemplate) {
            if let image = UIImage(data: template.avatar) {
                view.configure(icon: image)
            } else {
                view.configure(icon: UIImage(systemName: "person.crop.circle.fill"))
            }
            view.configure(title: template.name)
            view.configure(description: template.prompt)
        }

        func load(_ itemIdentifier: ChatTemplate.ID) {
            identifier = itemIdentifier
            if let template = ChatTemplateManager.shared.template(for: itemIdentifier) {
                load(template)
            } else {
                prepareForReuse()
            }
        }

        func contextMenuInteraction(
            _: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {
            guard let identifier else { return nil }
            let menu = UIMenu(options: [.displayInline], children: [
                UIAction(title: String(localized: "Delete"), attributes: .destructive) { _ in
                    ChatTemplateManager.shared.remove(for: identifier)
                },
            ])
            present(menu: menu, anchorPoint: location)
            return nil
        }
    }
}
