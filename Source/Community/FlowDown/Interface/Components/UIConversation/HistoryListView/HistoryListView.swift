//
//  HistoryListView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import Combine
import UIKit

extension UIConversation {
    class HistoryListView: UIView {
        let tableView: UITableView
        var cancellables: Set<AnyCancellable> = .init()

        enum Section {
            case main
        }

        weak var delegate: Delegate?

        typealias DataSource = UITableViewDiffableDataSource<Section, Conversation.ID>
        typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Conversation.ID>
        let dataSource: DataSource

        var highlightedIdentifier: Conversation.ID = .init() {
            didSet { updateHighlight() }
        }

        init() {
            let tableView = UITableView()
            tableView.register(Cell.self, forCellReuseIdentifier: "cell")
            self.tableView = tableView
            let dataSource = DataSource(tableView: tableView) { tableView, indexPath, identifier in
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
                if let conv = ConversationManager.shared.conversation(withIdentifier: identifier) {
                    cell.textLabel?.text = conv.metadata.title
                    cell.imageView?.image = conv.metadata.avatarImage
                }
                return cell
            }
            self.dataSource = dataSource

            super.init(frame: .zero)

            addSubview(tableView)
            tableView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            tableView.delegate = self
            tableView.separatorStyle = .none
            tableView.backgroundColor = .clear
            tableView.backgroundView = nil
            tableView.alwaysBounceVertical = true
            tableView.contentInset = .zero
            tableView.scrollIndicatorInsets = .zero
            tableView.selectionFollowsFocus = true

            tableView.dataSource = dataSource
            dataSource.defaultRowAnimation = .fade

            ConversationManager.shared.conversationsPublisher()
                .ensureMainThread()
                .map(\.values)
                .map { $0.map(\.id) }
                .sink { [weak self] output in
                    self?.updateSnapshot(forInput: output)
                }
                .store(in: &cancellables)

            updateHighlight()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        func updateHighlight() {
            tableView.indexPathsForSelectedRows?.forEach {
                tableView.deselectRow(at: $0, animated: false)
            }
            let indexPath = dataSource.indexPath(for: highlightedIdentifier)
            if let indexPath {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }

        func updateSnapshot(forInput convs: [Conversation.ID]) {
            var snapshot = Snapshot()
            snapshot.appendSections([.main])
            snapshot.appendItems(convs.reversed(), toSection: .main)
            dataSource.apply(snapshot, animatingDifferences: true)
        }

        func updateCell(forConversationIdentifier conv: Conversation.ID) {
            var snapshot = dataSource.snapshot()
            snapshot.reconfigureItems([conv])
            dataSource.apply(snapshot)
        }
    }
}

extension UIConversation.HistoryListView {}
