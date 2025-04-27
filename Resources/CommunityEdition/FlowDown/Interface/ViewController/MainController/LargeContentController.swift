//
//  LargeContentController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/6.
//

import ColorfulX
import Combine
import UIKit

class LargeContentController: UIViewController {
    let backgroundView = AnimatedMulticolorGradientView().then { view in
        view.alpha = 0.25
        view.speed = 0.5
        view.renderScale = 0.2
        view.frameLimit = 30
        view.noise = 0
        view.setColors(ColorfulPreset.winter.colors, animated: false)
    }

    let brandingLabel = BrandingLabel().then { view in
        view.font = .title.bold
    }

    let newConversationButton = NewConversationPopUpButton()

    let settingButton = SettingButton()

    let searchBarView = SearchBarView().then { view in
        view.alpha = 0
    }

    let historyListView = UIConversation.HistoryListView()

    let contentContainer = UIView().then { view in
        view.backgroundColor = .comfortableBackground
        view.layerCornerRadius = 8
        view.layerBorderColor = .gray.withAlphaComponent(0.25)
        view.layerBorderWidth = 0.5
        view.clipsToBounds = true
        view.masksToBounds = true
    }

    var conversation: Conversation = ConversationManager.shared.createConversation() {
        didSet {
            guard oldValue.id != conversation.id else { return }
            conversation.registerListener(self)
            rebuildContentView()
        }
    }

    private var cancellables: Set<AnyCancellable> = .init()

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                input: "N",
                modifierFlags: .command,
                action: #selector(newConversation),
                discoverabilityTitle: "New Conversation"
            ),
        ]
    }

    init() {
        super.init(nibName: nil, bundle: nil)

        newConversationButton.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        defer { rebuildContentView() }

        view.backgroundColor = .comfortableBackground
        view.hideKeyboardWhenTappedAround()

        let spacing: CGFloat = 16
        let sideBarLayoutGuide = UILayoutGuide()
        view.addLayoutGuide(sideBarLayoutGuide)
        sideBarLayoutGuide.snp.makeConstraints { make in
            make.top.left.bottom.equalTo(view.safeAreaLayoutGuide).inset(spacing)
            make.width.equalTo(256)
        }

        view.addSubview(backgroundView)
        view.addSubview(brandingLabel)
        view.addSubview(newConversationButton)
        view.addSubview(searchBarView)
        view.addSubview(historyListView)
        view.addSubview(settingButton)
        view.addSubview(contentContainer)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        brandingLabel.snp.makeConstraints { make in
            make.left.top.equalTo(sideBarLayoutGuide)
        }
        newConversationButton.snp.makeConstraints { make in
            make.top.right.equalTo(sideBarLayoutGuide)
            make.bottom.equalTo(brandingLabel)
        }
        searchBarView.snp.makeConstraints { make in
            make.top.bottom.equalTo(brandingLabel).inset(-spacing / 2)
            make.left.right.equalTo(sideBarLayoutGuide)
        }
        settingButton.snp.makeConstraints { make in
            make.left.bottom.equalTo(sideBarLayoutGuide)
            make.width.height.equalTo(32)
        }
        historyListView.snp.makeConstraints { make in
            make.top.equalTo(brandingLabel.snp.bottom).offset(spacing)
            make.left.right.equalTo(sideBarLayoutGuide)
            make.bottom.equalTo(settingButton.snp.top).offset(-spacing)
        }
        contentContainer.snp.makeConstraints { make in
            make.left.equalTo(sideBarLayoutGuide.snp.right).offset(spacing)
            #if targetEnvironment(macCatalyst)
                make.top.bottom.right.equalToSuperview().inset(spacing)
            #else
                make.top.bottom.right.equalTo(view.safeAreaLayoutGuide).inset(spacing)
            #endif
        }

        historyListView.delegate = self
        historyListView.highlightedIdentifier = conversation.id

        ConversationManager.shared.conversationsPublisher()
            .sink { [weak self] conversations in
                guard let self else { return }
                if !conversations.keys.contains(conversation.id) {
                    guard let firstConv = conversations.values.first else { return }
                    conversation = firstConv
                    historyListView.highlightedIdentifier = firstConv.id
                }
            }
            .store(in: &cancellables)

        conversation.registerListener(self)
    }

    func rebuildContentView() {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        let contentViewController = ConversationController(conversation: conversation)
        addChild(contentViewController)
        contentContainer.addSubview(contentViewController.view)
        contentViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @objc func newConversation() {
        let conversation = ConversationManager.shared.createConversation()
        self.conversation = conversation
        historyListView.highlightedIdentifier = conversation.id
    }
}

extension LargeContentController: NewConversationPopUpButton.Delegate {
    func onNewConversation(_ conversation: Conversation) {
        self.conversation = conversation
        historyListView.highlightedIdentifier = conversation.id
    }
}

extension LargeContentController: Conversation.Delegate {
    func metadataDidUpdate(metadata _: Conversation.Metadata) {
        historyListView.updateCell(forConversationIdentifier: conversation.id)
    }
}

extension LargeContentController: UIConversation.HistoryListView.Delegate {
    func historyListDidSelectConversation(withIdentifier: Conversation.ID) {
        if let conv = ConversationManager.shared.conversation(withIdentifier: withIdentifier) {
            conversation = conv
        }
    }
}
