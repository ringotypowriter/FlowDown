//
//  RichEditorView+Delegates.swift
//  RichEditor
//
//  Created by 秋星桥 on 2025/1/17.
//

import AlertController
import Foundation
import PhotosUI
import ScrubberKit
import UIKit
import UniformTypeIdentifiers

extension RichEditorView {
    func presentSpeechRecognition() {
        let controller = SimpleSpeechController()
        controller.callback = { [weak self] text in
            self?.inputEditor.set(
                text: (self?.inputEditor.textView.text ?? "") + text
            )
            self?.inputEditor.textView.becomeFirstResponder()
        }
        controller.onErrorCallback = { [weak self] error in
            self?.delegate?.onRichEditorError(error.localizedDescription)
        }
        parentViewController?.present(controller, animated: true)
    }

    func openCamera() {
        guard let parent = parentViewController else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            delegate?.onRichEditorError(NSLocalizedString(
                "Camera is not available, please grant camera permission",
                bundle: .module,
                comment: ""
            ))
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        picker.mediaTypes = ["public.image"]
        parent.present(picker, animated: true)
    }

    func openPhotoPicker() {
        guard let parent = parentViewController else { return }
        var config = PHPickerConfiguration()
        config.selectionLimit = 4
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        parent.present(picker, animated: true)
    }

    func openFilePicker() {
        guard let parent = parentViewController else { return }
        let supportedTypes: [UTType] = [.data, .image, .text, .plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        parent.present(picker, animated: true)
    }

    func process(image: UIImage) {
        guard let attachment = Object.Attachment(image: image, storage: storage) else {
            delegate?.onRichEditorError(NSLocalizedString("Failed to process image.", bundle: .module, comment: ""))
            return
        }
        attachmentsBar.insert(item: attachment)
    }

    func process(file: URL) {
        if let image = UIImage(contentsOfFile: file.path) {
            process(image: image)
            return
        }
        guard let attachment = Object.Attachment(file: file, storage: storage) else {
            delegate?.onRichEditorError(NSLocalizedString("Unsupported format.", bundle: .module, comment: ""))
            return
        }
        if attachment.textRepresentation.count > 1_000_000 {
            delegate?.onRichEditorError(NSLocalizedString("Text too long.", bundle: .module, comment: ""))
            return
        }
        attachmentsBar.insert(item: attachment)
    }
}

extension RichEditorView: InputEditor.Delegate {
    func onInputEditorCaptureButtonTapped() { openCamera() }

    func onInputEditorPickAttachmentTapped() { openFilePicker() }

    func onInputEditorMicButtonTapped() { presentSpeechRecognition() }

    func onInputEditorToggleMoreButtonTapped() {
        endEditing(true)
        controlPanel.toggle()
    }

    func onInputEditorSubmitButtonTapped() { submitValues() }

    func onInputEditorBeginEditing() {
        quickSettingBar.scrollToAfterModelItem()
        controlPanel.close()
    }

    func onInputEditorEndEditing() { publishNewEditorStatus() }

    func onInputEditorPastingLargeTextAsDocument(content: String) {
        let url = storage.absoluteURL(storage.random())
            .deletingLastPathComponent() // delete random new file name
            .appendingPathComponent(NSLocalizedString("Pasteboard", bundle: .module, comment: "") + "-\(UUID().uuidString)")
            .appendingPathExtension("txt")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            process(file: url)
        } catch {
            delegate?.onRichEditorError(NSLocalizedString("Failed to save text.", bundle: .module, comment: ""))
        }
    }

    func onInputEditorPastingImage(image: UIImage) {
        process(image: image)
    }

    func onInputEditorTextChanged(text: String) {
        dropColorView.alpha = 0
        publishNewEditorStatus()
        guard text.isEmpty else { return }
        controlPanel.close()
    }
}

extension RichEditorView: AttachmentsBar.Delegate {
    public func attachmentBarDidUpdateAttachments(_: [AttachmentsBar.Item]) {
        publishNewEditorStatus()
    }
}

