//
//  HubModelDownloadProgressController.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/27/25.
//

import SwiftUI
import UIKit

class HubModelDownloadProgressController: UIHostingController<HubModelDownloadProgressController.Content> {
    struct Content: View {
        let model: HubModelDownloadController.RemoteModel

        @StateObject var progress: ModelManager.HubDownloadProgress = .init()
        @State var modelIsDownloaded: Bool = false
        @State var task: Task<Void, Never>?

        @Environment(\.dismiss) var dismiss

        var ramSize: Double {
            Double(ProcessInfo.processInfo.physicalMemory)
        }

        var totalSize: Double {
            Double(progress.overall.totalUnitCount)
        }

        var modelIsLikelyOversize: Bool {
            totalSize > ramSize * 0.8
        }

        @ViewBuilder
        var content: some View {
            if let errorText = progress.error?.localizedDescription {
                Image(systemName: modelIsDownloaded ? "checkmark.circle.badge.xmark" : "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                VStack(spacing: 8) {
                    if modelIsDownloaded {
                        Text("Model is downloaded, but there seems to be a problem loading it.")
                            .font(.body.bold())
                            .multilineTextAlignment(.center)
                        Text("Either model is corrupted or not supported.")
                            .font(.body.bold())
                            .multilineTextAlignment(.center)
                    }
                }
                .transition(.opacity)
                Text(errorText)
                    .font(modelIsDownloaded ? .footnote : .body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                Button("Close") {
                    dismiss()
                }
            } else if modelIsDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("Model Download Complete")
                    .font(.body.bold())
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                Button("Close") {
                    dismiss()
                }
            } else {
                ProgressView()
                VStack(spacing: 16) {
                    progressContent
                }
                .font(.body)
            }
        }

        @ViewBuilder
        var progressContent: some View {
            HStack {
                Text("\(Int(progress.overall.fractionCompleted * 100))% Finished")
                Spacer()
                Text(progress.speed)
            }
            GeometryReader { r in
                Rectangle()
                    .foregroundStyle(.gray)
                    .overlay {
                        Rectangle()
                            .foregroundStyle(.accent)
                            .frame(width: r.size.width * progress.overall.fractionCompleted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: 2, style: .circular)
                    )
            }
            .frame(height: 4)
            Text(String(
                format: String(localized: "Process %@..."),
                progress.currentFilename
            ))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Download in progress, please keep app running in foreground.")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        var body: some View {
            ZStack {
                VStack(spacing: 32) {
                    Spacer()
                    Button("Cancel") {
                        progress.isCancelled = true
                        dismiss()
                    }
                    .opacity(progress.cancellable ? 1 : 0)
                    .disabled(!progress.cancellable)
                    Text(model.id)
                        .font(.footnote).monospaced()
                        .multilineTextAlignment(.center)
                        .opacity(0.5)
                }
                VStack(spacing: 32) {
                    content
                    Text("This model is likely too large to fit in the available memory.")
                        .foregroundStyle(.red)
                        .underline()
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                        .opacity(modelIsLikelyOversize ? 1 : 0)
                        .animation(.spring, value: modelIsLikelyOversize)
                }
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .transition(.opacity)
            .padding(32)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                task = Task.detached { await execute() }
            }

            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                progress.onInterfaceDisappear()
                task?.cancel()
                task = nil
            }
        }

        func execute() async {
            do {
                try await ModelManager.shared.downloadModelFromHuggingFace(
                    identifier: model.id,
                    populateProgressTo: progress
                )
                await MainActor.run { withAnimation(.spring) {
                    modelIsDownloaded = true
                    progress.cancellable = false
                } }
            } catch {
                await MainActor.run { withAnimation(.spring) {
                    progress.error = error
                    progress.cancellable = false
                } }
            }
        }
    }

    var onDismiss: () -> Void = {}

    init(model: HubModelDownloadController.RemoteModel) {
        super.init(rootView: Content(model: model))
        title = String(localized: "Downloading Model")
        modalTransitionStyle = .coverVertical
        modalPresentationStyle = .formSheet
        isModalInPresentation = true
        preferredContentSize = .init(width: 500, height: 500)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            onDismiss()
            onDismiss = {}
        }
    }
}
