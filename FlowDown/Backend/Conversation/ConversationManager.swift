//
//  ConversationManager.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/31/25.
//

import Combine
import ConfigurableKit
import Foundation
import OrderedCollections
import OSLog
import RichEditor
import Storage
import UIKit

class ConversationManager: NSObject {
    static let shared = ConversationManager()

    @BareCodableStorage(key: "wiki.qaq.conversation.editor.objects", defaultValue: [:])
    private var _temporaryEditorObjects: [Conversation.ID: RichEditorView.Object] {
        didSet { assert(!Thread.isMainThread) }
    }

    var temporaryEditorObjects: [Conversation.ID: RichEditorView.Object] = [:] {
        didSet {
            NSObject.cancelPreviousPerformRequests(
                withTarget: self,
                selector: #selector(saveObjects),
                object: nil
            )
            perform(#selector(saveObjects), with: nil, afterDelay: 1.0)
        }
    }

    let conversations: CurrentValueSubject<OrderedDictionary<Conversation.ID, Conversation>, Never> = .init([:])

    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
        temporaryEditorObjects = _temporaryEditorObjects
        Logger.app.infoFile("\(temporaryEditorObjects.count) temporary editor objects loaded.")
        scanAll()

        NotificationCenter.default.publisher(for: SyncEngine.ConversationChanged)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                logger.info("Recived SyncEngine.ConversationChanged")
                self?.scanAll()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: SyncEngine.LocalDataDeleted)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                logger.info("Recived SyncEngine.LocalDataDeleted")
                self?.scanAll()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: SyncEngine.MessageChanged)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] note in
                logger.info("Recived SyncEngine.MessageChanged")
                guard let userInfo = note.userInfo,
                      let info = userInfo[SyncEngine.MessageNotificationKey] as? MessageNotificationInfo else {
                    // No detailed info: invalidate all sessions and rescan
                    ConversationSessionManager.shared.invalidateAllSessions()
                    self?.scanAll()
                    return
                }

                // Collect affected conversation IDs from modifications and deletions
                var affected: Set<Conversation.ID> = []
                affected.formUnion(info.modifications.keys)
                affected.formUnion(info.deletions.keys)

                if affected.isEmpty {
                    ConversationSessionManager.shared.invalidateAllSessions()
                } else {
                    ConversationSessionManager.shared.invalidateSessions(for: Array(affected))
                }

                self?.scanAll()
            }
            .store(in: &cancellables)
    }

    @objc private func saveObjects() {
        DispatchQueue.global().async {
            self._temporaryEditorObjects = self.temporaryEditorObjects
            Logger.app.infoFile("\(self.temporaryEditorObjects.count) temporary editor objects saved.")
        }
    }
}

extension Conversation {
    var interfaceImage: UIImage {
        if let image = UIImage(data: icon) {
            return image
        }
        return "💬"
            .textToImage(size: 64)
            ?? .init(systemName: "quote.bubble")
            ?? .starShine
    }
}
