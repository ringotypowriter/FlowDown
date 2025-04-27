//
//  ContentController.swift
//  RichEditorDemo
//
//  Created by 秋星桥 on 1/18/25.
//

import RichEditor
import UIKit

class ContentController: UIViewController, RichEditorView.Delegate {
    let editor = RichEditorView(conversationIdentifier: UUID(uuidString: "83fa720a-a511-4d75-a963-a18198485d3f")!)
    let textView = UITextView()

    init() {
        super.init(nibName: nil, bundle: nil)

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
        [
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        .forEach { $0.isActive = true }

        view.addSubview(editor)
        [
            editor.widthAnchor.constraint(equalTo: view.widthAnchor),
            editor.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        .forEach { $0.isActive = true }

        textView.text = "Submit to see object."
        textView.textColor = .label
        textView.textContainer.maximumNumberOfLines = 0
        textView.isSelectable = false
        textView.isEditable = false
        textView.isScrollEnabled = true

        textView.alwaysBounceVertical = true
        textView.contentSize = .init(width: 100, height: 4000)
    }

    func onRichEditorSubmit(object: RichEditor.RichEditorView.Object) {
        do {
            let data = try JSONEncoder().encode(object)
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
            guard let prettyString = String(data: prettyData, encoding: .utf8) else {
                throw NSError(domain: "Error", code: -1, userInfo: nil)
            }
            textView.text = prettyString
        } catch {
            textView.text = "Error: \(error)"
        }

        let handler = editor.withProgress {
            print("[*] cancel triggered")
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            handler()
        }
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
    var currentModel: String? = nil

    func onRichEditorPickModel(anchor _: UIView, completion: @escaping () -> Void) {
        currentModel = modelList.randomElement()
        completion()
    }

    func onRichEditorRequestCurrentModelName() -> String? {
        currentModel
    }

    func onRichEditorRequestCurrentModelIdentifier() -> String? {
        UUID().uuidString
    }
}
