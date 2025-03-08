//
//  Conversation+Message.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/2.
//

import Foundation
import MarkdownParser
import UIKit

extension Conversation {
    struct Message: Identifiable, Codable, Hashable, Equatable {
        private(set) var id: UUID = .init()
        private(set) var contentHash: Int = 0

        enum Participant: String, Codable, Equatable, Hashable {
            case system
            case hint
            case assistant
            case user
        }

        var date: Date = .init() { didSet { updateContentHash() } }
        var participant: Participant { didSet { updateContentHash() } }

        var document: String = "" { didSet { updateContentHash() } }
        var documentNode: [BlockNode] = [] { didSet { updateContentHash() } }
        var attachment: [Attachment] = [] { didSet { updateContentHash() } }
        var conversationIdentifier: Conversation.ID { didSet { updateContentHash() } }

        init(
            conversationIdentifier: Conversation.ID,
            id: UUID = .init(),
            date: Date = .init(),
            participant: Participant,
            document: String = "",
            attachment: [Attachment] = []
        ) {
            self.id = id
            self.date = date
            self.participant = participant
            self.document = document
            self.attachment = attachment
            self.conversationIdentifier = conversationIdentifier

            if !document.isEmpty { resolveMarkdownNodes() }
        }

        mutating func resolveMarkdownNodes() {
            let parser = MarkdownParser()
            let node = parser.feed(document)
            documentNode = node
        }

        mutating func updateContentHash() {
            var hasher = Hasher()
            hasher.combine(date)
            hasher.combine(participant)
            hasher.combine(document)
            hasher.combine(documentNode)
            hasher.combine(attachment)
            hasher.combine(conversationIdentifier)
            contentHash = hasher.finalize()
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(contentHash)
        }
    }
}

extension Conversation.Message {
    func createTextMenu(referenceView view: UIView) -> UIMenu? {
        guard let conv: Conversation = nil else { return nil }

        return UIMenu(title: NSLocalizedString("Text", comment: ""), options: [.displayInline], children: [
            UIAction(
                title: NSLocalizedString("Copy Original Text", comment: ""),
                image: UIImage(systemName: "doc.on.doc"),
                handler: { _ in
                    UIPasteboard.general.string = self.document
                }
            ),
            UIAction(
                title: NSLocalizedString("Share", comment: ""),
                image: UIImage(systemName: "square.and.arrow.up"),
                handler: { _ in
                    let activityViewController = UIActivityViewController(
                        activityItems: [self.document],
                        applicationActivities: nil
                    )
                    activityViewController.popoverPresentationController?.sourceView = view
                    view.parentViewController?.present(activityViewController, animated: true)
                }
            ),
        ])
    }

    func createRegenerateMenu(referenceView view: UIView) -> UIMenu? {
        guard let conv: Conversation = nil else { return nil }

        return switch participant {
        case .assistant:
            UIMenu(title: NSLocalizedString("Model", comment: ""), options: [.displayInline], children: [
                UIAction(
                    title: NSLocalizedString("Regenerate", comment: ""),
                    image: UIImage(systemName: "arrow.clockwise"),
                    handler: { _ in
                        _ = view
                        // TODO: impl
                    }
                ),
                UIAction(
                    title: NSLocalizedString("Regenerate Using New Model", comment: ""),
                    image: UIImage(systemName: "arrow.clockwise"),
                    handler: { _ in
                        // TODO: impl
                    }
                ),
            ])
        default:
            nil
        }
    }

