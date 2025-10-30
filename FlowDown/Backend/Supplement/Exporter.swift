import Foundation
import UIKit

class Exporter: NSObject {
    private let item: URL
    private let completion: (() -> Void)?
    private let exportTitle: String?

    init(
        item: URL,
        completion: (() -> Void)? = nil,
        exportTitle: String? = nil
    ) {
        self.item = item
        self.completion = completion
        self.exportTitle = exportTitle
        super.init()
    }

    func execute(presentingViewController: UIViewController) {
        #if targetEnvironment(macCatalyst)
            let picker = UIDocumentPickerViewController(forExporting: [item])
            picker.delegate = self
            if let exportTitle { picker.title = exportTitle }
            presentingViewController.present(picker, animated: true, completion: nil)
        #else
            let activityVC = UIActivityViewController(activityItems: [item], applicationActivities: nil)
            activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
                guard let self else { return }
                // Always clean up the temporary file after sharing
                try? FileManager.default.removeItem(at: item)
                completion?()
            }
            presentingViewController.present(activityVC, animated: true, completion: nil)
        #endif
    }

    func run(anchor toView: UIView) {
        guard let presentingViewController = toView.parentViewController else { return }
        execute(presentingViewController: presentingViewController)
    }
}

extension Exporter: UIDocumentPickerDelegate {
    // MARK: - UIDocumentPickerDelegate

    #if targetEnvironment(macCatalyst)
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            try? FileManager.default.removeItem(at: item)
            completion?()
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            completion?()
        }
    #endif
}
