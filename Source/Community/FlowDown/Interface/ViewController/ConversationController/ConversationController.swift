//
//  ConversationController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import Combine
import Foundation
import UIKit

class ConversationController: UIViewController {
    let conversation: Conversation

    let messageListSubject: CurrentValueSubject<[Conversation.Message], Never>
    let messageListDataSource: UIConversation.MessageListView.ElementPublisher
    let titleBar = UIConversation.TitleBarView()
    let titleBarSeparator = SeparatorView()
    let messageList: UIConversation.MessageListView
    let messageEditorSeprator = SeparatorView()
    let messageEditor = UIConversation.MessageEditorView()
    let progressCover = UIConversation.ProgressCoverView()
    let keyboardAdapter = UIView()

    var cancellable: Set<AnyCancellable> = []

    init(conversation: Conversation) {
        self.conversation = conversation

        messageListSubject = .init(.init(conversation.messages.values))
        messageListDataSource = messageListSubject
            .map { $0.flatMap(UIConversation.MessageListView.Element.transform(input:)) }
            .eraseToAnyPublisher()

        messageList = .init(dataPublisher: messageListDataSource)

        super.init(nibName: nil, bundle: nil)

        messageEditor.delegate = self
        messageEditor.modelSelectButton.delegate = self

        titleBar.delegate = self

        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        cancellable.forEach { $0.cancel() }
        cancellable.removeAll()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .comfortableBackground

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillDisappear),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillAppear),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        view.addSubview(titleBar)
        view.addSubview(titleBarSeparator)
        view.addSubview(messageList)
        view.addSubview(messageEditorSeprator)
        view.addSubview(messageEditor)
        view.addSubview(keyboardAdapter)
        messageEditor.addSubview(progressCover)

        let titleBarHeight: CGFloat = 64
        titleBar.snp.makeConstraints { make in
            #if targetEnvironment(macCatalyst)
                make.top.equalToSuperview()
            #else
                make.top.equalTo(view.safeAreaLayoutGuide)
            #endif
            make.left.right.equalToSuperview()
            make.height.equalTo(titleBarHeight)
        }
        titleBarSeparator.snp.makeConstraints { make in
            make.top.equalTo(titleBar.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(1)
        }
        messageList.snp.makeConstraints { make in
            make.top.equalTo(titleBarSeparator.snp.bottom)
            make.left.right.equalToSuperview()
        }
        messageEditorSeprator.snp.makeConstraints { make in
            make.top.equalTo(messageList.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(1)
        }
        messageEditor.snp.makeConstraints { make in
            make.top.equalTo(messageEditorSeprator.snp.bottom)
            make.left.right.equalToSuperview()
        }
        keyboardAdapter.snp.makeConstraints { make in
            make.top.equalTo(messageEditor.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(0)
            #if targetEnvironment(macCatalyst)
                make.bottom.equalToSuperview()
            #else
                make.bottom.equalTo(view.safeAreaLayoutGuide)
            #endif
        }

        messageList.hideKeyboardWhenTappedAround()

        progressCover.alpha = 0
        progressCover.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleBar.subscribe(to: conversation)

        conversation.registerListener(self)
    }
}
