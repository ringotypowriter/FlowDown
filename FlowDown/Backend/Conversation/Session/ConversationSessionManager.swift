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

    /// Returns the session for the given conversation ID.
    func session(for id: Conversation.ID) -> Session {
        #if DEBUG
            ConversationSession.allowedInit = id
        #endif

        if let session = sessions[id] { return session }
        let session = Session(id: id)
        if session.messages.isEmpty {
            session.prepareSystemPrompt()
            session.save()
        }
        sessions[id] = session
        return session
    }
}
