//
//  ConversationSession+Cancel.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/3/25.
//

import Foundation
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
        print("[*] cancel current task for conversation: \(id)")
        task.cancel()
        // wait until self.currentTask is nil
        DispatchQueue.global().async {
            while self.currentTask != nil {
                Thread.sleep(forTimeInterval: 0.1)
            }
            print("[*] current task cancelled for conversation: \(self.id)")
            DispatchQueue.main.async {
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
