import Foundation
import UIKit

class FileExporterHelper: NSObject, UIDocumentPickerDelegate {
    var targetFileURL: URL?
    var referencedView: UIView?
    var deleteAfterComplete: Bool = false
    var completion: (() -> Void)?
    var exportTitle: String?

    override init() {
        super.init()
    }

    func execute(presentingViewController: UIViewController) {
        guard let fileURL = targetFileURL else { return }
        #if targetEnvironment(macCatalyst)
            let picker = UIDocumentPickerViewController(forExporting: [fileURL])
            picker.delegate = self
            if let exportTitle { picker.title = exportTitle }
            presentingViewController.present(picker, animated: true, completion: nil)
        #else
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            activityVC.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                if let self {
                    if completed, deleteAfterComplete {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
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

    // MARK: - UIDocumentPickerDelegate

    #if targetEnvironment(macCatalyst)
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            if deleteAfterComplete, let fileURL = targetFileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
            completion?()
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            completion?()
        }
    #endif
}
