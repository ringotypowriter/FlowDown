import Foundation
import UIKit

class DisposableExporter: NSObject {
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

    func execute(presentingViewController: UIViewController) {
        #if targetEnvironment(macCatalyst)
            let picker = UIDocumentPickerViewController(forExporting: [deletableItem])
            picker.delegate = self
            if let title { picker.title = title }
            presentingViewController.present(picker, animated: true, completion: nil)
        #else
            let activityVC = UIActivityViewController(activityItems: [deletableItem], applicationActivities: nil)
            activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
                guard let self else { return }
                // Always clean up the temporary file after sharing
                try? FileManager.default.removeItem(at: deletableItem)
            }
            presentingViewController.present(activityVC, animated: true, completion: nil)
        #endif
    }

    func run(anchor toView: UIView) {
        guard let presentingViewController = toView.parentViewController else { return }
        execute(presentingViewController: presentingViewController)
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