    func createConversationMenu(referenceView view: UIView) -> UIMenu? {
        // TODO: IMPL
        guard let conv: Conversation = nil else { return nil }

        return UIMenu(title: NSLocalizedString("Conversation", comment: ""), options: [.displayInline, .destructive], children: [
            UIAction(
                title: NSLocalizedString("Delete Message", comment: ""),
                image: UIImage(systemName: "trash"),
                handler: { _ in
                    let alert = UIAlertController(
                        title: NSLocalizedString("Delete Message", comment: ""),
                        message: NSLocalizedString("Are you sure you want to delete this message?", comment: ""),
                        preferredStyle: .alert
                    )
                    alert.addAction(.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
                    alert.addAction(.init(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in
                        conv.messages.removeValue(forKey: self.id)
                    })
                    view.parentViewController?.present(alert, animated: true)
                }
            ),
            UIAction(
                title: NSLocalizedString("Delete All Messages After", comment: ""),
                image: UIImage(systemName: "trash"),
                handler: { _ in
                    let alert = UIAlertController(
                        title: NSLocalizedString("Delete Message", comment: ""),
                        message: NSLocalizedString("Are you sure you want to delete all messages after this one?", comment: ""),
                        preferredStyle: .alert
                    )
                    alert.addAction(.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
                    alert.addAction(.init(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in
                        var msgs = conv.messages
                        let index = msgs.values.firstIndex(where: { $0.id == self.id })
                        guard let index else { return }
                        let count = max(0, msgs.count - index)
                        msgs.removeLast(count)
                        conv.messages = msgs
                    })
                    view.parentViewController?.present(alert, animated: true)
                }
            ),
        ])
    }

    func createMenu(referencingView view: UIView) -> UIMenu {
        .init(children: [
            createTextMenu(referenceView: view),
            createRegenerateMenu(referenceView: view),
            createConversationMenu(referenceView: view),
        ].compactMap(\.self))
    }
}

extension Conversation.Message {
    struct Attachment: Identifiable, Codable, Equatable, Hashable {
        var id: UUID = .init()
        var thumbnailImageData: Data
    }
}

extension Conversation.Message.Attachment {
    var thumbnailImage: UIImage {
        UIImage(data: thumbnailImageData) ?? .init()
    }
}

extension Conversation.Message {
    static let defaultSystemPrompt = """
    You are a helpful assistant, user is using app named {{Template.applicationName}} to contact with you. The current date is {{Template.currentDateTime}}.
    Your knowledge base was last updated on August 2023. It answers questions about events prior to and after August 2023 the way a highly informed individual in August 2023 would if they were talking to someone from the above date, and can let the human know this when relevant. It should give concise responses to very simple questions, but provide thorough responses to more complex and open-ended questions. It cannot open URLs, links, or videos, so if it seems as though the interlocutor is expecting you to do so, it clarifies the situation and asks the human to paste the relevant text or image content directly into the conversation. If it is asked to assist with tasks involving the expression of views held by a significant number of people, you provides assistance with the task even if it personally disagrees with the views being expressed, but follows this with a discussion of broader perspectives. You doesn’t engage in stereotyping, including the negative stereotyping of majority groups. If asked about controversial topics, you tries to provide careful thoughts and objective information without downplaying its harmful content or implying that there are reasonable perspectives on both sides. If your response contains a lot of precise information about a very obscure person, object, or topic - the kind of information that is unlikely to be found more than once or twice on the internet - you ends its response with a succinct reminder that it may hallucinate in response to questions like this, and it uses the term ‘hallucinate’ to describe this as the user will understand what it means. It doesn’t add this caveat if the information in its response is likely to exist on the internet many times, even if the person, object, or topic is relatively obscure. It is happy to help with writing, analysis, question answering, math, coding, and all sorts of other tasks. It uses markdown for coding. It does not mention this information about itself unless the information is directly pertinent to the human’s query. It reply to user with the language that is most likely to be native for user, for example, if user is asking question in Chinese with a large number of reference text in English, you should reply in Chinese. Other languages are also acceptable if they are more likely to be native. An exception is that for rewriting tasks, eg: optimization, continue writing, please use the original language of that text. 
    """
    .replacingOccurrences(
        of: "{{Template.applicationName}}",
        with: {
            if let name = Bundle.main.localizedInfoDictionary?["CFBundleName"] as? String {
                return name
            }
            if let name = Bundle.main.infoDictionary?["CFBundleName"] as? String {
                return name
            }
            return NSLocalizedString("FlowDown", comment: "App name")
        }()
    )
    .replacingOccurrences(
        of: "{{Template.currentDateTime}}",
        with: DateFormatter.localizedString(
            from: Date(),
            dateStyle: .medium,
            timeStyle: .medium
        )
    )
}