extension RichEditorView: QuickSettingBar.Delegate {
    func quickSettingBarPickModel() {
        delegate?.onRichEditorPickModel(anchor: quickSettingBar.modelPicker) { [weak self] in
            self?.updateModelInfo()
        }
    }

    func quickSettingBarShowAlternativeModelMenu() {
        delegate?.onRichEditorShowAlternativeModelMenu(anchor: quickSettingBar.modelPicker)
    }

    func updateModelInfo(postUpdate: Bool = true) {
        let newModel = delegate?.onRichEditorRequestCurrentModelName()
        withAnimation { self.quickSettingBar.setModelName(newModel) }
        let newModelIdentifier = delegate?.onRichEditorRequestCurrentModelIdentifier()
        quickSettingBar.setModelIdentifier(newModelIdentifier)
        var supportsToolCall = false
        if let newModelIdentifier {
            supportsToolCall = delegate?.onRichEditorCheckIfModelSupportsToolCall(newModelIdentifier) ?? false
        }
        quickSettingBar.updateToolCallAvailability(supportsToolCall)
        if postUpdate {
            delegate?.onRichEditorUpdateObject(object: collectObject())
        }
    }

    func quickSettingBarOnValueChagned() {
        publishNewEditorStatus()
        delegate?.onRichEditorTogglesUpdate(object: collectObject())

        if quickSettingBar.toolsToggle.isOn {
            let newModelIdentifier = delegate?.onRichEditorRequestCurrentModelIdentifier()
            if let newModelIdentifier,
               let value = delegate?.onRichEditorCheckIfModelSupportsToolCall(newModelIdentifier),
               value
            { /* pass */ } else {
                quickSettingBar.toolsToggle.isOn = false
                let alert = AlertViewController(
                    title: String(localized: "Error", bundle: .module),
                    message: String(localized: "This model does not support tool call or no model is selected.", bundle: .module)
                ) { context in
                    context.addAction(title: String(localized: "OK", bundle: .module), attribute: .dangerous) {
                        context.dispose()
                    }
                }
                parentViewController?.present(alert, animated: true)
            }
        }
    }
}

extension RichEditorView: ControlPanel.Delegate {
    func onControlPanelCameraButtonTapped() { openCamera() }
    func onControlPanelPickPhotoButtonTapped() { openPhotoPicker() }
    func onControlPanelPickFileButtonTapped() { openFilePicker() }

    func onControlPanelRequestWebScrubber() {
        let alert = AlertInputViewController(
            title: String(localized: "Capture Web Content", bundle: .module),
            message: String(localized: "Please paste or enter the URL here, the web content will be fetched later.", bundle: .module),
            placeholder: "https://",
            text: "",
            cancelButtonText: String(localized: "Cancel", bundle: .module),
            doneButtonText: String(localized: "Capture", bundle: .module)
        ) { [weak self] text in
            guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = url.scheme,
                  ["http", "https"].contains(scheme.lowercased()),
                  url.host != nil
            else {
                let alert = AlertViewController(
                    title: String(localized: "Error", bundle: .module),
                    message: String(localized: "Please enter a valid URL.", bundle: .module)
                ) { context in
                    context.addAction(title: String(localized: "OK", bundle: .module), attribute: .dangerous) {
                        context.dispose()
                    }
                }
                self?.parentViewController?.present(alert, animated: true)
                return
            }
            let indicator = AlertProgressIndicatorViewController(
                title: String(localized: "Fetching Content", bundle: .module)
            )
            self?.parentViewController?.present(indicator, animated: true)
            Scrubber.document(for: url) { [weak self] doc in
                indicator.dismiss(animated: true) {
                    guard let doc else {
                        let alert = AlertViewController(
                            title: String(localized: "Error", bundle: .module),
                            message: String(localized: "Failed to fetch the web content.", bundle: .module)
                        ) { context in
                            context.addAction(title: String(localized: "OK", bundle: .module), attribute: .dangerous) {
                                context.dispose()
                            }
                        }
                        self?.parentViewController?.present(alert, animated: true)
                        return
                    }
                    let attachment = Object.Attachment(
                        type: .text,
                        name: doc.title,
                        previewImage: .init(),
                        imageRepresentation: .init(),
                        textRepresentation: doc.textDocument,
                        storageSuffix: UUID().uuidString
                    )
                    self?.attachmentsBar.insert(item: attachment)
                }
            }
        }
        parentViewController?.present(alert, animated: true)
    }

