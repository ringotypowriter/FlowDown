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
    }

    @objc func addTemplate() {
        let template = ChatTemplate()
        ChatTemplateManager.shared.addTemplate(template)
    }
}

extension ChatTemplateListController: UITableViewDelegate {}

extension ChatTemplateListController {
    class Cell: UITableViewCell {
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
            contentView.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(20)
            }
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
            view.configure(description: template.templateDescription)
        }

        func load(_ itemIdentifier: ChatTemplate.ID) {
            identifier = itemIdentifier
            if let template = ChatTemplateManager.shared.template(for: itemIdentifier) {
                load(template)
            } else {
                prepareForReuse()
            }
        }
    }
}
