//
//  QuickSettingBar.swift
//  RichEditor
//
//  Created by 秋星桥 on 2025/1/16.
//

import UIKit

public class QuickSettingBar: EditorSectionView {
    public struct ThinkingModeState {
        public let title: String
        public let isActive: Bool
        public let isVisible: Bool

        public init(title: String, isActive: Bool, isVisible: Bool) {
            self.title = title
            self.isActive = isActive
            self.isVisible = isVisible
        }
    }

    let scrollView = UIScrollView()

    let modelPicker = BlockButton(text: "", icon: "asterisk")
    let modelPickerRightClickFinder = RightClickFinder()
    let thinkingModeButton: BlockButton = {
        let button = BlockButton(
            text: String(localized: "Reasoning"),
            icon: "sparkles"
        )
        if let symbol = UIImage(systemName: "lightbulb")?.withRenderingMode(.alwaysTemplate) {
            button.iconView.image = symbol
            button.iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        }
        return button
    }()

    let browsingToggle = ToggleBlockButton(
        text: NSLocalizedString("Web Browsing", bundle: .module, comment: ""),
        icon: "server"
    )
    let toolsToggle = ToggleBlockButton(
        text: NSLocalizedString("Tools", bundle: .module, comment: ""),
        icon: "tools"
    )

    lazy var buttons: [BlockButton] = [
        modelPicker,
        thinkingModeButton,
        browsingToggle,
        toolsToggle,
    ]
    var modelIdentifier: String = ""
    var modelSupportsToolCall = false {
        didSet { toolsToggle.strikeThrough = !modelSupportsToolCall }
    }

    var height: CGFloat {
        if isOpen {
            buttons.filter { !$0.isHidden }.map(\.intrinsicContentSize.height).max() ?? 0
        } else {
            0
        }
    }

    var isOpen = true {
        didSet {
            heightPublisher.send(height)
            withAnimation { self.setNeedsLayout() }
        }
    }

    weak var delegate: Delegate?

    override public func initializeViews() {
        super.initializeViews()

        scrollView.clipsToBounds = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        addSubview(scrollView)

        for button in buttons {
            scrollView.addSubview(button)
            if let button = button as? ToggleBlockButton {
                button.onValueChanged = { [weak self] in
                    self?.delegate?.quickSettingBarOnValueChagned()
                }
            }
        }

        setModelName(nil)

        modelPicker.showsMenuAsPrimaryAction = true
        modelPicker.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                guard let self else {
                    completion([])
                    return
                }
                scrollToBeforeModelItem()
                let elements = delegate?.quickSettingBarBuildModelSelectionMenu() ?? []
                completion(elements)
            },
        ])
        modelPicker.actionBlock = {}

        var requestReload: ((Bool) -> Void)!
        requestReload = { [weak self] input in
            self?.toolsToggle.isOn = input
            self?.toolsToggle.menu = .init(children: [UIDeferredMenuElement.uncached { [weak self] provider in
                let isEnabled = self?.toolsToggle.isOn ?? false
                let elements = self?.delegate?.quickSettingBarBuildAlternativeToolsMenu(
                    isEnabled: isEnabled,
                    requestReload: requestReload
                ) ?? []
                provider(elements)
            }])
        }
        requestReload(false)
        toolsToggle.showsMenuAsPrimaryAction = true
        toolsToggle.actionBlock = {}

        thinkingModeButton.showsMenuAsPrimaryAction = false
        thinkingModeButton.actionBlock = { [weak self] in
            guard let self else { return }
            delegate?.quickSettingBarToggleThinkingMode()
            refreshThinkingModeButton()
        }
        thinkingModeButton.isHidden = true

        heightPublisher.send(height)
        updateToolCallAvailability(false)
        refreshThinkingModeButton()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        defer {
            let contentSizeWidth = scrollView.contentSize.width
            if contentSizeWidth < bounds.width {
                scrollView.frame = .init(
                    x: (bounds.width - contentSizeWidth) / 2,
                    y: 0,
                    width: contentSizeWidth,
                    height: bounds.height
                )
            }
        }

        alpha = isOpen ? 1 : 0
        guard isOpen else { return }

        buttons.forEach { $0.transform = .identity }
        let visibleButtons = buttons.filter { !$0.isHidden }
        let sizes = visibleButtons.map(\.intrinsicContentSize)

        var anchorX: CGFloat = horizontalAdjustment
        for (index, button) in visibleButtons.enumerated() {
            let size = sizes[index]
            assert(size.width > 0)
            assert(size.height > 0)
            button.frame = .init(
                x: anchorX,
                y: 0,
                width: size.width,
                height: size.height
            )
            anchorX += size.width + 10
        }

        let lastOne = visibleButtons.last?.frame.maxX ?? 0
        let contentSizeWidth = lastOne + horizontalAdjustment
        scrollView.contentSize = .init(width: contentSizeWidth, height: height)
    }

    func setModelName(_ name: String?) {
        defer { setNeedsLayout() }
        guard let name, !name.isEmpty else {
            modelPicker.textLabel.text = NSLocalizedString("No Model", bundle: .module, comment: "")
            return
        }
        modelPicker.textLabel.text = name
    }

    func updateToolCallAvailability(_ availability: Bool) {
        modelSupportsToolCall = availability
        if !availability { toolsToggle.isOn = false }
    }

    func scrollToBeforeModelItem() {
        scrollView.withAnimation { [self] in
            scrollView.contentOffset.x = 0
        }
    }

    func scrollToAfterModelItem() {
        scrollView.withAnimation { [self] in
            var requiredOffset = modelPicker.frame.maxX + 10
            requiredOffset = min(requiredOffset, scrollView.contentSize.width - scrollView.frame.width)
            requiredOffset = max(0, requiredOffset)
            scrollView.contentOffset.x = requiredOffset
        }
    }

    func setModelIdentifier(_ modelIdentifier: String?) {
        self.modelIdentifier = modelIdentifier ?? ""
    }

    func hide() {
        isOpen = false
    }

    func show() {
        isOpen = true
    }

    func updateThinkingModeButton(state: ThinkingModeState?) {
        guard let state, state.isVisible else {
            if !thinkingModeButton.isHidden {
                thinkingModeButton.isHidden = true
                heightPublisher.send(height)
                setNeedsLayout()
            }
            return
        }

        thinkingModeButton.isHidden = false
        thinkingModeButton.textLabel.text = String(localized: "Reasoning")
        thinkingModeButton.applyDefaultAppearance()

        if state.isActive {
            thinkingModeButton.borderView.layer.borderColor = UIColor.accent.cgColor
            thinkingModeButton.borderView.backgroundColor = .accent
            thinkingModeButton.iconView.tintColor = .white
            thinkingModeButton.textLabel.textColor = .white
        } else {
            thinkingModeButton.borderView.layer.borderColor = UIColor.label.withAlphaComponent(0.1).cgColor
            thinkingModeButton.borderView.backgroundColor = .clear
            thinkingModeButton.iconView.tintColor = .label
            thinkingModeButton.textLabel.textColor = .label
        }

        heightPublisher.send(height)
        setNeedsLayout()
    }

    func refreshThinkingModeButton() {
        let state = delegate?.quickSettingBarRequestThinkingModeState()
        updateThinkingModeButton(state: state)
    }
}
