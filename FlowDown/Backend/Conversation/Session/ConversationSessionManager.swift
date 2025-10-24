//
//  ConversationSessionManager.swift
//  FlowDown
//
//  Created by ktiays on 2025/2/12.
//

import ChatClientKit
import Foundation
import OSLog
import Storage

final class ConversationSessionManager {
    typealias Session = ConversationSession

    // MARK: - Singleton

    static let shared = ConversationSessionManager()

    // MARK: - State

    private var sessions: [Conversation.ID: Session] = [:]
    private var messageChangedObserver: Any?
    private var pendingRefresh: Set<Conversation.ID> = []
    private let logger = Logger(subsystem: "wiki.qaq.flowdown", category: "ConversationSessionManager")

    // MARK: - Lifecycle

    private init() {
        messageChangedObserver = NotificationCenter.default.addObserver(
            forName: SyncEngine.MessageChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            handleMessageChanged(notification)
        }
    }

    deinit {
        if let messageChangedObserver {
            NotificationCenter.default.removeObserver(messageChangedObserver)
        }
    }

    // MARK: - Public APIs

    func session(for conversationID: Conversation.ID) -> Session {
        if let cached = sessions[conversationID] { return cached }
        #if DEBUG
            ConversationSession.allowedInit = conversationID
        #endif
        let newSession = Session(id: conversationID)
        sessions[conversationID] = newSession
        return newSession
    }

    func invalidateSession(for conversationID: Conversation.ID) {
        sessions.removeValue(forKey: conversationID)
        pendingRefresh.remove(conversationID)
    }

    // MARK: - Message Change Handling

    private func handleMessageChanged(_ notification: Notification) {
        // Only update message lists; do not touch conversation sidebar (no scanAll here).
        guard let info = notification.userInfo?[SyncEngine.MessageNotificationKey] as? MessageNotificationInfo else {
            logger.info("MessageChanged without detail; refreshing all cached sessions")
            for (_, session) in sessions {
                refreshSafely(session)
            }
            return
        }

        var affected = Set<Conversation.ID>()
        for (cid, _) in info.modifications {
            affected.insert(cid)
        }
        for (cid, _) in info.deletions {
            affected.insert(cid)
        }
        guard !affected.isEmpty else { return }

        for cid in affected {
            guard let session = sessions[cid] else { continue }
            refreshSafely(session)
        }
    }

    private func refreshSafely(_ session: Session) {
        // Avoid refreshing while a streaming task is active to prevent UI errors.
        if let task = session.currentTask, !task.isCancelled {
            logger.debug("Defer refresh for session \(String(describing: session.id)) due to active task")
            if !pendingRefresh.contains(session.id) {
                pendingRefresh.insert(session.id)
                waitUntilIdleAndRefresh(sessionID: session.id)
            }
            return
        }
        session.refreshContentsFromDatabase()
    }

    private func waitUntilIdleAndRefresh(sessionID: Conversation.ID) {
        Task { @MainActor in
            var attempts = 0
            let maxAttempts = 60 // ~30s total
            while attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                attempts += 1
                guard let session = sessions[sessionID] else {
                    pendingRefresh.remove(sessionID)
                    return
                }
                if session.currentTask == nil {
                    session.refreshContentsFromDatabase()
                    pendingRefresh.remove(sessionID)
                    return
                }
            }
            // Still busy, invalidate so next switch loads from DB.
            logger.info("Timeout waiting for idle; invalidating session \(String(describing: sessionID))")
            invalidateSession(for: sessionID)
        }
    }
}
