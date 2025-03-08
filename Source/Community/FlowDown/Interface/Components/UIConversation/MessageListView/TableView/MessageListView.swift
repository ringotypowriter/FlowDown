//
//  MessageListView.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Combine
import OrderedCollections
import UIKit

extension UIConversation {
    class MessageListView: UIView {
        typealias ElementPublisher = AnyPublisher<[Element], Never>
        typealias Elements = OrderedDictionary<Element.ID, Element>
        var elements: Elements = .init()

        var cancellables: Set<AnyCancellable> = []

        let tableView: UITableView = .init(frame: .zero, style: .plain).then { tableView in
            tableView.allowsSelection = false
            tableView.allowsMultipleSelection = false
            tableView.allowsFocus = false
            tableView.selectionFollowsFocus = true
            tableView.separatorColor = .clear
            tableView.backgroundColor = .clear
            for cellIdentifier in Element.Cell.allCases {
                tableView.register(cellIdentifier.cellClass, forCellReuseIdentifier: cellIdentifier.rawValue)
            }
        }

        let layoutEngine = TableLayoutEngine()
        let anchorBottomButton = FollowContentButton()

        var heightKeeper: [Element.ID: CGFloat] = [:] // prevent table view flick before layout engine updated them all
        var contentHasUpdateToResolve: Bool = false
        var isAutomaticScrollAnimating = false
        let pauseUpdateDueToUserInteract = CurrentValueSubject<Bool, Never>(false)
        var distributedPendingUpdateElements: Elements? = nil
        let elementUpdateProcessLock = Lock()

        init(dataPublisher: AnyPublisher<[Element], Never>) {
            super.init(frame: .zero)

            tableView.delegate = self
            tableView.dataSource = self
            addSubview(tableView)
            tableView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            addSubview(anchorBottomButton)
            anchorBottomButton.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview().offset(-16)
            }

            anchorBottomButton.onTap = { [weak self] in
                self?.pauseUpdateDueToUserInteract.send(false)
                self?.scrollToBottom(useTableViewAnimation: true)
            }
            updateAnchorBottomAppearance(paused: false, animated: false)

            setupPublishers(dataPublisher: dataPublisher)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        deinit {
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            viewCallingUpdateLayoutEngineWidth()
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let event,
               [.touches, .presses, .scroll].contains(event.type),
               !pauseUpdateDueToUserInteract.value,
               isAutomaticScrollAnimating
            {
                tableView.contentOffset = tableView.contentOffset
                pauseUpdateDueToUserInteract.send(true)
            }
            return super.hitTest(point, with: event)
        }

        func updateAnchorBottomAppearance(paused: Bool, animated: Bool = true) {
            if animated {
                withAnimation {
                    self.updateAnchorBottomAppearance(paused: paused, animated: false)
                    self.layoutIfNeeded()
                }
            } else {
                anchorBottomButton.alpha = paused ? 1 : 0
                anchorBottomButton.snp.updateConstraints { make in
                    let offset = paused ? -16 : 50
                    make.bottom.equalToSuperview().offset(offset)
                }
            }
        }
    }
}
