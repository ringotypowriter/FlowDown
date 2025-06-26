//
//  MainController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import AlertController
import Combine
import Storage
import RichEditor
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

    let sidebarView = SafeInputView()
    let contentView = SafeInputView()
    let contentShadowView = UIView()
    let gestureLayoutGuide = UILayoutGuide()

    let chatView = ChatView()
    let sidebar = Sidebar()

    var isSidebarCollapsed = true {
        didSet {
            guard oldValue != isSidebarCollapsed else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            updateViewConstraints()
            contentView.contentView.isUserInteractionEnabled = isSidebarCollapsed
        }
    }

    init() {
        fatalError()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetGestures),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pickupModels),
            name: .openModel,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewMessage),
            name: .sendNewMessage,
            object: nil
        )
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
        textureBackground.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        sidebarView.clipsToBounds = true
        view.addSubview(sidebarView)

        view.addSubview(contentShadowView)

        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous

        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .background
        view.addSubview(contentView)

        contentShadowView.layer.shadowColor = UIColor.black.cgColor
        contentShadowView.layer.shadowOffset = .zero
        contentShadowView.layer.shadowRadius = 8
        #if targetEnvironment(macCatalyst)
            contentShadowView.layer.shadowOpacity = 0.025
        #else
            contentShadowView.layer.shadowOpacity = 0.1
        #endif
        contentShadowView.layer.cornerRadius = contentView.layer.cornerRadius
        contentShadowView.layer.cornerCurve = contentView.layer.cornerCurve

        contentShadowView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }

        setupViews()
        sidebar.newChatButton.delegate = self
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

        if previousFrame != view.frame {
            previousFrame = view.frame
            updateViewConstraints()
            view.setNeedsLayout()
            return
        }

        contentShadowView.layer.shadowPath =
            UIBezierPath(
                roundedRect: contentShadowView.bounds,
                cornerRadius: contentShadowView.layer.cornerRadius
            ).cgPath
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
        if !isSidebarCollapsed, !touchesMoved, contentView.frame.contains(touch.location(in: view)) {
            view.doWithAnimation { self.isSidebarCollapsed = true }
            return
        }
    }

    override var keyCommands: [UIKeyCommand]? {
        var commands = [
            UIKeyCommand(
                input: "n",
                modifierFlags: .command,
                action: #selector(requestNewChat)
            ),
            UIKeyCommand(
                input: ",",
                modifierFlags: .command,
                action: #selector(openSettings)
            ),
        ]
        return commands
    }

    @objc func resetGestures() {
        firstTouchLocation = nil
        touchesMoved = false
        updateLayoutGuideToOriginalStatus()
    }

    @objc private func contentViewButtonTapped() {
        view.doWithAnimation { self.isSidebarCollapsed.toggle() }
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

    @objc func pickupModels() {
        let models = SceneDelegate.supposeToOpenModel
        SceneDelegate.supposeToOpenModel.removeAll()
        guard !models.isEmpty else { return }
        print("[*] opening models \(models)")
        ModelManager.shared.importModels(at: models, controller: self)
    }

    @objc func handleNewMessage(_ notification: Notification) {
        guard let message = notification.object as? String else {
            print("[!] Invalid message object in notification")
            return
        }
        print("[*] handling new message from URL scheme: \(message)")

        DispatchQueue.main.async {
            // create new conversation
            let conversation = ConversationManager.shared.createNewConversation()
            print("[+] Created new conversation with ID: \(conversation.id)")

            self.load(conversation.id)

            // send after ensuring UI is fully ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if self.chatView.conversationIdentifier == conversation.id {
                    self.sendMessageToCurrentConversation(message)
                } else {
                    // retry
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.sendMessageToCurrentConversation(message)
                    }
                }
            }
        }
    }

    private func sendMessageToCurrentConversation(_ message: String) {
        print("[*] Attempting to send message: \(message)")

        guard let currentConversationID = chatView.conversationIdentifier else {
            // showErrorAlert(title: "Error", message: "No conversation available to send message.")
            return
        }
        print("[*] Current conversation ID: \(currentConversationID)")

        // retrieve session
        let session = ConversationSessionManager.shared.session(for: currentConversationID)
        print("[*] Session created/retrieved for conversation")

        let modelID = ModelManager.ModelIdentifier.defaultModelForConversation
        guard !modelID.isEmpty else {
            print("[!] No default model configured")
            showErrorAlert(
                title: String(localized: "No Model Available"),
                message: String(
                    localized:
                    "Please add some models to use. You can choose to download models, or use cloud model from well known service providers."
                )
            )
            return
        }
        print("[*] Using model: \(modelID)")

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
        print("[*] Message content: '\(trimmedMessage)'")

        let editorObject = RichEditorView.Object(text: trimmedMessage)
        session.doInfere(
            modelID: modelID,
            currentMessageListView: currentMessageListView,
            inputObject: editorObject
        ) {
            print("[+] Message sent and AI response triggered successfully via URL scheme")
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
        chatView.use(conversation: identifier)
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
