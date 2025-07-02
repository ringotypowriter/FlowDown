//
//  ChatTemplateListController.swift
//  FlowDown
//
//  Created by 秋星桥 on 6/28/25.
//

import AlertController
import Combine
import ConfigurableKit
import Foundation
import Storage
import UIKit
import UniformTypeIdentifiers

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
        let menu = UIMenu(children: [
            UIMenu(title: String(localized: "Chat Template"), options: [.displayInline], children: [
                UIMenu(title: String(localized: "Chat Template"), options: [.displayInline], children: [
                    UIAction(title: String(localized: "Create Template"), image: UIImage(systemName: "plus")) { [weak self] _ in
                        var template = ChatTemplate()
                        template.name = String(localized: "Template \(ChatTemplateManager.shared.templates.count + 1)")
                        ChatTemplateManager.shared.addTemplate(template)

                        DispatchQueue.main.async {
                            let controller = ChatTemplateEditorController(templateIdentifier: template.id)
                            self?.navigationController?.pushViewController(controller, animated: true)
                        }
                    },
                ]),
                UIMenu(title: String(localized: "Import"), options: [.displayInline], children: [
                    UIAction(title: String(localized: "Import from File"), image: UIImage(systemName: "doc")) { [weak self] _ in
                        self?.presentDocumentPicker()
                    },
                ]),
            ]),
        ])
        guard let bar = navigationController?.navigationBar else { return }
        let point: CGPoint = .init(x: bar.bounds.maxX, y: bar.bounds.midY - 16)
        bar.present(menu: menu, anchorPoint: point)
    }

    func presentDocumentPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType(filenameExtension: "fdtemplate") ?? .data,
        ])
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }
}

extension ChatTemplateListController: UITableViewDelegate {
    func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let itemIdentifier = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        let delete = UIContextualAction(
            style: .destructive,
            title: String(localized: "Delete")
        ) { _, _, completion in
            guard let template = ChatTemplateManager.shared.template(for: itemIdentifier) else {
                assertionFailure()
                completion(false)
                return
            }
            assert(template.id == itemIdentifier)
            ChatTemplateManager.shared.remove(for: template.id)
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

extension ChatTemplateListController: UIDocumentPickerDelegate {
    func documentPicker(
        _: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard !urls.isEmpty else { return }

        Indicator.progress(
            title: String(localized: "Importing Templates"),
            controller: self
        ) { completionHandler in
            var success = 0
            var failure: [Error] = .init()

            for url in urls {
                do {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: url)
                    let decoder = PropertyListDecoder()
                    let template = try decoder.decode(ChatTemplate.self, from: data)
                    DispatchQueue.main.asyncAndWait {
                        ChatTemplateManager.shared.addTemplate(template)
                    }
                    success += 1
                } catch {
                    failure.append(error)
                }
            }

            completionHandler {
                if !failure.isEmpty {
                    let alert = AlertViewController(
                        title: String(localized: "Import Failed"),
                        message: String(
                            format: String(localized: "%d templates imported successfully, %d failed."),
                            success,
                            failure.count
                        )
                    ) { context in
                        context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                            context.dispose()
                        }
                    }
                    self.present(alert, animated: true)
                } else {
                    Indicator.present(
                        title: String(localized: "Imported \(success) templates."),
                        preset: .done,
                        haptic: .success,
                        referencingView: self.view
                    )
                }
            }
        }
    }
}