    func onControlPanelOpen() {
        quickSettingBar.hide()
        inputEditor.isControlPanelOpened = true
    }

    func onControlPanelClose() {
        quickSettingBar.show()
        inputEditor.isControlPanelOpened = false
    }
}

extension RichEditorView.Object.Attachment {
    init?(image: UIImage, storage: TemporaryStorage) {
        guard let compressed = image.prepareAttachment() else { return nil }
        let suffix = storage.random() + ".jpeg"
        let url = storage.absoluteURL(suffix)
        do {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: url)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            try compressed.write(to: url)
        } catch {
            return nil
        }
        self.init(
            type: .image,
            name: "Image",
            previewImage: image.jpeg(.medium) ?? .init(),
            imageRepresentation: compressed,
            textRepresentation: "",
            storageSuffix: suffix
        )
    }
}

extension RichEditorView.Object.Attachment {
    init?(file: URL, storage: TemporaryStorage) {
        guard let url = storage.duplicateIfNeeded(file) else { return nil }
        do {
            let content = try String(contentsOf: file)
            self.init(
                type: .text,
                name: file.lastPathComponent,
                previewImage: .init(),
                imageRepresentation: .init(),
                textRepresentation: content,
                storageSuffix: url.lastPathComponent
            )
        } catch {
            return nil
        }
    }
}

extension RichEditorView: UIDropInteractionDelegate {
    public func dropInteraction(_: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        var canHandleDrop = true
        for provider in session.items.map(\.itemProvider) {
            if session.localDragSession != nil {
                canHandleDrop = false
            }
            if canHandleDrop, provider.hasItemConformingToTypeIdentifier(UTType.folder.identifier) {
                canHandleDrop = false
            }
            if canHandleDrop, !provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                canHandleDrop = false
            }
        }
        return canHandleDrop
    }

    public func dropInteraction(_: UIDropInteraction, sessionDidUpdate _: UIDropSession) -> UIDropProposal {
        .init(operation: .copy)
    }

    public func dropInteraction(_: UIDropInteraction, sessionDidEnter _: UIDropSession) {
        UIView.animate(withDuration: 0.25) { self.dropColorView.alpha = 1 }
    }

    public func dropInteraction(_: UIDropInteraction, sessionDidExit _: any UIDropSession) {
        UIView.animate(withDuration: 0.25) { self.dropColorView.alpha = 0 }
    }

    public func dropInteraction(_: UIDropInteraction, sessionDidEnd _: UIDropSession) {
        UIView.animate(withDuration: 0.25) { self.dropColorView.alpha = 0 }
    }

    public func dropInteraction(_: UIDropInteraction, performDrop session: any UIDropSession) {
        let items = session.items
        UIView.animate(withDuration: 0.25) { self.dropColorView.alpha = 0 }
        for provider in items.map(\.itemProvider) {
            provider.loadFileRepresentation(
                forTypeIdentifier: UTType.item.identifier
            ) { url, _ in
                guard let url else { return }
                let tempDir = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(
                    at: tempDir,
                    withIntermediateDirectories: true
                )
                let targetURL = tempDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.copyItem(at: url, to: targetURL)
                DispatchQueue.main.async {
                    self.process(file: targetURL)
                    DispatchQueue.global().async {
                        try? FileManager.default.removeItem(at: tempDir)
                    }
                }
            }
        }
    }
}
