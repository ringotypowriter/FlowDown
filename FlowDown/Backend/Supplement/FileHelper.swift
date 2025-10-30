import Foundation
import UIKit

class FileExporterHelper: NSObject, UIDocumentPickerDelegate {
    private let targetFileURL: URL
    private let referencedView: UIView?
    private let completion: (() -> Void)?
    private let exportTitle: String?

    init(
        targetFileURL: URL,
        referencedView: UIView? = nil,
        completion: (() -> Void)? = nil,
        exportTitle: String? = nil
    ) {
        self.targetFileURL = targetFileURL
        self.referencedView = referencedView
        self.completion = completion
        self.exportTitle = exportTitle
        super.init()
    }

    func execute(presentingViewController: UIViewController) {
        #if targetEnvironment(macCatalyst)
            let picker = UIDocumentPickerViewController(forExporting: [targetFileURL])
            picker.delegate = self
            if let exportTitle { picker.title = exportTitle }
            presentingViewController.present(picker, animated: true, completion: nil)
        #else
            let activityVC = UIActivityViewController(activityItems: [targetFileURL], applicationActivities: nil)
            activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
                if let self {
                    // Always clean up the temporary file after sharing
                    try? FileManager.default.removeItem(at: targetFileURL)
                    completion?()
                }
            }
            if let popover = activityVC.popoverPresentationController, let refView = referencedView {
                popover.sourceView = refView
                popover.sourceRect = refView.bounds
            }
            presentingViewController.present(activityVC, animated: true, completion: nil)
        #endif
    }

    func run(anchor toView: UIView) {
        guard let presentingViewController = toView.parentViewController else { return }
        execute(presentingViewController: presentingViewController)
    }

    // MARK: - UIDocumentPickerDelegate

    #if targetEnvironment(macCatalyst)
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            try? FileManager.default.removeItem(at: targetFileURL)
            completion?()
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            completion?()
        }
    #endif
}
