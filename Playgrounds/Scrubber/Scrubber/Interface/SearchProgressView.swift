//
//  SearchProgressView.swift
//  Scrubber
//
//  Created by 秋星桥 on 2/18/25.
//

import ScrubberKit
import SwiftUI

struct SearchProgressView: View {
    @StateObject var vm: ViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Browsing Internet")
                        .bold()
                    Text("Hold on while we are browsing the internet for you.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider().padding(.horizontal, -16)
            progressContent
            Divider().padding(.horizontal, -16)
            HStack {
                if vm.documents == nil {
                    Button("Cancel") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            vm.core.cancel()
                        }
                    }
                } else {
                    Text("File saved to downloads.")
                        .underline(true, color: .orange.opacity(0.2))
                        .onTapGesture {
                            NSWorkspace.shared.open(vm.documentDirectory)
                        }
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 400)
    }

    var progressContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                ProgressIndicator(status: $vm.searchingStatus)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        Text("Searching")
                        Spacer()
                        Text(vm.searchingProgressText)
                            .contentTransition(.numericText())
                            .animation(.spring, value: vm.searchingProgressText)
                    }
                    .bold()
                    Text(vm.searchingText)
                        .contentTransition(.numericText())
                        .animation(.spring, value: vm.searchingText)
                        .underline(true, color: .blue.opacity(0.2))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                ProgressIndicator(status: $vm.fetchingStatus)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        Text("Fetching Websites")
                        Spacer()
                        Text(vm.fetchingProgressText)
                            .contentTransition(.numericText())
                            .animation(.spring, value: vm.fetchingProgressText)
                    }
                    .bold()
                    Text(vm.fetchingText)
                        .contentTransition(.numericText())
                        .animation(.spring, value: vm.fetchingText)
                        .foregroundStyle(.secondary)
                        .underline(true, color: .blue.opacity(0.2))
                }
            }
            HStack(alignment: .firstTextBaseline) {
                ProgressIndicator(status: $vm.processingStatus)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        Text("Processing Content")
                        Spacer()
                        Text(vm.processingProgressText)
                            .contentTransition(.numericText())
                            .animation(.spring, value: vm.processingProgressText)
                    }
                    .bold()
                    Text(vm.processingText)
                        .contentTransition(.numericText())
                        .animation(.spring, value: vm.processingText)
                        .foregroundStyle(.secondary)
                        .underline(true, color: .blue.opacity(0.2))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
