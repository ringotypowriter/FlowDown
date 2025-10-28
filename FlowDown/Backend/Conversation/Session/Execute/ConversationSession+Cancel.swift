//
//  ConversationSession+Cancel.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/3/25.
//

import Combine
import Foundation
import OSLog
import Storage

class InferenceUserCancellationError: Error, LocalizedError {
    var errorDescription: String? {
        String(localized: "User cancelled the operation.")
    }
}

extension ConversationSession {
    func cancelCurrentTask(completion: @escaping () -> Void) {
        guard let task = currentTask else {
            DispatchQueue.main.async {
                completion()
            }
            return
        }
        Logger.app.infoFile("cancel current task for conversation: \(id)")
        task.cancel()
        // wait until self.currentTask is nil
        DispatchQueue.global().async {
            while self.currentTask != nil {
                Thread.sleep(forTimeInterval: 0.1)
            }
            Logger.app.infoFile("current task cancelled for conversation: \(self.id)")
            DispatchQueue.main.async {
                ConversationSessionManager.shared.markSessionCompleted(self.id)
                completion()
            }
        }
    }

    func checkCancellation() throws {
        guard let task = currentTask, !task.isCancelled else {
            throw InferenceUserCancellationError()
        }
    }
}
