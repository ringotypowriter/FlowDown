//
//  QuickSettingBar.swift
//  RichEditor
//
//  Created by 秋星桥 on 2025/1/16.
//

import UIKit

public class QuickSettingBar: EditorSectionView {
    let scrollView = UIScrollView()

    let modelPicker = BlockButton(text: "", icon: "asterisk")
    let modelPickerRightClickFinder = RightClickFinder()
    let browsingToggle = ToggleBlockButton(
        text: NSLocalizedString("Web Browsing", bundle: .module, comment: ""),
        icon: "server"
    )
    let toolsToggle = ToggleBlockButton(
        text: NSLocalizedString("Tools", bundle: .module, comment: ""),
        icon: "tools"
    )
    let toolsToggleRightClickFinder = RightClickFinder()
    let ephemeralChatToggle = ToggleBlockButton(
        text: NSLocalizedString("Ephemeral Chat", bundle: .module, comment: ""),
        icon: "beaker"
    )

    lazy var buttons: [BlockButton] = [
        modelPicker,
        browsingToggle,
        toolsToggle,
//        ephemeralChatToggle, // removed for now
    ]
    var modelIdentifier: String = ""
    var modelSupportsToolCall = false {
        didSet { toolsToggle.strikeThrough = !modelSupportsToolCall }
    }

    var height: CGFloat {
        if isOpen {
            buttons.map(\.intrinsicContentSize.height).max() ?? 0
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

        // Setup model picker menu - add a transparent button overlay for menu
        let modelPickerMenuButton = UIButton(type: .system)
        modelPickerMenuButton.backgroundColor = .clear
        modelPickerMenuButton.showsMenuAsPrimaryAction = true
        modelPicker.addSubview(modelPickerMenuButton)
        modelPickerMenuButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            modelPickerMenuButton.topAnchor.constraint(equalTo: modelPicker.topAnchor),
            modelPickerMenuButton.leadingAnchor.constraint(equalTo: modelPicker.leadingAnchor),
            modelPickerMenuButton.trailingAnchor.constraint(equalTo: modelPicker.trailingAnchor),
            modelPickerMenuButton.bottomAnchor.constraint(equalTo: modelPicker.bottomAnchor),
        ])

        // Build menu dynamically
        modelPickerMenuButton.menu = UIMenu(children: [
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

        let modelPickerInteraction = UIContextMenuInteraction(delegate: self)
        modelPicker.addInteraction(modelPickerInteraction)

        let toolsToggleInteraction = UIContextMenuInteraction(delegate: self)
        toolsToggle.addInteraction(toolsToggleInteraction)

        heightPublisher.send(height)
        updateToolCallAvailability(false)
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
        let sizes = buttons.map(\.intrinsicContentSize)

        var anchorX: CGFloat = horizontalAdjustment
        for idx in 0 ..< buttons.count {
            let size = sizes[idx]
            assert(size.width > 0)
            assert(size.height > 0)
            buttons[idx].frame = .init(
                x: anchorX,
                y: 0,
                width: size.width,
                height: size.height
            )
            anchorX += size.width + 10
        }

        let lastOne = buttons.last?.frame.maxX ?? 0
        let contentSizeWidth = lastOne + horizontalAdjustment
        scrollView.contentSize = .init(width: contentSizeWidth, height: height)
    }

    func setModelName(_ name: String?) {
        defer { setNeedsLayout() }
        guard let name, !name.isEmpty else {
            modelPicker.titleLabel.text = NSLocalizedString("No Model", bundle: .module, comment: "")
            return
        }
        modelPicker.titleLabel.text = name
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
}

// MARK: - UIContextMenuInteractionDelegate

extension QuickSettingBar: UIContextMenuInteractionDelegate {
    public func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation _: CGPoint
    ) -> UIContextMenuConfiguration? {
        // Determine which view triggered the interaction
        let view = interaction.view

        if view === modelPicker {
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                guard let self else { return nil }
                let elements = delegate?.quickSettingBarBuildModelSelectionMenu() ?? []
                return elements.isEmpty ? nil : UIMenu(children: elements)
            }
        } else if view === toolsToggle {
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                guard let self else { return nil }
                let elements = delegate?.quickSettingBarBuildAlternativeToolsMenu() ?? []
                return elements.isEmpty ? nil : UIMenu(children: elements)
            }
        }

        return nil
    }

    public func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor _: UIContextMenuConfiguration,
        animator _: UIContextMenuInteractionAnimating?
    ) {
        if interaction.view === modelPicker {
            scrollToBeforeModelItem()
        }
    }
}
