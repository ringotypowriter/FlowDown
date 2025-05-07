//
//  LocalModelEditorController.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/26/25.
//

import AlertController
import Combine
import ConfigurableKit
import MLX
import Storage
import UIKit

extension ModelCapabilities {
    static var localModelEditable: [ModelCapabilities] = [
//        .visual, // currently broken due to mlx-swift-libraries broken
    ]
}

private let dateFormatter: DateFormatter = .init().with {
    $0.dateStyle = .short
    $0.timeStyle = .short
}

class LocalModelEditorController: StackScrollController {
    let identifier: LocalModel.ID
    init(identifier: LocalModel.ID) {
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

        ModelManager.shared.localModels
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

    @objc func deleteTapped() {
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
                    ModelManager.shared.removeLocalModel(identifier: identifier)
                    navigationController?.popViewController(animated: true)
                }
            }
        }
        present(alert, animated: true)
    }

    override func setupContentViews() {
        super.setupContentViews()

        let model = ModelManager.shared.localModel(identifier: identifier)

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Metadata"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let idView = ConfigurableInfoView().setTapBlock { view in
            view.present(menu: .init(
                title: String(localized: "Copy"),
                children: [UIAction(
                    title: String(localized: "Identifier"),
                    image: UIImage(systemName: "person.crop.square.filled.and.at.rectangle")
                ) { _ in
                    UIPasteboard.general.string = model?.model_identifier
                    Indicator.present(
                        title: String(localized: "Copied"),
                        referencingView: view
                    )
                }]
            ), anchorPoint: .init(x: view.bounds.maxX, y: view.bounds.maxY))
        }
        idView.configure(icon: .init(systemName: "person.crop.square.filled.and.at.rectangle"))
        idView.configure(title: String(localized: "Identifier"))
        idView.configure(description: String(localized: "Unique identifier of this model."))
        idView.configure(value: model?.model_identifier ?? "")
        stackView.addArrangedSubviewWithMargin(idView)
        stackView.addArrangedSubview(SeparatorView())

        let sizeView = ConfigurableInfoView().setTapBlock { view in
            view.present(menu: .init(children: [UIAction(
                title: String(localized: "Calibrate Size"),
                image: UIImage(systemName: "internaldrive")
            ) { _ in
                guard let identifier = model?.id else { return }
                let newSize = ModelManager.shared.calibrateLocalModelSize(identifier: identifier)
                view.configure(value: ByteCountFormatter.string(fromByteCount: Int64(newSize), countStyle: .file))
            }]
            ), anchorPoint: .init(x: view.bounds.maxX, y: view.bounds.maxY))
        }
        sizeView.configure(icon: .init(systemName: "internaldrive"))
        sizeView.configure(title: String(localized: "Size"))
        sizeView.configure(description: String(localized: "Model size on your local disk."))
        sizeView.configure(value: ByteCountFormatter.string(fromByteCount: Int64(model?.size ?? 0), countStyle: .file))
        stackView.addArrangedSubviewWithMargin(sizeView)
        stackView.addArrangedSubview(SeparatorView())

        let dateView = ConfigurableInfoView().setTapBlock { view in
            view.present(menu: .init(
                title: String(localized: "Copy"),
                children: [UIAction(
                    title: String(localized: "Download Date"),
                    image: UIImage(systemName: "timer")
                ) { _ in
                    UIPasteboard.general.string = dateFormatter
                        .string(from: model?.downloaded ?? .distantPast)
                    Indicator.present(
                        title: String(localized: "Copied"),
                        referencingView: view
                    )
                }]
            ), anchorPoint: .init(x: view.bounds.maxX, y: view.bounds.maxY))
        }
        dateView.configure(icon: .init(systemName: "timer"))
        dateView.configure(title: String(localized: "Download Date"))
        dateView.configure(description: String(localized: "The date when the model was downloaded."))
        dateView.configure(value: dateFormatter.string(from: model?.downloaded ?? .distantPast))
        stackView.addArrangedSubviewWithMargin(dateView)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: String(localized: "Metadata of a local model cannot be changed."))
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        if !ModelCapabilities.localModelEditable.isEmpty {
            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView()
                    .with(header: String(localized: "Capabilities"))
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())
            
            for cap in ModelCapabilities.localModelEditable {
                let view = ConfigurableToggleActionView()
                view.boolValue = model?.capabilities.contains(cap) ?? false
                view.actionBlock = { [weak self] value in
                    guard let self else { return }
                    ModelManager.shared.editLocalModel(identifier: identifier) { model in
                        if value {
                            model.capabilities.insert(cap)
                        } else {
                            model.capabilities.remove(cap)
                        }
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
                    .with(footer: String(localized: "We cannot determine whether this model includes additional capabilities. However, if supported, features such as visual recognition can be enabled manually here. Please note that if the model does not actually support these capabilities, attempting to enable them may result in errors."))
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())
        }

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Context"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let contextListViewAnnotation = ConfigurableInfoView()
        contextListViewAnnotation.configure(icon: .init(systemName: "list.bullet"))
        contextListViewAnnotation.configure(title: String(localized: "Context Length"))
        contextListViewAnnotation.configure(description: String(localized: "The context length for inference refers to the amount of information the model can retain and process at a given time. This context serves as the model’s memory, allowing it to understand and generate responses based on prior input."))
        let value = model?.context.title ?? String(localized: "Not Configured")
        contextListViewAnnotation.configure(value: value)
        contextListViewAnnotation.setTapBlock { view in
            guard let model else { return }
            let children = ModelContextLength.allCases.map { item in
                UIAction(
                    title: item.title,
                    image: UIImage(systemName: item.icon)
                ) { _ in
                    ModelManager.shared.editLocalModel(identifier: model.id) { $0.context = item }
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
                .with(footer: String(localized: "We cannot determine the context length supported by the model. Please choose the correct configuration here. Configuring a context length smaller than the capacity can save costs. A context that is too long may be truncated during inference."))
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Verification"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        var verifyButtonReader: UIView?
        let verifyButton = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            guard let model = ModelManager.shared.localModel(identifier: identifier) else { return }
            verifyButtonReader?.isUserInteractionEnabled = false
            verifyButtonReader?.alpha = 0.5
            Indicator.progress(
                title: String(localized: "Verifying Model"),
                controller: self
            ) { completionHandler in
                ModelManager.shared.testLocalModel(model) { result in
                    DispatchQueue.main.async {
                        verifyButtonReader?.isUserInteractionEnabled = true
                        verifyButtonReader?.alpha = 1
                        completionHandler {
                            switch result {
                            case .success:
                                Indicator.present(
                                    title: String(localized: "Model Verified"),
                                    referencingView: self.view
                                )
                            case let .failure(failure):
                                Indicator.present(
                                    title: String(localized: "Failed"),
                                    message: failure.localizedDescription,
                                    preset: .error,
                                    referencingView: self.view
                                )
                            }
                        }
                    }
                }
            }
        }
        verifyButton.configure(icon: UIImage(systemName: "testtube.2"))
        verifyButton.configure(title: String(localized: "Verify Model"))
        verifyButton.configure(description: String(localized: "Verify this model with corresponding capabilities."))
        stackView.addArrangedSubviewWithMargin(verifyButton)
        verifyButtonReader = verifyButton.superview
        stackView.addArrangedSubview(SeparatorView())
        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionFooterView()
                .with(footer: String(localized: "Local models will use different loaders based on the selected capabilities. For visual models, make sure to enable visual capabilities. Selecting the wrong model capability may result in a crash. If you still cannot load, try switching the model."))
        ) { $0.top /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Shortcuts"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())

        let openHuggingFace = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            guard let url = URL(string: "https://huggingface.co/\(identifier)") else {
                return
            }
            UIApplication.shared.open(url)
        }
        openHuggingFace.configure(icon: UIImage(systemName: "safari"))
        openHuggingFace.configure(title: String(localized: "Open in Hugging Face"))
        openHuggingFace.configure(description: String(localized: "View this model on Hugging Face."))
        stackView.addArrangedSubviewWithMargin(openHuggingFace)
        stackView.addArrangedSubview(SeparatorView())

        var exportOptionReader: UIView?
        let exportOption = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            guard let model = ModelManager.shared.localModel(identifier: identifier) else { return }
            Indicator.progress(
                title: String(localized: "Exporting Model"),
                controller: self
            ) { completionHandler in
                ModelManager.shared.pack(model: model) { url, cleanup in
                    completionHandler { [weak self] in
                        guard let url else {
                            Indicator.present(
                                title: String(localized: "Failed to Export"),
                                preset: .error,
                                haptic: .error,
                                referencingView: exportOptionReader
                            )
                            return
                        }
                        #if targetEnvironment(macCatalyst)
                            let documentPicker = UIDocumentPickerViewController(forExporting: [url])
                            documentPicker.title = String(localized: "Export Model")
                            documentPicker.delegate = self
                            documentPicker.modalPresentationStyle = .formSheet
                            exportOptionReader?.parentViewController?.present(documentPicker, animated: true)
                            self?.documentPickerExportTempItems.append(url)
                        #else
                            let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            shareSheet.popoverPresentationController?.sourceView = exportOptionReader
                            shareSheet.popoverPresentationController?.sourceRect = exportOptionReader?.bounds ?? .zero
                            exportOptionReader?.parentViewController?.present(shareSheet, animated: true)
                            shareSheet.completionWithItemsHandler = { _, _, _, _ in
                                cleanup()
                            }
                        #endif
                    }
                }
            }
        }
        exportOptionReader = exportOption
        exportOption.configure(icon: UIImage(systemName: "square.and.arrow.up"))
        exportOption.configure(title: String(localized: "Export Model"))
        exportOption.configure(description: String(localized: "Export this model to share with others."))
        stackView.addArrangedSubviewWithMargin(exportOption)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView()
                .with(header: String(localized: "Management"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())
        let deleteAction = ConfigurableActionView { [weak self] _ in
            guard let self else { return }
            deleteTapped()
        }
        deleteAction.configure(icon: UIImage(systemName: "trash"))
        deleteAction.configure(title: String(localized: "Delete Model"))
        deleteAction.configure(description: String(localized: "Delete this model from your local storage."))
        deleteAction.titleLabel.textColor = .systemRed
        deleteAction.iconView.tintColor = .systemRed
        deleteAction.descriptionLabel.textColor = .systemRed
        deleteAction.imageView.tintColor = .systemRed
        stackView.addArrangedSubviewWithMargin(deleteAction)
        stackView.addArrangedSubview(SeparatorView())

        stackView.addArrangedSubviewWithMargin(UIView())

        let icon = UIImageView().with {
            $0.image = .modelLocal
            $0.tintColor = .label.withAlphaComponent(0.25)
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !MLX.GPU.isSupported {
            let alert = AlertViewController(
                title: String(localized: "Unsupporte"),
                message: String(localized: "Your device does not support MLX.")
            ) { context in
                context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                    context.dispose {
                        self.navigationController?.popViewController()
                    }
                }
            }
            present(alert, animated: true)
        }
    }
}

#if targetEnvironment(macCatalyst)
    extension LocalModelEditorController: UIDocumentPickerDelegate {
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            for cleanableURL in documentPickerExportTempItems {
                try? FileManager.default.removeItem(at: cleanableURL)
            }
            documentPickerExportTempItems.removeAll()
        }
    }
#endif
