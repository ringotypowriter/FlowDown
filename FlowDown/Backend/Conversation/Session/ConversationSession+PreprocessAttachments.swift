//
//  ConversationSession+PreprocessAttachments.swift
//  FlowDown
//
//  Created by 秋星桥 on 3/19/25.
//

import ChatClientKit
import Foundation
import RichEditor
import Storage

extension ConversationSession {
    func preprocessAttachments(
        _ object: inout RichEditorView.Object,
        _ currentMessageListView: MessageListView,
        _ userMessage: Message
    ) async throws {
        let attachmentThatRequiresProcess = object.attachments.filter {
            $0.type == .image && $0.textRepresentation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var processCount = 0
        for idx in 0 ..< object.attachments.count
            where object.attachments[idx].type == .image
            && object.attachments[idx].textRepresentation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            let attach = object.attachments[idx]
            assert(object.attachments[idx].type == .image)
            assert(object.attachments[idx].textRepresentation.isEmpty)
            processCount += 1

            // describe the image into text
            guard let image = UIImage(data: attach.imageRepresentation) else {
                assertionFailure()
                continue
            }
            let hint = String(localized: "Identifying an image: \(processCount)/\(attachmentThatRequiresProcess.count)")
            await currentMessageListView.loading(with: hint)
            let text = try await self.processImageToText(image: image)
            object.attachments[idx].textRepresentation = text
        }

        if processCount > 0 {
            await currentMessageListView.loading(with: String(localized: "Processed \(processCount) image(s)"))
        }

        if case let .bool(value) = object.options[.ephemeral], !value {
            updateAttachments(object.attachments, for: userMessage)
        }
    }
}
