import UIKit

public class RichEditorView: EditorSectionView {
    var storage: TemporaryStorage = .init(id: -1)

    public required init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    let attachmentsBar = AttachmentsBar()
    let inputEditor = InputEditor()
    let quickSettingBar = QuickSettingBar()
    let controlPanel = ControlPanel()

    let shadowContainer = UIView()
    let dropContainer = DropView()
    let dropColorView = UIView()
    let attachmentSeprator = UIView()

    lazy var sectionSubviews: [EditorSectionView] = [
        attachmentsBar,
        inputEditor,
        quickSettingBar,
        controlPanel,
    ]

    let spacing: CGFloat = 10
    var keyboardAdditionalHeight: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    public weak var delegate: Delegate?
    var objectTransactionInProgress = false
    var heightContraints: NSLayoutConstraint = .init()

    public var handlerColor: UIColor = .init {
        switch $0.userInterfaceStyle {
        case .light:
            .white
        default:
            .gray.withAlphaComponent(0.1)
        }
    } { didSet { shadowContainer.backgroundColor = handlerColor } }

    override public func initializeViews() {
        super.initializeViews()

        shadowContainer.layer.cornerRadius = 16
        shadowContainer.layer.cornerCurve = .continuous
        shadowContainer.backgroundColor = handlerColor
        shadowContainer.addShadow()
        addSubview(shadowContainer)

        dropContainer.clipsToBounds = true
        dropContainer.layer.cornerRadius = shadowContainer.layer.cornerRadius
        addSubview(dropContainer)
        dropColorView.alpha = 0
        dropColorView.backgroundColor = .accent.withAlphaComponent(0.05)
        dropColorView.alpha = 0.01
        dropContainer.addSubview(dropColorView)
        dropContainer.addInteraction(UIDropInteraction(delegate: self))
        defer { bringSubviewToFront(dropContainer) }

        for subview in sectionSubviews {
            addSubview(subview)
        }

        attachmentSeprator.backgroundColor = .gray.withAlphaComponent(0.25)
        addSubview(attachmentSeprator)

        inputEditor.delegate = self
        controlPanel.delegate = self
        quickSettingBar.delegate = self
        attachmentsBar.delegate = self

        quickSettingBar.horizontalAdjustment = spacing

        DispatchQueue.main.async {
            self.updateModelInfo()
            self.restoreEditorStatusIfPossible()
        }

        heightPublisher
            .removeDuplicates()
            .ensureMainThread()
            .sink { [weak self] output in
                self?.updateHeightConstraint(output)
            }
            .store(in: &cancellables)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        var y: CGFloat = spacing
        var finalHeight: CGFloat = 0
        for subview in sectionSubviews {
            let viewHeight = subview.heightPublisher.value
            let horizontalAdjustment = subview.horizontalAdjustment

            if viewHeight > 0 {
                subview.frame = CGRect(
                    x: spacing - horizontalAdjustment,
                    y: y,
                    width: bounds.width - spacing * 2 + horizontalAdjustment * 2,
                    height: subview.heightPublisher.value
                )
                finalHeight = subview.frame.maxY
                y = finalHeight + spacing
            } else {
                subview.frame = CGRect(
                    x: spacing - horizontalAdjustment,
                    y: y,
                    width: bounds.width - spacing * 2 + horizontalAdjustment * 2,
                    height: 0
                )
            }
        }

        if attachmentsBar.heightPublisher.value > 0 {
            attachmentSeprator.alpha = 1
            shadowContainer.frame = .init(
                x: spacing,
                y: attachmentsBar.frame.minX,
                width: bounds.width - spacing * 2,
                height: inputEditor.frame.maxY - attachmentsBar.frame.minY
            )
        } else {
            attachmentSeprator.alpha = 0
            shadowContainer.frame = inputEditor.frame
        }

        attachmentSeprator.frame = .init(
            x: shadowContainer.frame.minX,
            y: inputEditor.frame.minY - 0.5,
            width: shadowContainer.frame.width,
            height: 1
        )

        dropContainer.frame = shadowContainer.frame
        dropColorView.frame = dropContainer.bounds

        heightPublisher.send(finalHeight + keyboardAdditionalHeight + spacing)
    }

    func updateHeightConstraint(_ height: CGFloat) {
        guard heightContraints.constant != height else { return }
        heightContraints.isActive = false
        heightContraints = heightAnchor.constraint(equalToConstant: height)
        heightContraints.priority = .defaultHigh
        heightContraints.isActive = true
        parentViewController?.view.layoutIfNeeded()
        setNeedsLayout()
    }

    public func focus() {
        inputEditor.textView.becomeFirstResponder()
    }

    public func updateModelName() {
        updateModelInfo()
    }

    public func prepareForReuse() {
        storage = .init(id: -1)
        resetValues()
        updateModelName()
    }

    public func use(identifier: Int64) {
        storage = .init(id: identifier)
        updateModelInfo(postUpdate: false)
        restoreEditorStatusIfPossible()
    }

    public func scheduleModelSelection() {
        quickSettingBarPickModel()
    }

    // used when requesting retry, inherit current option toggles
    public func collectObject() -> Object {
        var text = (inputEditor.textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = attachmentsBar.attachmetns.values
        if text.isEmpty, !attachments.isEmpty {
            text = String(localized: "Attached \(attachments.count) Documents", bundle: .module)
        }
        return Object(
            text: text,
            attachments: .init(attachments),
            options: [
                .storagePrefix: .url(storage.storageDir),
                .modelIdentifier: .string(quickSettingBar.modelIdentifier),
                .browsing: .bool(quickSettingBar.browsingToggle.isOn),
                .tools: .bool(quickSettingBar.toolsToggle.isOn),
                .ephemeral: .bool(false), // .ephemeral: .bool(quickSettingBar.ephemeralChatToggle.isOn),
            ]
        )
    }
}

public extension RichEditorView {
    static let temporaryStorage = FileManager.default
        .temporaryDirectory
        .appendingPathComponent("RichEditor.TemporaryStorage")
}
