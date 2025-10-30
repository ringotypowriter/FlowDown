//
//  CloudModelEditorController.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/26/25.
//

import AlertController
import Combine
import ConfigurableKit
import Foundation
import Storage
import UIKit

class CloudModelEditorController: StackScrollController {
    let identifier: CloudModel.ID

    init(identifier: CloudModel.ID) {
        self.identifier = identifier
        super.init(nibName: nil, bundle: nil)
        title = String(localized: "Edit Model")
    }

    #if targetEnvironment(macCatalyst)
        var documentPickerExportTempItems: [URL] = []
    #endif

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    var cancellables: Set<AnyCancellable> = .init()

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background

        navigationItem.rightBarButtonItem = .init(
            image: UIImage(systemName: "checkmark"),
            style: .done,
            target: self,
            action: #selector(checkTapped)
        )

        ModelManager.shared.cloudModels
            .removeDuplicates()
            .ensureMainThread()
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] values in
                guard let self, isVisible else { return }
                guard !values.contains(where: { $0.id == self.identifier }) else { return }
                navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)
    }

    @objc func checkTapped() {
        navigationController?.popViewController()
    }

    override func setupContentViews() {
        super.setupContentViews()

        let model = ModelManager.shared.cloudModel(identifier: identifier)

        if let comment = model?.comment, !comment.isEmpty {
            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView()
                    .with(header: "Comment")
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView()
                    .with(rawFooter: comment)
            )
            stackView.addArrangedSubview(SeparatorView())
        }

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: "Metadata")
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let endpointView = ConfigurableInfoView().setTapBlock { view in
            guard let model = ModelManager.shared.cloudModel(identifier: model?.id) else { return }
            let input = AlertInputViewController(
                title: String(localized: "Edit Endpoint"),
                message: String(localized: "This endpoint is used to send inference requests."),
                placeholder: "https://",
                text: model.endpoint.isEmpty ? "https://" : model.endpoint
            ) { output in
                ModelManager.shared.editCloudModel(identifier: model.id) {
                    $0.update(\.endpoint, to: output)
                }
                view.configure(value: output)
            }
            view.parentViewController?.present(input, animated: true)
        }
        endpointView.configure(icon: .init(systemName: "link"))
        endpointView.configure(title: "Inference Endpoint")
        endpointView.configure(description: "This endpoint is used to send inference requests.")
        var endpoint = model?.endpoint ?? ""
        if endpoint.isEmpty { endpoint = String(localized: "Not Configured") }
        endpointView.configure(value: endpoint)
        stackView.addArrangedSubviewWithMargin(endpointView)
        stackView.addArrangedSubview(SeparatorView())

        let tokenView = ConfigurableInfoView().setTapBlock { view in
            guard let model = ModelManager.shared.cloudModel(identifier: model?.id) else { return }
            let oldToken = model.token
            let input = AlertInputViewController(
                title: String(localized: "Edit Workgroup (Optional)"),
                message: String(localized: "This value will be added to the request to distinguish the workgroup on the remote. This part is optional, if not used, leave it blank."),
                placeholder: "workgroup-xxx",
                text: model.token
            ) { newToken in
                ModelManager.shared.editCloudModel(identifier: model.id) {
                    $0.update(\.token, to: newToken)
                }
                view.configure(value: newToken.isEmpty ? String(localized: "N/A") : String(localized: "Configured"))
                let list = ModelManager.shared.cloudModels.value.filter {
                    $0.endpoint == model.endpoint && $0.token == oldToken && $0.id != model.id
                }
                if !list.isEmpty {
                    let alert = AlertViewController(
                        title: String(localized: "Update All Models"),
                        message: String(localized: "Would you like to apply the new workgroup to all? This requires the inference endpoint and the old workgroup equal to the current editing.")
                    ) { context in
                        context.addAction(title: String(localized: "Cancel")) {
                            context.dispose()
                        }
                        context.addAction(title: String(localized: "Update All"), attribute: .dangerous) {
                            context.dispose {
                                for item in list {
                                    ModelManager.shared.editCloudModel(identifier: item.id) {
                                        $0.update(\.token, to: newToken)
                                    }
                                }
                            }
                        }
                    }
                    view.parentViewController?.present(alert, animated: true)
                }
            }
            view.parentViewController?.present(input, animated: true)
        }
        tokenView.configure(icon: .init(systemName: "square"))
        tokenView.configure(title: "Workgroup (Optional)")
        tokenView.configure(description: "This value will be added to the request to distinguish the workgroup on the remote.")
        tokenView.configure(
            value: (model?.token.isEmpty ?? true)
                ? String(localized: "N/A")
                : String(localized: "Configured")
        )

        stackView.addArrangedSubviewWithMargin(tokenView)
        stackView.addArrangedSubview(SeparatorView())

        // additional header
        let headerEditorView = ConfigurableInfoView().setTapBlock { view in
            guard let model = ModelManager.shared.cloudModel(identifier: model?.id) else { return }
            let jsonData = try? JSONSerialization.data(withJSONObject: model.headers, options: .prettyPrinted)
            var text = String(data: jsonData ?? Data(), encoding: .utf8) ?? ""
            if text.isEmpty { text = "{}" }
            let textEditor = JsonStringMapEditorController(text: text)
            textEditor.title = String(localized: "Edit Additional Header")
            textEditor.collectEditedContent { result in
                guard let object = try? JSONDecoder().decode([String: String].self, from: result.data(using: .utf8) ?? .init()) else {
                    return
                }
                ModelManager.shared.editCloudModel(identifier: model.id) {
                    $0.update(\.headers, to: object)
                }
                view.configure(value: object.isEmpty ? String(localized: "N/A") : String(localized: "Configured"))
            }
            view.parentViewController?.navigationController?.pushViewController(textEditor, animated: true)
        }
        headerEditorView.configure(icon: .init(systemName: "pencil"))
        headerEditorView.configure(title: "Additional Header (Optional)")
        headerEditorView.configure(description: "This value will be added to the request as additional header.")
        headerEditorView.configure(value: model?.headers.isEmpty ?? true ? String(localized: "N/A") : String(localized: "Configured"))

        stackView.addArrangedSubviewWithMargin(headerEditorView)
        stackView.addArrangedSubview(SeparatorView())

        let modelCanFetchList = !(model?.model_list_endpoint.isEmpty ?? true)
        let modelIdentifierView = ConfigurableInfoView().setTapBlock { [weak self] view in
            guard let self else { return }
            guard let model = ModelManager.shared.cloudModel(identifier: model?.id) else { return }
            let presentEditor = {
                let input = AlertInputViewController(
                    title: String(localized: "Edit Model Identifier"),
                    message: String(localized: "The name of the model to be used."),
                    placeholder: String(localized: "Model Identifier"),
                    text: model.model_identifier
                ) { output in
                    ModelManager.shared.editCloudModel(identifier: model.id) {
                        $0.update(\.model_identifier, to: output)
                    }
                    if output.isEmpty {
                        if modelCanFetchList {
                            view.configure(value: String(localized: "Not Configured (Tapped to Fetch)"))
                        } else {
                            view.configure(value: String(localized: "Not Configured"))
                        }
                    } else {
                        view.configure(value: output)
                    }
                }
                view.parentViewController?.present(input, animated: true)
            }
            if modelCanFetchList {
                func postProcessList(list: [String]) {
                    if list.isEmpty {
                        Indicator.present(
                            title: "Failed",
                            message: "No models found.",
                            preset: .error,
                            referencingView: view
                        )
                    } else {
                        var buildSections: [String: [(String, String)]] = [:]
                        for item in list {
                            var scope = ""
                            var trimmedName = item
                            if item.contains("/") {
                                scope = item.components(separatedBy: "/").first ?? ""
                                trimmedName = trimmedName.replacingOccurrences(of: scope + "/", with: "")
                            }
                            buildSections[scope, default: []].append((trimmedName, item))
                        }

                        var children: [UIMenu] = []
                        var options: UIMenu.Options = []
                        if list.count < 10 { options.insert(.displayInline) }
                        for key in buildSections.keys.sorted() {
                            let items = buildSections[key] ?? []
                            guard !items.isEmpty else { continue }
                            let key = key.isEmpty ? String(localized: "Ungrouped") : key
                            children.append(UIMenu(
                                title: key,
                                image: UIImage(systemName: "folder"),
                                options: options,
                                children: items.map { item in
                                    UIAction(title: item.0, image: .modelCloud) { _ in
                                        var modelIdentifier = item.1
                                        ModelManager.shared.editCloudModel(identifier: model.id) {
                                            $0.update(\.model_identifier, to: modelIdentifier)
                                        }
                                        if modelIdentifier.isEmpty {
                                            if modelCanFetchList {
                                                modelIdentifier = String(localized: "Not Configured (Tapped to Fetch)")
                                            } else {
                                                modelIdentifier = String(localized: "Not Configured")
                                            }
                                        }
                                        view.configure(value: modelIdentifier)
                                    }
                                }
                            ))
                        }
                        let menu = UIMenu(
                            title: String(localized: "Model List"),
                            children: children.count > 1 ? children : children.first?.children ?? []
                        )
                        view.present(menu: menu, anchorPoint: .init(x: view.bounds.maxX, y: view.bounds.maxY))
                    }
                }
                let fetchFromServer = {
                    view.isUserInteractionEnabled = false
                    view.alpha = 0.5
                    Indicator.progress(
                        title: "Fetching Model List",
                        controller: self
                    ) { completionHandler in
                        let list = await withCheckedContinuation { continuation in
                            ModelManager.shared.fetchModelList(identifier: model.id) { list in
                                continuation.resume(returning: list)
                            }
                        }
                        await completionHandler {
                            view.isUserInteractionEnabled = true
                            view.alpha = 1
                            postProcessList(list: list)
                        }
                    }
                }

                view.present(
                    menu: .init(title: String(localized: "Edit Model Identifier"), children: [
                        UIAction(
                            title: String(localized: "Edit"),
                            image: UIImage(systemName: "character.cursor.ibeam")
                        ) { _ in presentEditor() },
                        UIAction(
                            title: String(localized: "Fetch from Server"),
                            image: UIImage(systemName: "icloud.and.arrow.down")
                        ) { _ in fetchFromServer() },
                    ]),
                    anchorPoint: .init(x: view.bounds.maxX, y: view.bounds.maxY)
                )
            } else {
                presentEditor()
            }
        }
        modelIdentifierView.configure(icon: .init(systemName: "circle"))
        modelIdentifierView.configure(title: "Model Identifier")
        modelIdentifierView.configure(description: "The name of the model to be used.")
        var modelIdentifier = model?.model_identifier ?? ""
        if modelIdentifier.isEmpty {
            if modelCanFetchList {
                modelIdentifier = String(localized: "Not Configured (Tapped to Fetch)")
            } else {
                modelIdentifier = String(localized: "Not Configured")
            }
        }
        modelIdentifierView.configure(value: modelIdentifier)
        stackView.addArrangedSubviewWithMargin(modelIdentifierView)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: "The endpoint needs to be written in full path to work. The path is usually /v1/chat/completions.")
        ) {
            $0.top /= 2
            $0.bottom = 0
        }
        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: "After setting up, click the model identifier to edit it or retrieve a list from the server.")
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: "Capabilities")
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        for cap in ModelCapabilities.allCases {
            let view = ConfigurableToggleActionView()
            view.boolValue = model?.capabilities.contains(cap) ?? false
            view.actionBlock = { [weak self] value in
                guard let self else { return }
                ModelManager.shared.editCloudModel(identifier: identifier) { model in
                    var capabilities = model.capabilities
                    if value {
                        capabilities.insert(cap)
                    } else {
                        capabilities.remove(cap)
                    }
                    model.assign(\.capabilities, to: capabilities)
                }
            }
            view.configure(icon: .init(systemName: cap.icon))
            view.configure(title: cap.title)
            view.configure(description: cap.description)
            stackView.addArrangedSubviewWithMargin(view)
            stackView.addArrangedSubview(SeparatorView())
        }

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: "We cannot determine whether this model includes additional capabilities. However, if supported, features such as visual recognition can be enabled manually here. Please note that if the model does not actually support these capabilities, attempting to enable them may result in errors.")
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: "Context")
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let contextListViewAnnotation = ConfigurableInfoView()
        contextListViewAnnotation.configure(icon: .init(systemName: "list.bullet"))
        contextListViewAnnotation.configure(title: "Context Length")
        contextListViewAnnotation.configure(description: "The context length for inference refers to the amount of information the model can retain and process at a given time. This context serves as the model’s memory, allowing it to understand and generate responses based on prior input.")
        let value = model?.context.title ?? String(localized: "Not Configured")
        contextListViewAnnotation.configure(value: value)
        contextListViewAnnotation.setTapBlock { view in
            let children = ModelContextLength.allCases.map { item in
                UIAction(
                    title: item.title,
                    image: UIImage(systemName: item.icon)
                ) { _ in
                    ModelManager.shared.editCloudModel(identifier: model?.id) {
                        $0.update(\.context, to: item)
                    }
                    view.configure(value: item.title)
                }
            }
            view.present(
                menu: .init(title: String(localized: "Context Length"), children: children),
                anchorPoint: .init(x: view.bounds.maxX, y: view.bounds.maxY)
            )
        }
        stackView.addArrangedSubviewWithMargin(contextListViewAnnotation)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: "We cannot determine the context length supported by the model. Please choose the correct configuration here. Configuring a context length smaller than the capacity can save costs. A context that is too long may be truncated during inference.")
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: "Parameters")
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let nameView = ConfigurableInfoView().setTapBlock { view in
            guard let model = ModelManager.shared.cloudModel(identifier: model?.id) else { return }
            let input = AlertInputViewController(
                title: String(localized: "Edit Model Name"),
                message: String(localized: "Custom display name for this model."),
                placeholder: String(localized: "Nickname (Optional)"),
                text: model.name
            ) { output in
                ModelManager.shared.editCloudModel(identifier: model.id) {
                    $0.update(\.name, to: output)
                }
                if output.isEmpty {
                    view.configure(value: String(localized: "Not Configured"))
                } else {
                    view.configure(value: output)
                }
            }
            view.parentViewController?.present(input, animated: true)
        }
        nameView.configure(icon: .init(systemName: "tag"))
        nameView.configure(title: "Nickname (Optional)")
        nameView.configure(description: "Custom display name for this model.")
        var nameValue = model?.name ?? ""
        if nameValue.isEmpty { nameValue = String(localized: "Not Configured") }
        nameView.configure(value: nameValue)
        stackView.addArrangedSubviewWithMargin(nameView)
        stackView.addArrangedSubview(SeparatorView())

        let temperatureView = ConfigurableInfoView().setTapBlock { [weak self] view in
            guard let self,
                  let model = ModelManager.shared.cloudModel(identifier: identifier)
            else { return }

            func updateDisplay(_ preference: ModelTemperaturePreference, override: Double?) {
                view.configure(value: ModelManager.shared.displayTextForTemperature(
                    preference: preference,
                    override: override
                ))
            }

            var actions: [UIMenuElement] = []

            let inheritAction = UIAction(
                title: String(localized: "Inference default"),
                image: UIImage(systemName: "circle.dashed")
            ) { _ in
                ModelManager.shared.editCloudModel(identifier: model.id) { item in
                    item.update(\.temperature_preference, to: .inherit)
                    item.update(\.temperature_override, to: nil)
                }
                updateDisplay(.inherit, override: nil)
            }
            inheritAction.state = model.temperature_preference == .inherit ? .on : .off
            actions.append(inheritAction)

            for preset in ModelManager.shared.temperaturePresets {
                let action = UIAction(
                    title: preset.title,
                    image: UIImage(systemName: preset.icon)
                ) { _ in
                    ModelManager.shared.editCloudModel(identifier: model.id) { item in
                        item.update(\.temperature_preference, to: .custom)
                        item.update(\.temperature_override, to: preset.value)
                    }
                    updateDisplay(.custom, override: preset.value)
                }
                if model.temperature_preference == .custom,
                   let value = model.temperature_override,
                   abs(value - preset.value) < 0.0001
                {
                    action.state = .on
                }
                actions.append(action)
            }

            let menu = UIMenu(title: String(localized: "Imagination"), children: actions)
            view.present(
                menu: menu,
                anchorPoint: CGPoint(x: view.bounds.maxX, y: view.bounds.maxY)
            )
        }
        temperatureView.configure(icon: .init(systemName: "sparkles"))
        temperatureView.configure(title: "Imagination")
        temperatureView.configure(description: "This parameter can be used to control the personality of the model. The more imaginative, the more unstable the output. This parameter is also known as temperature.")
        let temperatureDisplay = ModelManager.shared.displayTextForTemperature(
            preference: model?.temperature_preference ?? .inherit,
            override: model?.temperature_override
        )
        temperatureView.configure(value: temperatureDisplay)
        stackView.addArrangedSubviewWithMargin(temperatureView)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: "Verification")
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        var verifyButtonReader: UIView?
        let verifyButton = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            guard let model = ModelManager.shared.cloudModel(identifier: identifier) else { return }
            verifyButtonReader?.isUserInteractionEnabled = false
            verifyButtonReader?.alpha = 0.5
            Indicator.progress(
                title: "Verifying Model",
                controller: self
            ) { completionHandler in
                let result = await withCheckedContinuation { continuation in
                    ModelManager.shared.testCloudModel(model) { result in
                        continuation.resume(returning: result)
                    }
                }
                try result.get()
                await completionHandler {
                    verifyButtonReader?.isUserInteractionEnabled = true
                    verifyButtonReader?.alpha = 1
                    Indicator.present(
                        title: "Model Verified",
                        referencingView: self.view
                    )
                }
            }
        }
        verifyButton.configure(icon: UIImage(systemName: "testtube.2"))
        verifyButton.configure(title: "Verify Model")
        verifyButton.configure(description: "Verify the model by sending a test request.")
        stackView.addArrangedSubviewWithMargin(verifyButton)
        verifyButtonReader = verifyButton.superview
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: "Verification process will send a standard inference request to the inference node and verify the returned status code. This process requires the server to return status code: 200. The verification process may incur standard charges from your service provider.")
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: "Shortcuts")
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        var exportOptionReader: UIView?
        let exportOption = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            guard let model = ModelManager.shared.cloudModel(identifier: identifier) else { return }
            let tempFileDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("DisposableResources")
                .appendingPathComponent(UUID().uuidString)
            let tempFile = tempFileDir
                .appendingPathComponent("Export-\(model.modelDisplayName.sanitizedFileName)\(model.auxiliaryIdentifier)")
                .appendingPathExtension(ModelManager.flowdownModelConfigurationExtension)
            try? FileManager.default.createDirectory(at: tempFileDir, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: tempFile.path, contents: nil)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            try? encoder.encode(model).write(to: tempFile, options: .atomic)
            DisposableExporter(deletableItem: tempFile, title: "Export Model").run(anchor: exportOptionReader ?? view)
        }
        exportOptionReader = exportOption
        exportOption.configure(icon: UIImage(systemName: "square.and.arrow.up"))
        exportOption.configure(title: "Export Model")
        exportOption.configure(description: "Export this model to share with others.")
        stackView.addArrangedSubviewWithMargin(exportOption)
        stackView.addArrangedSubview(SeparatorView())

        let duplicateModel = ConfigurableActionView { [weak self] _ in
            guard let nav = self?.navigationController else { return }
            let newIdentifier = UUID().uuidString
            ModelManager.shared.editCloudModel(identifier: self?.identifier) {
                $0.update(\.objectId, to: newIdentifier)
                $0.update(\.model_identifier, to: "")
                $0.update(\.creation, to: $0.modified)
            }
            guard let newModel = ModelManager.shared.cloudModel(identifier: newIdentifier) else { return }
            assert(newModel.objectId == newIdentifier)
            nav.popViewController(animated: true) {
                let editor = CloudModelEditorController(identifier: newModel.id)
                nav.pushViewController(editor, animated: true)
            }
        }
        duplicateModel.configure(icon: UIImage(systemName: "doc.on.doc"))
        duplicateModel.configure(title: "Duplicate")
        duplicateModel.configure(description: "Create a new model by copying the current configuration.")
        stackView.addArrangedSubviewWithMargin(duplicateModel)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: "After creating a copy, you can choose a new model. This is useful if the endpoint provides multiple models.")
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: "Management")
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())
        let deleteAction = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            deleteModel()
        }
        deleteAction.configure(icon: UIImage(systemName: "trash"))
        deleteAction.configure(title: "Delete Model")
        deleteAction.configure(description: "Delete this model from your device.")
        deleteAction.titleLabel.textColor = .systemRed
        deleteAction.iconView.tintColor = .systemRed
        deleteAction.descriptionLabel.textColor = .systemRed
        deleteAction.imageView.tintColor = .systemRed
        stackView.addArrangedSubviewWithMargin(deleteAction)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(UIView())

        let icon = UIImageView().with {
            $0.image = .modelCloud
            $0.tintColor = .separator
            $0.contentMode = .scaleAspectFit
            $0.snp.makeConstraints { make in
                make.width.height.equalTo(24)
            }
        }
        stackView.addArrangedSubviewWithMargin(icon) { $0.bottom /= 2 }

        let footer = UILabel().with {
            $0.font = .rounded(
                ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                weight: .regular
            )
            $0.textColor = .label.withAlphaComponent(0.25)
            $0.numberOfLines = 0
            $0.text = identifier
            $0.textAlignment = .center
        }
        stackView.addArrangedSubviewWithMargin(footer) { $0.top /= 2 }
        stackView.addArrangedSubviewWithMargin(UIView())
    }

    @objc func deleteModel() {
        let alert = AlertViewController(
            title: String(localized: "Delete Model"),
            message: String(localized: "Are you sure you want to delete this model? This action cannot be undone.")
        ) { context in
            context.addAction(title: String(localized: "Cancel")) {
                context.dispose()
            }
            context.addAction(title: String(localized: "Delete"), attribute: .dangerous) {
                context.dispose { [weak self] in
                    guard let self else { return }
                    ModelManager.shared.removeCloudModel(identifier: identifier)
                    navigationController?.popViewController(animated: true)
                }
            }
        }
        present(alert, animated: true)
    }
}

#if targetEnvironment(macCatalyst)
    extension CloudModelEditorController: UIDocumentPickerDelegate {
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            for cleanableURL in documentPickerExportTempItems {
                try? FileManager.default.removeItem(at: cleanableURL)
            }
            documentPickerExportTempItems.removeAll()
        }
    }
#endif
