//
//  ConversationListController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/13.
//

import Combine
import UIKit

class ConversationListController: UIViewController {
    var cancellables: Set<AnyCancellable> = .init()

    init() {
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("FlowDown", comment: "")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    let list = UIConversation.HistoryListView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(list)
        list.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        list.delegate = self

        navigationItem.rightBarButtonItem = .init(systemItem: .add, primaryAction: .init(handler: { [weak self] _ in
            self?.createConversation()
        }))

        createConversation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        list.highlightedIdentifier = .init()
        for value in ConversationManager.shared.conversations.value.values.map(\.id) {
            list.updateCell(forConversationIdentifier: value)
        }
    }

    func createConversation() {
        let conv = ConversationManager.shared.createConversation()
        let controller = ConversationController(conversation: conv)
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension ConversationListController: UIConversation.HistoryListView.Delegate {
    func historyListDidSelectConversation(withIdentifier: Conversation.ID) {
        guard let conv = ConversationManager.shared.conversation(withIdentifier: withIdentifier) else {
            return
        }
        let conversation = ConversationController(conversation: conv)
        navigationController?.pushViewController(conversation, animated: true)
    }
}
