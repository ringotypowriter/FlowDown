//
//  ChatView+Delegates.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/31/25.
//

import AlertController
import ChatClientKit
import ConfigurableKit
import OSLog
import RegexBuilder
import RichEditor
import ScrubberKit
import Storage
import UIKit

extension ChatView: RichEditorView.Delegate {
    func onRichEditorSubmit(object: RichEditorView.Object, completion: @escaping (Bool) -> Void) {
        guard let conversationID = conversationIdentifier,
              let currentMessageListView
        else {
            assertionFailure()
            return
        }

        guard let modelID = modelIdentifier(), !modelID.isEmpty else {
            if ModelManager.shared.localModels.value.isEmpty,
               ModelManager.shared.cloudModels.value.isEmpty
            {
                let alert = AlertViewController(
                    title: String(localized: "Error"),
                    message: String(localized: "You need to add a model to use.")
                ) { context in
                    context.addAction(title: String(localized: "Cancel")) {
                        context.dispose()
                    }
                    context.addAction(title: String(localized: "Add Model"), attribute: .dangerous) {
                        context.dispose {
                            SettingController.setNextEntryPage(.modelManagement)
                            let setting = SettingController()
                            self.parentViewController?.present(setting, animated: true)
                        }
                    }
                }
                parentViewController?.present(alert, animated: true)
            } else {
                let alert = AlertViewController(
                    title: String(localized: "Error"),
                    message: String(localized: "You need to select a model to use.")
                ) { context in
                    context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                        context.dispose { [weak self] in
                            self?.editor.scheduleModelSelection()
                        }
                    }
                }
                parentViewController?.present(alert, animated: true)
            }
            completion(false)
            return
        }

        let session = ConversationSessionManager.shared.session(for: conversationID)
        offloadModelsToSession(modelIdentifier: modelIdentifier())
        if case let .bool(value) = object.options[.browsing], value {
            guard let auxModel = session.models.auxiliary,
                  !auxModel.isEmpty
            else {
                let alert = AlertViewController(
                    title: String(localized: "Error"),
                    message: String(localized: "A tool model is required for browsing.")
                ) { context in
                    context.addAction(title: String(localized: "Close")) {
                        context.dispose()
                    }
                    context.addAction(title: String(localized: "Configure"), attribute: .dangerous) {
                        context.dispose { [weak self] in
                            SettingController.setNextEntryPage(.inference)
                            let setting = SettingController()
                            self?.parentViewController?.present(setting, animated: true)
                        }
                    }
                }
                parentViewController?.present(alert, animated: true)
                completion(false)
                return
            }
        }

        let shouldHaveVisualModel = object.attachments.contains { $0.type == .image }
        if shouldHaveVisualModel {
            let currentModelCanSee = ModelManager.shared.modelCapabilities(identifier: modelID)
                .contains(.visual)
            let auxModelExists = !(session.models.visualAuxiliary?.isEmpty ?? true)
            guard currentModelCanSee || auxModelExists else {
                let alert = AlertViewController(
                    title: String(localized: "Error"),
                    message: String(localized: "A visual model is required for image attachments.")
                ) { context in
                    context.addAction(title: String(localized: "Close")) {
                        context.dispose()
                    }
                    context.addAction(title: String(localized: "Configure"), attribute: .dangerous) {
                        context.dispose { [weak self] in
                            SettingController.setNextEntryPage(.inference)
                            let setting = SettingController()
                            SettingController.setNextEntryPage(.modelManagement)
                            self?.parentViewController?.present(setting, animated: true)
                        }
                    }
                }
                parentViewController?.present(alert, animated: true)
                completion(false)
                return
            }
        }

        completion(true)

        session.doInfere(
            modelID: modelID,
            currentMessageListView: currentMessageListView,
            inputObject: object
        ) {}

