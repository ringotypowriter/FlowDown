//
//  ProgressIndicator.swift
//  Scrubber
//
//  Created by 秋星桥 on 2/18/25.
//

import SwiftUI

struct ProgressIndicator: View {
    enum Status {
        case pending
        case working
        case success
        case partialSuccess
        case failed
    }

    @Binding var status: Status

    let transition: AnyTransition = .opacity
        .combined(with: .scale(scale: 0.95))
    @State var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            switch status {
            case .pending:
                Image(systemName: "hourglass.circle.fill")
                    .transition(transition)
                    .foregroundStyle(.orange)
            case .working:
                Image(systemName: "gear.circle.fill")
                    .transition(transition)
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(
                        .linear(duration: 2)
                            .repeatForever(autoreverses: false),
                        value: rotationAngle
                    )
                    .onAppear { rotationAngle = 360 }
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .transition(transition)
                    .foregroundStyle(.green)
            case .partialSuccess:
                Image(systemName: "checkmark.circle.badge.xmark.fill")
                    .transition(transition)
                    .foregroundStyle(.red, .green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .transition(transition)
                    .foregroundStyle(.red)
            }
        }
        .animation(.spring, value: status)
    }
}
