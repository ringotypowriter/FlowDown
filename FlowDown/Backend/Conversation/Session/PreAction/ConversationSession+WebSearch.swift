//
//  ConversationSession+WebSearch.swift
//  FlowDown
//
//  Created by 秋星桥 on 3/19/25.
//

import ChatClientKit
import Foundation
import RichEditor
@preconcurrency import ScrubberKit
import Storage

extension ConversationSessionManager.Session {
    struct WebSearchPhase: Hashable {
        var query: Int = 0
        var queryBeginDate: Date = .init(timeIntervalSince1970: 0)
        /// The number of queries to be processed.
        var numberOfQueries: Int = 0
        var currentSource: Int = 0
        var numberOfSource: Int = 0
        var numberOfWebsites: Int = 0
        var numberOfResults: Int = 0
        var proccessProgress: Double = 0
    }

    func gatheringWebContent(
        searchQueries: [String],
        onSetWebDocumentResult: @escaping ([Scrubber.Document]) -> Void
    ) -> AsyncStream<WebSearchPhase> {
        .init { cont in
            Task.detached {
                var results: [Scrubber.Document] = []

                guard !searchQueries.isEmpty else {
                    onSetWebDocumentResult([])
                    return
                }

                let eachLimit = Int(max(3, ScrubberConfiguration.limitConfigurableObjectValue / searchQueries.count))
                print("[*] web search has limited \(eachLimit) for each query")

                var phase = WebSearchPhase()
                phase.numberOfQueries = searchQueries.count
                for (idx, searchQuery) in searchQueries.enumerated() {
                    try self.checkCancellation()
                    phase.query = idx
                    phase.queryBeginDate = .init()
                    phase.numberOfSource = 0
                    phase.numberOfWebsites = 0
                    phase.proccessProgress = 0
                    cont.yield(phase)
                    let urlsReranker = URLsReranker(question: searchQuery, keepKPerHostname: 4)
                    let scrubber = Scrubber(query: searchQuery, options: .init(urlsReranker: urlsReranker))
                    await withTaskCancellationHandler {
                        await withCheckedContinuation { innerCont in
                            DispatchQueue.main.async {
                                scrubber.run(limitation: eachLimit) { docs in
                                    results.append(contentsOf: docs)
                                    innerCont.resume()
                                } onProgress: { overall in
                                    let searchCompleted = scrubber.progress.engineStatusCompletedCount
                                    let searchTotal = scrubber.progress.engineStatus.count
                                    let websiteTotal = scrubber.progress.fetchedStatus.count
                                    phase.proccessProgress = overall.fractionCompleted
                                    phase.currentSource = searchCompleted
                                    phase.numberOfSource = searchTotal
                                    phase.numberOfWebsites = websiteTotal
                                    cont.yield(phase)
                                }
                            }
                        }
                    } onCancel: {
                        print("[-] cancelling web search due to task is cancelled")
                        scrubber.cancel()
                    }
                }

                results.shuffle()
                onSetWebDocumentResult(results)

                phase.numberOfResults = results.count
                phase.queryBeginDate = .init(timeIntervalSince1970: 0)
                cont.yield(phase)

                cont.finish()
            }
        }
    }

    func generateSearchQueries(for query: String, attachments: [String], previousMessages: [String]) async -> [String] {
        let messages: [ChatRequestBody.Message] = ModelManager.queryForWebSearch(
            input: query,
            documents: attachments,
            previousMessages: previousMessages
        ).map {
            switch $0.participant {
            case .system: .system(content: .text($0.document))
            case .assistant: .assistant(content: .text($0.document))
            case .user: .user(content: .text($0.document))
            }
        }

        guard let model = models.auxiliary else { return [] }
        let ans = try? await ModelManager.shared.infer(
            with: model,
            maxCompletionTokens: 64,
            input: messages
        )
        .content
        .components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .filter { !$0.lowercased().contains(ModelManager.queryForWebSearchNotRequiredToken().lowercased()) }

        let ret = ans ?? []
        // some reasoning model is not following our instructions
        guard ret.allSatisfy({ $0.count < 25 }) else { return [] }
        guard ret.count <= 3 else { return [] }
        return ret
    }
}

extension ConversationSession {
    func preprocessSearchQueries(
        _ currentMessageListView: MessageListView,
        _ object: inout RichEditorView.Object,
        _ webSearchResults: inout [Message.WebSearchStatus.SearchResult]
    ) async throws {
        guard case let .bool(value) = object.options[.browsing], value else {
            return
        }

        try checkCancellation()
        await currentMessageListView.loading()
        let prevMsgs = messages
            .filter { [.user, .assistant].contains($0.role) }
            .map(\.document)
            .filter { !$0.isEmpty }
        let searchQueries = await generateSearchQueries(
            for: object.text,
            attachments: object.attachments.map(\.textRepresentation),
            previousMessages: prevMsgs
        )
        guard !searchQueries.isEmpty else { return }
        let webSearchMessage = appendNewMessage(role: .webSearch)
        webSearchMessage.webSearchStatus.queries = searchQueries
        await requestUpdate(view: currentMessageListView)

        var webAttachments: [RichEditorView.Object.Attachment] = []

        let onSetWebContents: ([Scrubber.Document]) -> Void = { documents in
            print("[*] setting \(documents.count) search result")
            for (idx, doc) in documents.enumerated() where idx < 8 {
                webAttachments.append(.init(
                    type: .text,
                    name: doc.title,
                    previewImage: .init(),
                    imageRepresentation: .init(),
                    textRepresentation: """
                    [Internet Document Archive] \(doc.title)
                    **This document is provided by system, please cite the source if used.**
                    [^\(idx + 1)]
                    =======================================
                    \(doc.textDocument)
                    """,
                    storageSuffix: UUID().uuidString
                ))
            }
            let storableContent: [Message.WebSearchStatus.SearchResult] = documents.map { doc in
                .init(title: doc.title, url: doc.url)
            }
            webSearchMessage.webSearchStatus.searchResults.append(contentsOf: storableContent)
        }

        for try await phase in gatheringWebContent(
            searchQueries: searchQueries,
            onSetWebDocumentResult: onSetWebContents
        ) {
            try checkCancellation()
            var status = webSearchMessage.webSearchStatus
            status.currentSource = phase.currentSource
            status.numberOfSource = phase.numberOfSource
            status.numberOfWebsites = phase.numberOfWebsites
            status.currentQuery = phase.query
            status.currentQueryBeginDate = phase.queryBeginDate
            status.numberOfResults = phase.numberOfResults
            status.proccessProgress = phase.proccessProgress
            webSearchMessage.webSearchStatus = status
            await requestUpdate(view: currentMessageListView)
        }

        webSearchResults = webSearchMessage.webSearchStatus.searchResults
        object.attachments.append(contentsOf: webAttachments)

        if webAttachments.isEmpty {
            webSearchMessage.webSearchStatus.proccessProgress = -1
            throw NSError(
                domain: "Inference Service",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "No web search results."),
                ]
            )
        }
    }
}