        #if targetEnvironment(macCatalyst)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.editor.focus()
            }
        #endif
    }

    func onRichEditorError(_ error: String) {
        Indicator.present(
            title: error,
            preset: .error,
            haptic: .error,
            referencingView: self
        )
    }

    func onRichEditorTogglesUpdate(object: RichEditor.RichEditorView.Object) {
        _ = object
    }

    func onRichEditorRequestObjectForRestore() -> RichEditor.RichEditorView.Object? {
        guard let conversationIdentifier else { return nil }
        return ConversationManager.shared.getRichEditorObject(identifier: conversationIdentifier)
    }

    func onRichEditorUpdateObject(object: RichEditor.RichEditorView.Object) {
        guard let conversationIdentifier else { return }
        ConversationManager.shared.setRichEditorObject(identifier: conversationIdentifier, object)
        offloadModelsToSession(modelIdentifier: modelIdentifier())
    }

    func modelIdentifier() -> String? {
        if let id = ConversationManager.shared.conversation(
            identifier: conversationIdentifier
        )?.modelId {
            return id
        }
        return ModelManager.ModelIdentifier.defaultModelForConversation
    }

    func onRichEditorRequestCurrentModelName() -> String? {
        guard let modelIdentifier = modelIdentifier() else { return nil }
        if #available(iOS 26.0, macCatalyst 26.0, *), modelIdentifier == AppleIntelligenceModel.shared.modelIdentifier {
            return AppleIntelligenceModel.shared.modelDisplayName
        }
        if let localModel = ModelManager.shared.localModel(identifier: modelIdentifier) {
            switch editorModelNameStyle {
            case .full: return localModel.model_identifier
            case .trimmed: return localModel.modelDisplayName
            case .none: return "👌"
            }
        } else if let cloudModel = ModelManager.shared.cloudModel(identifier: modelIdentifier) {
            switch editorModelNameStyle {
            case .full: return cloudModel.modelFullName
            case .trimmed: return cloudModel.modelDisplayName
            case .none: return "👌"
            }
        }
        return nil
    }

    func onRichEditorRequestCurrentModelIdentifier() -> String? {
        modelIdentifier()
    }

    func onRichEditorPickModel(anchor: UIView, completion: @escaping () -> Void) {
        guard let conversationIdentifier else { return }
        let modelIdentifier = ConversationManager.shared.conversation(
            identifier: conversationIdentifier
        )?.modelId
        ModelManager.shared.presentModelSelectionMenu(
            anchoringView: anchor,
            currentSelection: modelIdentifier
        ) { modelIdentifier in
            ConversationManager.shared.editConversation(identifier: conversationIdentifier) { conv in
                conv.modelId = modelIdentifier
            }
            if self.editorApplyModelToDefault {
                ModelManager.ModelIdentifier.defaultModelForConversation = modelIdentifier
            }
            completion()
        }
    }

    func onRichEditorShowAlternativeModelMenu(anchor: UIView) {
        let isAppleIntelligence: Bool = {
            guard let id = modelIdentifier(), !id.isEmpty else { return false }
            if #available(iOS 26.0, macCatalyst 26.0, *) {
                return id == AppleIntelligenceModel.shared.modelIdentifier
            }
            return false
        }()
        let menu = UIMenu(title: String(localized: "Shortcuts"), children: [
            { () -> UIAction? in
                guard !isAppleIntelligence, let id = modelIdentifier(), !id.isEmpty else { return nil }
                return UIAction(title: String(localized: "Edit Model")) { [weak self] _ in
                    SettingController.setNextEntryPage(.modelEditor(model: id))
                    let settingController = SettingController()
                    self?.parentViewController?.present(settingController, animated: true)
                }
            }(),
            UIAction(title: String(localized: "Inference Settings")) { [weak self] _ in
                SettingController.setNextEntryPage(.inference)
                let settingController = SettingController()
                self?.parentViewController?.present(settingController, animated: true)
            },
        ].compactMap(\.self))
        anchor.present(menu: menu)
    }

    func onRichEditorShowAlternativeToolsMenu(anchor: UIView) {
        let mcpServers = MCPService.shared.servers.value

        var toolMenuItems: [UIMenuElement] = []

        func createAction(for tools: [ModelTool]) -> [UIAction] {
            tools.map { tool in
                UIAction(
                    title: tool.interfaceName,
                    image: .init(systemName: tool.interfaceIcon),
                    attributes: [.keepsMenuPresented],
                    state: tool.isEnabled ? .on : .off
                ) { action in
                    tool.isEnabled.toggle()
                    action.state = tool.isEnabled ? .on : .off
                }
            }
        }

        toolMenuItems.append(UIMenu(
            title: String(localized: "Built-in Tools"),
            options: [.displayInline],
            children: createAction(for: ModelToolsManager.shared.configurableTools)
        ))
        toolMenuItems.append(UIMenu(
            title: String(localized: "Memory Tools"),
//            options: [.displayInline],
            children: createAction(for: ModelToolsManager.shared.tools.filter { tool in
                false
                    || tool is MTStoreMemoryTool
                    || tool is MTRecallMemoryTool
                    || tool is MTListMemoriesTool
                    || tool is MTUpdateMemoryTool
                    || tool is MTDeleteMemoryTool
            })
        ))

        if !mcpServers.isEmpty {
            let mcpServersMenu = UIMenu(
                title: String(localized: "MCP Servers"),
                options: mcpServers.count < 5 ? [.displayInline] : [],
                children: mcpServers.map { server in
                    let name = server.name.isEmpty
                        ? URL(string: server.endpoint)?.host ?? String(localized: "Unknown Server")
                        : server.name
                    return UIAction(
                        title: name,
                        image: UIImage(systemName: "server.rack"),
                        attributes: [.keepsMenuPresented],
                        state: server.isEnabled ? .on : .off
                    ) { action in
                        MCPService.shared.edit(identifier: server.id) { server in
                            server.isEnabled.toggle()
                            action.state = server.isEnabled ? .on : .off
                        }
                    }
                }
            )
            toolMenuItems.append(mcpServersMenu)
        }

        let settingsMenu = UIMenu(
            title: String(localized: "Shortcuts"),
            children: [
                UIAction(title: String(localized: "MCP Settings")) { [weak self] _ in
                    SettingController.setNextEntryPage(.mcp)
                    let settingController = SettingController()
                    self?.parentViewController?.present(settingController, animated: true)
                },
                UIAction(title: String(localized: "Tools Settings")) { [weak self] _ in
                    SettingController.setNextEntryPage(.tools)
                    let settingController = SettingController()
                    self?.parentViewController?.present(settingController, animated: true)
                },
            ]
        )
        toolMenuItems.append(settingsMenu)

        anchor.present(menu: .init(options: [.displayInline], children: toolMenuItems))
    }

    func onRichEditorCheckIfModelSupportsToolCall(_ modelIdentifier: String) -> Bool {
        ModelManager.shared.modelCapabilities(identifier: modelIdentifier).contains(.tool)
    }

    func onSelectLocalModel(_ model: LocalModel) {
        onSelectModel(model_id: model.id)
    }

    func onSelectCloudModel(_ model: CloudModel) {
        onSelectModel(model_id: model.id)
    }

    private func onSelectModel(model_id: String) {
        offloadModelsToSession(modelIdentifier: model_id)
    }

    func offloadModelsToSession(modelIdentifier: ModelManager.ModelIdentifier?) {
        guard let conversationIdentifier else {
            assertionFailure()
            return
        }
        let session = ConversationSessionManager.shared.session(for: conversationIdentifier)

        session.models.chat = modelIdentifier ?? .defaultModelForConversation
        if ModelManager.ModelIdentifier.defaultModelForAuxiliaryTaskWillUseCurrentChatModel {
            session.models.auxiliary = session.models.chat ?? .defaultModelForAuxiliaryTask
        } else {
            session.models.auxiliary = ModelManager.ModelIdentifier.defaultModelForAuxiliaryTask
        }
        session.models.visualAuxiliary = ModelManager.ModelIdentifier.defaultModelForAuxiliaryVisualTask

        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(printModelInfomation), with: nil, afterDelay: 0.25)
    }

    @objc func printModelInfomation() {
        guard let conversationIdentifier else { return }
        let session = ConversationSessionManager.shared.session(for: conversationIdentifier)
        Logger.model.infoFile("offloaded model to session: \(conversationIdentifier)")
        Logger.model.debugFile("chat: \(ModelManager.shared.modelName(identifier: session.models.chat))")
        Logger.model.debugFile("task: \(ModelManager.shared.modelName(identifier: session.models.auxiliary))")
        Logger.model.debugFile("view: \(ModelManager.shared.modelName(identifier: session.models.visualAuxiliary))")
    }
}
