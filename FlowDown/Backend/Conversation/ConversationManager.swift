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
import RichEditor
import Storage
import UIKit

class ConversationManager {
    static let shared = ConversationManager()

    @BareCodableStorage(key: "wiki.qaq.conversation.editor.objects", defaultValue: [:])
    var temporaryEditorObjects: [Conversation.ID: RichEditorView.Object]

    let conversations: CurrentValueSubject<[Conversation], Never> = .init([])

    private init() {
        scanAll()
    }
}

extension Conversation {
    var interfaceImage: UIImage {
        if let image = UIImage(data: icon) {
            return image
        }
        return .init(systemName: "quote.bubble")
            ?? .starShine
    }
}
