//
//  InferenceController.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/2/25.
//

import AlertController
import ConfigurableKit
import MLX
import UIKit

extension SettingController.SettingContent {
    class InferenceController: StackScrollController {
        init() {
            super.init(nibName: nil, bundle: nil)
            title = String(localized: "Inference")
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .background
        }

        private let defaultConversationModel = ConfigurableInfoView().with {
            $0.configure(icon: UIImage(systemName: "quote.bubble"))
            $0.configure(title: String(localized: "Default Model"))
            $0.configure(description: String(localized: "The model used for new conversations."))
        }

        private let defaultAuxiliaryModelAlignWithChatModel = ConfigurableBooleanBlockView(storage: .init(
            key: "InferenceController.defaultAuxiliaryModelAlignWithChatModel",
            defaultValue: true,
            storage: UserDefaultKeyValueStorage(suite: .standard)
        )).with {
            $0.configure(icon: UIImage(systemName: "quote.bubble"))
            $0.configure(title: String(localized: "Use Chat Model"))
            $0.configure(description: String(localized: "Utilize the current chat model to assist with auxiliary tasks."))
        }

        private let defaultAuxiliaryModel = ConfigurableInfoView().with {
            $0.configure(icon: UIImage(systemName: "ellipsis.bubble"))
            $0.configure(title: String(localized: "Task Model"))
            $0.configure(description: String(localized: "The model is used for auxiliary tasks such as generating conversation titles and web search keywords."))
        }

        private let defaultAuxiliaryVisualModel = ConfigurableInfoView().with {
            $0.configure(icon: UIImage(systemName: "eye"))
            $0.configure(title: String(localized: "Auxiliary Visual Model"))
            $0.configure(description: String(localized: "The model is used for visual input when the current model does not support it. It will extract information before using the current model for inference."))
        }

        private let skipVisualAssessmentView = ConfigurableObject(
            icon: "arrowshape.zigzag.forward",
            title: String(localized: "Skip Recognization If Possible"),
            explain: String(localized: "Skip the visual assessment process when the conversation model natively supports visual input. Enabling this option can improve the efficiency when using visual models, but if you switch to a model that does not support visual input after using it, the image information will be lost."),
            key: "",
            defaultValue: true,
            annotation: .boolean
        )
        .whenValueChange(type: Bool.self) { newValue in
            guard let newValue else {
                assertionFailure()
                return
            }
            ModelManager.shared.defaultModelForAuxiliaryVisualTaskSkipIfPossible = newValue
        }
        .createView()

        override func setupContentViews() {
            super.setupContentViews()

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Conversation")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(defaultConversationModel)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Task Model")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(defaultAuxiliaryModelAlignWithChatModel)
            stackView.addArrangedSubview(SeparatorView())
            stackView.addArrangedSubviewWithMargin(defaultAuxiliaryModel)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "Using a local or mini model for this purpose will lower overall costs while maintaining a consistent experience.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Visual Assessment")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(defaultAuxiliaryVisualModel)
            stackView.addArrangedSubview(SeparatorView())
            stackView.addArrangedSubviewWithMargin(skipVisualAssessmentView)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "While using a visual assessment model may result in some loss of information, it can make tasks requiring visual input possible.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            defer { updateDefaultModelInfo() }

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: String(localized: "Parameters")
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(ModelManager.defaultPromptConfigurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(ModelManager.extraPromptConfigurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(ModelManager.temperatureConfigurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "The above parameters will be applied to all conversations.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "MLX"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(MLX.GPU.configurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: String(localized: "MLX is only available on Apple Silicon devices with Metal 3 support.")
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            updateDefaultModelInfo()
        }

        func updateDefaultModelInfo() {
            ModelManager.shared.checkDefaultModels()

            let defConvId = ModelManager.ModelIdentifier.defaultModelForConversation
            if let localModel = ModelManager.shared.localModel(identifier: defConvId) {
                defaultConversationModel.configure(value: localModel.model_identifier)
            } else if let cloudModel = ModelManager.shared.cloudModel(identifier: defConvId) {
                defaultConversationModel.configure(value: cloudModel.modelFullName)
            } else {
                defaultConversationModel.configure(value: String(localized: "Not Configured"))
            }

            defaultConversationModel.setTapBlock { [weak self] view in
                ModelManager.shared.presentModelSelectionMenu(
                    anchoringView: view.valueLabel,
                    currentSelection: ModelManager.ModelIdentifier.defaultModelForConversation,
                    allowSelectionWithNone: true
                ) { [weak self] identifier in
                    ModelManager.ModelIdentifier.defaultModelForConversation = identifier
                    self?.updateDefaultModelInfo()
                }
            }

            let devAuxId = ModelManager.ModelIdentifier.defaultModelForAuxiliaryTask
            if let localModel = ModelManager.shared.localModel(identifier: devAuxId) {
                defaultAuxiliaryModel.configure(value: localModel.model_identifier)
            } else if let cloudModel = ModelManager.shared.cloudModel(identifier: devAuxId) {
                defaultAuxiliaryModel.configure(value: cloudModel.modelFullName)
            } else {
                defaultAuxiliaryModel.configure(value: String(localized: "Not Configured"))
            }

            defaultAuxiliaryModel.setTapBlock { [weak self] view in
                ModelManager.shared.presentModelSelectionMenu(
                    anchoringView: view.valueLabel,
                    currentSelection: ModelManager.ModelIdentifier.defaultModelForAuxiliaryTask,
                    allowSelectionWithNone: true
                ) { [weak self] identifier in
                    ModelManager.ModelIdentifier.defaultModelForAuxiliaryTask = identifier
                    self?.updateDefaultModelInfo()
                }
            }

            if defaultAuxiliaryModelAlignWithChatModel.boolValue {
                defaultAuxiliaryModel.alpha = 0.5
                defaultAuxiliaryModel.isUserInteractionEnabled = false
            } else {
                defaultAuxiliaryModel.alpha = 1.0
                defaultAuxiliaryModel.isUserInteractionEnabled = true
            }

            defaultAuxiliaryModelAlignWithChatModel.onUpdated = { [weak self] value in
                ModelManager.ModelIdentifier.defaultModelForAuxiliaryTaskWillUseCurrentChatModel = value
                self?.updateDefaultModelInfo()
            }

            let devAuxVisualId = ModelManager.ModelIdentifier.defaultModelForAuxiliaryVisualTask
            if let localModel = ModelManager.shared.localModel(identifier: devAuxVisualId) {
                defaultAuxiliaryVisualModel.configure(value: localModel.model_identifier)
            } else if let cloudModel = ModelManager.shared.cloudModel(identifier: devAuxVisualId) {
                defaultAuxiliaryVisualModel.configure(value: cloudModel.modelFullName)
            } else {
                defaultAuxiliaryVisualModel.configure(value: String(localized: "Not Configured"))
            }

            defaultAuxiliaryVisualModel.setTapBlock { [weak self] view in
                ModelManager.shared.presentModelSelectionMenu(
                    anchoringView: view.valueLabel,
                    currentSelection: ModelManager.ModelIdentifier.defaultModelForAuxiliaryVisualTask,
                    requiresCapabilities: [.visual],
                    allowSelectionWithNone: true
                ) { [weak self] identifier in
                    ModelManager.ModelIdentifier.defaultModelForAuxiliaryVisualTask = identifier
                    self?.updateDefaultModelInfo()
                }
            }
        }
    }
}

private class ConfigurableBooleanBlockView: ConfigurableBooleanView {
    var onUpdated: ((Bool) -> Void)?

    override func valueChanged() {
        super.valueChanged()
        onUpdated?(boolValue)
    }
}
