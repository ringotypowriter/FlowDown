import Foundation
import UIKit

final class DisposableExporter: NSObject {
    enum RunMode {
        case file
        case text
    }

    private let deletableItem: URL
    private let title: String?

    init(
        deletableItem: URL,
        title: String.LocalizationValue? = nil
    ) {
        self.deletableItem = deletableItem
        self.title = title.map { String(localized: $0) }
        super.init()
    }

    convenience init(
        data: Data,
        name: String = UUID().uuidString,
        pathExtension: String,
        title: String.LocalizationValue? = nil
    ) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DisposableResources")
        let tempURL = tempDir
            .appendingPathComponent(name)
            .appendingPathExtension(pathExtension)

        // Ensure parent directory exists
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? data.write(to: tempURL)

        self.init(deletableItem: tempURL, title: title)
    }

    func run(anchor toView: UIView, mode: RunMode = .file) {
        guard let presentingViewController = toView.parentViewController else { return }

        switch mode {
        case .text:
            // Always use UIActivityViewController for text
            let activityVC = UIActivityViewController(activityItems: [deletableItem], applicationActivities: nil)
            activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
                guard let self else { return }
                try? FileManager.default.removeItem(at: deletableItem)
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = toView
                popover.sourceRect = toView.bounds
            }
            presentingViewController.present(activityVC, animated: true, completion: nil)

        case .file:
            #if targetEnvironment(macCatalyst)
                let picker = UIDocumentPickerViewController(forExporting: [deletableItem])
                picker.delegate = self
                if let title { picker.title = title }
                presentingViewController.present(picker, animated: true, completion: nil)
            #else
                let activityVC = UIActivityViewController(activityItems: [deletableItem], applicationActivities: nil)
                activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
                    guard let self else { return }
                    try? FileManager.default.removeItem(at: deletableItem)
                }
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = toView
                    popover.sourceRect = toView.bounds
                }
                presentingViewController.present(activityVC, animated: true, completion: nil)
            #endif
        }
    }
}

extension DisposableExporter: UIDocumentPickerDelegate {
    // MARK: - UIDocumentPickerDelegate

    #if targetEnvironment(macCatalyst)
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            try? FileManager.default.removeItem(at: deletableItem)
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            try? FileManager.default.removeItem(at: deletableItem)
        }
    #endif
}
