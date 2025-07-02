//
//  MainController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import AlertController
import Combine
import RichEditor
import Storage
import UIKit

class MainController: UIViewController {
    let textureBackground = UIImageView().with {
        $0.image = .backgroundTexture
        $0.contentMode = .scaleAspectFill
        $0.backgroundColor = .background
        #if targetEnvironment(macCatalyst)
            $0.alpha = 0
            $0.isHidden = true
        #else
            $0.alpha = 0.2
            let vfx = UIBlurEffect(style: .systemMaterial)
            let vfxView = UIVisualEffectView(effect: vfx)
            $0.addSubview(vfxView)
            vfxView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        #endif
    }

    let sidebarLayoutView = SafeInputView()
    let sidebarDragger = SidebarDraggerView()
    let contentView = SafeInputView()
    let contentShadowView = UIView()
    let gestureLayoutGuide = UILayoutGuide()

    var allowSidebarPersistence: Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        return UIDevice.current.orientation.isLandscape || view.bounds.width > 800
    }

    var sidebarWidth: CGFloat = 256 {
        didSet {
            guard oldValue != sidebarWidth else { return }
            view.doWithAnimation { self.updateViewConstraints() }
        }
    }

    var isSidebarCollapsed = true {
        didSet {
            guard oldValue != isSidebarCollapsed else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            updateViewConstraints()
            contentView.contentView.isUserInteractionEnabled = isSidebarCollapsed || allowSidebarPersistence
        }
    }

    let chatView = ChatView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    let sidebar = Sidebar().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    var messages: [String] = []

    init() {
        super.init(nibName: nil, bundle: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetGestures),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        sidebarDragger.$currentValue
            .removeDuplicates()
            .map { CGFloat($0) }
            .ensureMainThread()
            .assign(to: \.sidebarWidth, on: self)
            .store(in: &chatView.cancellables)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        #if targetEnvironment(macCatalyst)
            view.backgroundColor = .clear
        #else
            view.backgroundColor = .background
        #endif

        view.addLayoutGuide(gestureLayoutGuide)
        view.addSubview(textureBackground)
        view.addSubview(sidebarLayoutView)
        view.addSubview(contentShadowView)
        view.addSubview(contentView)
        view.addSubview(sidebarDragger)
        sidebarLayoutView.contentView.addSubview(sidebar)
        contentView.contentView.addSubview(chatView)

        setupViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    private var previousLayoutRect: CGRect = .zero

    override func updateViewConstraints() {
        super.updateViewConstraints()
        #if targetEnvironment(macCatalyst)
            setupLayoutAsCatalyst()
        #else
            if view.frame.width < 500 /* || view.frame.height < 500 */ {
                setupLayoutAsCompactStyle()
            } else {
                setupLayoutAsRelaxedStyle()
            }
        #endif
    }

    private var previousFrame: CGRect = .zero

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        contentShadowView.layer.shadowPath = UIBezierPath(
            roundedRect: contentShadowView.bounds,
            cornerRadius: contentShadowView.layer.cornerRadius
        ).cgPath

        if previousFrame != view.frame {
            previousFrame = view.frame
            updateViewConstraints()
        }
    }

    var firstTouchLocation: CGPoint? = nil
    var lastTouchBegin: Date = .init(timeIntervalSince1970: 0)
    var touchesMoved = false

    let horizontalThreshold: CGFloat = 32

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard presentedViewController == nil else { return }
        firstTouchLocation = touches.first?.location(in: view)
        touchesMoved = false

        #if targetEnvironment(macCatalyst)
            var shouldZoomWindow = false
            defer {
                if shouldZoomWindow {
                    print("[*] zooming window...")
                    performZoom()
                }
            }
            if isTouchingHandlerBarArea(touches) {
                if Date().timeIntervalSince(lastTouchBegin) < 0.25 {
                    shouldZoomWindow = true
                }
            }
        #endif
        lastTouchBegin = .init()

        NSObject.cancelPreviousPerformRequests(
            withTarget: self, selector: #selector(resetGestures), object: nil
        )
        perform(#selector(resetGestures), with: nil, afterDelay: 0.25)
    }

    func isTouchingHandlerBarArea(_ touches: Set<UITouch>) -> Bool {
        #if targetEnvironment(macCatalyst)
            if presentedViewController == nil,
               touches.count == 1,
               let touch = touches.first,
               let window = view.window
            {
                if false
                    || touch.location(in: window).y < 32
                    || chatView.title.bounds.contains(touch.location(in: chatView))
                    || sidebar.brandingLabel.bounds.contains(
                        touch.location(in: sidebar.brandingLabel))
                {
                    return true
                }
            }
        #endif
        return false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        #if targetEnvironment(macCatalyst)
            if isTouchingHandlerBarArea(touches) {
                dispatchTouchAsWindowMovement()
                return
            }
        #endif

        super.touchesMoved(touches, with: event)

        NSObject.cancelPreviousPerformRequests(
            withTarget: self, selector: #selector(resetGestures), object: nil
        )
        perform(#selector(resetGestures), with: nil, afterDelay: 0.25)
        guard presentedViewController == nil else { return }
        #if !targetEnvironment(macCatalyst)
            guard let touch = touches.first else { return }
            let currentLocation = touch.location(in: view)
            guard let firstTouchLocation else { return }
            let offsetX = currentLocation.x - firstTouchLocation.x
            guard abs(offsetX) > horizontalThreshold else { return }
            touchesMoved = true
            view.endEditing(true)
            if updateGestureStatus(withOffset: offsetX) {
                self.firstTouchLocation = touch.location(in: view)
            }
        #endif
    }

    #if targetEnvironment(macCatalyst)
        func performZoom() {
            guard let appClass = NSClassFromString("NSApplication") as? NSObject.Type,
                  let sharedApp = appClass.value(forKey: "sharedApplication") as? NSObject,
                  sharedApp.responds(to: NSSelectorFromString("windows")),
                  let windowsArray = sharedApp.value(forKey: "windows") as? [NSObject]
            else {
                return
            }

            for window in windowsArray {
                if window.responds(to: NSSelectorFromString("performZoom:")) {
                    window.perform(NSSelectorFromString("performZoom:"), with: nil)
                }
            }
        }
    #endif

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        defer { resetGestures() }
        guard presentedViewController == nil else { return }
        guard let touch = touches.first else { return }
        if !isSidebarCollapsed,
           !touchesMoved,
           contentView.frame.contains(touch.location(in: view)),
           !allowSidebarPersistence
        {
            view.doWithAnimation { self.isSidebarCollapsed = true }
        }
    }

    @objc func resetGestures() {
        firstTouchLocation = nil
        touchesMoved = false
        updateLayoutGuideToOriginalStatus()
    }

    @objc private func contentViewButtonTapped() {
        #if targetEnvironment(macCatalyst)
            return
        #else
            guard !allowSidebarPersistence else { return }
            view.doWithAnimation { self.isSidebarCollapsed.toggle() }
        #endif
    }

    @objc func requestNewChat() {
        let conv = ConversationManager.shared.createNewConversation()
        sidebar.newChatDidCreated(conv.id)
        chatView.use(conversation: conv.id) { [weak self] in
            self?.chatView.focusEditor()
        }
    }

    @objc func openSettings() {
        sidebar.settingButton.buttonAction()
    }

    private func sendMessageToCurrentConversation(_ message: String) {
        print("[*] attempting to send message: \(message)")

        guard let currentConversationID = chatView.conversationIdentifier else {
            // showErrorAlert(title: "Error", message: "No conversation available to send message.")
            return
        }
        print("[*] current conversation ID: \(currentConversationID)")

        // retrieve session
        let session = ConversationSessionManager.shared.session(for: currentConversationID)
        print("[*] session created/retrieved for conversation")

        let modelID = ModelManager.ModelIdentifier.defaultModelForConversation
        guard !modelID.isEmpty else {
            print("[!] no default model configured")
            showErrorAlert(
                title: String(localized: "No Model Available"),
                message: String(
                    localized:
                    "Please add some models to use. You can choose to download models, or use cloud model from well known service providers."
                )
            )
            return
        }
        print("[*] using model: \(modelID)")

        // check if ui was loaded
        guard let currentMessageListView = chatView.currentMessageListView else {
            return
        }

        // verify message
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            showErrorAlert(
                title: String(localized: "Error"), message: String(localized: "Empty message.")
            )
            return
        }
        print("[*] message content: '\(trimmedMessage)'")

        let editorObject = RichEditorView.Object(text: trimmedMessage)
        session.doInfere(
            modelID: modelID,
            currentMessageListView: currentMessageListView,
            inputObject: editorObject
        ) {
            print("[+] message sent and AI response triggered successfully via URL scheme")
        }
    }

    private func showErrorAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = AlertViewController(
                title: title,
                message: message
            ) { context in
                context.addAction(title: "OK") {
                    context.dispose()
                }
            }
            self.present(alert, animated: true)
        }
    }
}

