//
//  Created by ktiays on 2025/2/12.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import ChatClientKit
import Foundation
import Storage

/// The manager for a collection of chat sessions.
final class ConversationSessionManager {
    typealias Session = ConversationSession

    /// Instantiates `ConversationSessionManager` as a singleton.
    static let shared = ConversationSessionManager()

    private var sessions: [Conversation.ID: Session] = [:]
    private var messageChangedObserver: Any?

    private init() {
        messageChangedObserver = NotificationCenter.default.addObserver(
            forName: SyncEngine.MessageChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleMessageChanged(notification)
        }
    }

    deinit {
        if let messageChangedObserver {
            NotificationCenter.default.removeObserver(messageChangedObserver)
        }
    }

    /// Returns the session for the given conversation ID.
    func session(for id: Conversation.ID) -> Session {
        #if DEBUG
            ConversationSession.allowedInit = id
        #endif

        if let session = sessions[id] { return session }
        let session = Session(id: id)
        if session.messages.isEmpty {
            session.prepareSystemPrompt()
        }
        sessions[id] = session
        return session
    }

    private func handleMessageChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let info = userInfo[SyncEngine.MessageNotificationKey] as? MessageNotificationInfo
        else {
            refreshAllCachedSessions()
            return
        }

        var identifiers = Set(info.modifications.keys)
        identifiers.formUnion(info.deletions.keys)

        if identifiers.isEmpty {
            refreshAllCachedSessions()
            return
        }

        for identifier in identifiers {
            refreshSession(for: identifier)
        }
    }

    private func refreshSession(for identifier: Conversation.ID) {
        guard let session = sessions[identifier] else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.refreshContentsFromDatabase()
        }
    }

    private func refreshAllCachedSessions() {
        for identifier in sessions.keys {
            refreshSession(for: identifier)
        }
    }
}
