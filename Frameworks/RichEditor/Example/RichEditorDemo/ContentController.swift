//
//  ContentController.swift
//  RichEditorDemo
//
//  Created by 秋星桥 on 1/18/25.
//

import RichEditor
import UIKit

class ContentController: UIViewController, RichEditorView.Delegate {
    let editor = RichEditorView()
    let textView = UITextView()
    var isProcessing = false

    init() {
        super.init(nibName: nil, bundle: nil)

        NotificationCenter.default.addObserver(
            forName: .init("TOGGLE_AI"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            isProcessing.toggle()
            editor.setProcessingMode(isProcessing)
        }
        NotificationCenter.default.addObserver(
            forName: .init("DONE"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.view.endEditing(true)
        }
        NotificationCenter.default.addObserver(
            forName: .init("COPY"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            UIPasteboard.general.string = self?.textView.text
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        editor.delegate = self

        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = .init(top: 16, left: 16, bottom: 16, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        view.addSubview(editor)
        NSLayoutConstraint.activate([
            editor.widthAnchor.constraint(equalTo: view.widthAnchor),
            editor.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        textView.text = "Submit to see object."
        textView.textColor = .label
        textView.textContainer.maximumNumberOfLines = 0
        textView.isSelectable = false
        textView.isEditable = false
        textView.isScrollEnabled = true

        textView.alwaysBounceVertical = true
        textView.contentSize = .init(width: 100, height: 4000)
    }

    func onRichEditorSubmit(object: RichEditor.RichEditorView.Object, completion: @escaping (Bool) -> Void) {
        do {
            let data = try JSONEncoder().encode(object)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
            guard let prettyString = String(data: prettyData, encoding: .utf8) else {
                throw NSError(domain: "Error", code: -1, userInfo: nil)
            }
            textView.text = prettyString

            // Show Apple Intelligence animation
            editor.setProcessingMode(true)

            // Simulate async work
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                DispatchQueue.main.async {
                    // Hide animation when done
                    self.editor.setProcessingMode(false)
                    completion(true)
                }
            }
        } catch {
            textView.text = "Error: \(error)"
            editor.setProcessingMode(false)
            completion(false)
        }
    }

    func onRichEditorError(_ error: String) {
        print("[*] Error: \(error)")
        // You can show an alert or handle the error as needed
    }

    func onRichEditorTogglesUpdate(object: RichEditor.RichEditorView.Object) {
        print("[*] Toggles updated: \(object)")
    }

    func onRichEditorRequestObjectForRestore() -> RichEditor.RichEditorView.Object? {
        guard let data = UserDefaults.standard.data(forKey: "TestEditorObject") else {
            return nil
        }
        guard let object = try? JSONDecoder().decode(RichEditor.RichEditorView.Object.self, from: data) else {
            return nil
        }
        print("[*] restored object: \(object)")
        return object
    }

    func onRichEditorUpdateObject(object: RichEditor.RichEditorView.Object) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        print("[*] updated object: \(object)")
        UserDefaults.standard.set(data, forKey: "TestEditorObject")
    }

    var modelList = ["llama-3.3-70b", "qwen2.5-32b", "gpt4o-mini"]
    var currentModel: String?

    func onRichEditorPickModel(anchor _: UIView, completion: @escaping () -> Void) {
        currentModel = modelList.randomElement()
        completion()
    }

    func onRichEditorShowAlternativeModelMenu(anchor: UIView) {
        print("[*] Show alternative model menu from anchor: \(anchor)")
        // Implement your model menu here
    }

    func onRichEditorRequestCurrentModelName() -> String? {
        currentModel
    }

    func onRichEditorRequestCurrentModelIdentifier() -> String? {
        UUID().uuidString
    }

    func onRichEditorCheckIfModelSupportsToolCall(_: String) -> Bool {
        // Return true if this model supports tool calls
        // For now, just return true for demonstration
        true
    }

    func onRichEditorShowAlternativeToolsMenu(anchor: UIView) {
        print("[*] Show alternative tools menu from anchor: \(anchor)")
        // Implement your tools menu here
    }
}