extension MainController: NewChatButton.Delegate {
    func newChatDidCreated(_ identifier: Conversation.ID) {
        sidebar.newChatDidCreated(identifier)
        chatView.use(conversation: identifier) { [weak self] in
            #if targetEnvironment(macCatalyst)
                self?.chatView.focusEditor()
            #endif
        }
    }
}

#if targetEnvironment(macCatalyst)
    fileprivate extension UIResponder {
        func dispatchTouchAsWindowMovement() {
            guard let appType = NSClassFromString("NSApplication") as? NSObject.Type,
                  let nsApp = appType.value(forKey: "sharedApplication") as? NSObject,
                  let currentEvent = nsApp.value(forKey: "currentEvent") as? NSObject,
                  let nsWindow = currentEvent.value(forKey: "window") as? NSObject
            else { return }
            nsWindow.perform(
                NSSelectorFromString("performWindowDragWithEvent:"),
                with: currentEvent
            )
        }
    }
#endif

extension MainController {
    func queueBootMessage(text: String) {
        messages.append(text)
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(presentNextBootMessage),
            object: nil
        )
        perform(#selector(presentNextBootMessage), with: nil, afterDelay: 0.5)
    }

    @objc private func presentNextBootMessage() {
        let text = messages.joined(separator: "\n")
        messages.removeAll()

        let alert = AlertViewController(
            title: String(localized: "External Resources"),
            message: text
        ) { context in
            context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                context.dispose {}
            }
        }
        var viewController: UIViewController = self
        while let child = viewController.presentedViewController {
            viewController = child
        }
        viewController.present(alert, animated: true)
    }

    func queueNewConversation(text: String) {
        DispatchQueue.main.async {
            let conversation = ConversationManager.shared.createNewConversation()
            print("[+] created new conversation with ID: \(conversation.id)")
            self.load(conversation.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.chatView.conversationIdentifier == conversation.id {
                    self.sendMessageToCurrentConversation(text)
                }
            }
        }
    }
}
