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
import XMLCoder

// MARK: - XML Models for Web Search

private struct WebSearchResponse: Codable {
    let search_required: Bool
    let queries: [String]

    private enum CodingKeys: String, CodingKey {
        case search_required
        case queries
    }
}

private struct WebSearchRequest: Codable {
    let task: String
    let user_input: String
    let attached_documents: [AttachedDocument]?
    let previous_messages: [PreviousMessage]?

    private enum CodingKeys: String, CodingKey {
        case task
        case user_input
        case attached_documents
        case previous_messages
    }

    struct AttachedDocument: Codable {
        let id: Int
        let content: String

        private enum CodingKeys: String, CodingKey {
            case id
            case content = ""
        }
    }

    struct PreviousMessage: Codable {
        let id: Int
        let content: String

        private enum CodingKeys: String, CodingKey {
            case id
            case content = ""
        }
    }
}

// MARK: - Web Search Query Generation

extension ConversationSessionManager.Session {
    private func generateWebSearchTemplate(input: String, documents: [String], previousMessages: [String]) -> [ModelManager.TemplateItem] {
        let task = """
        Generate relevant web search queries based on the user's input and context. Focus on simple, clear keywords that would be used in search engines. Return 1-3 queries maximum, preferably just one. Use the same language as the user's input.

        Respond with valid XML format like this example:
        <output>
        <search_required>true</search_required>
        <queries>
        <query>example search query</query>
        </queries>
        </output>

        If no web search is needed, respond with:
        <output>
        <search_required>false</search_required>
        <queries></queries>
        </output>
        """

        let attachedDocuments = documents.isEmpty ? nil : documents.enumerated().map { index, content in
            WebSearchRequest.AttachedDocument(id: index, content: content)
        }

        let previousMessagesData = previousMessages.isEmpty ? nil : previousMessages.enumerated().map { index, content in
            WebSearchRequest.PreviousMessage(id: index, content: content)
        }

        let webSearchRequest = WebSearchRequest(
            task: task,
            user_input: input,
            attached_documents: attachedDocuments,
            previous_messages: previousMessagesData
        )

        let encoder = XMLEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let xmlData = try encoder.encode(webSearchRequest, withRootKey: "web_search_request")
            let xmlString = String(data: xmlData, encoding: .utf8) ?? ""

            return [
                .init(
                    participant: .system,
                    document: """
                    \(task)

                    Current date and time: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .full))
                    Current locale: \(Locale.current.identifier)
                    Application name: \(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "unknown AI app")

                    Additional User Request: \(ModelManager.shared.additionalPrompt)
                    """
                ),
                .init(participant: .user, document: xmlString),
            ]
        } catch {
            print("[-] failed to encode web search request: \(error)")
            return []
        }
    }
}

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
                    phase.proccessProgress = 0.1
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
                                    phase.proccessProgress = max(0.1, overall.fractionCompleted)
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
        let messages: [ChatRequestBody.Message] = generateWebSearchTemplate(
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

        do {
            let ans = try await ModelManager.shared.infer(
                with: model,
                maxCompletionTokens: 128,
                input: messages
            )

            let content = ans.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Try to extract queries from XML first
            if let queries = extractQueriesFromXML(content) {
                return validateQueries(queries)
            }

            // Fallback to line-based parsing
            let queries = content
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return validateQueries(queries)
        } catch {
            print("[-] failed to generate search queries: \(error)")
            return []
        }
    }

    private func extractQueriesFromXML(_ xmlString: String) -> [String]? {
        if let queries = extractQueriesUsingXMLCoder(xmlString) {
            return queries
        }
        return extractQueriesUsingRegex(xmlString)
    }

    private func extractQueriesUsingXMLCoder(_ xmlString: String) -> [String]? {
        let decoder = XMLDecoder()

        if let data = xmlString.data(using: .utf8),
           let searchResponse = try? decoder.decode(WebSearchResponse.self, from: data)
        {
            guard searchResponse.search_required else {
                return []
            }
            return searchResponse.queries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return nil
    }

    private func extractQueriesUsingRegex(_ xmlString: String) -> [String]? {
        let searchRequiredPattern = #"<search_required>(.*?)</search_required>"#
        if let searchRequiredRegex = try? NSRegularExpression(pattern: searchRequiredPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let searchRequiredMatch = searchRequiredRegex.firstMatch(in: xmlString, options: [], range: NSRange(xmlString.startIndex ..< xmlString.endIndex, in: xmlString)),
           let searchRequiredRange = Range(searchRequiredMatch.range(at: 1), in: xmlString)
        {
            let searchRequiredValue = String(xmlString[searchRequiredRange]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if searchRequiredValue == "false" {
                return []
            }
        }
        let pattern = #"<queries>(.*?)</queries>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(xmlString.startIndex ..< xmlString.endIndex, in: xmlString)
        guard let match = regex.firstMatch(in: xmlString, options: [], range: range) else {
            return nil
        }
        guard let queriesRange = Range(match.range(at: 1), in: xmlString) else {
            return nil
        }
        let queriesText = String(xmlString[queriesRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let queryPattern = #"<query>(.*?)</query>"#
        guard let queryRegex = try? NSRegularExpression(pattern: queryPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let queryRange = NSRange(queriesText.startIndex ..< queriesText.endIndex, in: queriesText)
        let matches = queryRegex.matches(in: queriesText, options: [], range: queryRange)
        let queries = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: queriesText) else { return nil }
            return String(queriesText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        return queries.isEmpty ? nil : queries
    }

    private func validateQueries(_ queries: [String]) -> [String] {
        // Validate query constraints
        let validQueries = queries.filter { query in
            query.count <= 25 && query.count >= 2
        }

        // Limit to maximum 3 queries
        return Array(validQueries.prefix(3))
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
        guard !searchQueries.isEmpty else {
            print("[*] no search queries generated, skipping web search")
            let hintMessage = appendNewMessage(role: .assistant)
            hintMessage.document = String(localized: "I have determined not to search.")
            await requestUpdate(view: currentMessageListView)
            return
        }
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
                    textRepresentation: String(localized: """
                    <web_document id="\(idx + 1)">
                    <title>\(doc.title)</title>
                    <note>This document is provided by system, please cite the source if used.</note>
                    <content>
                    \(doc.textDocument)
                    </content>
                    </web_document>
                    """),
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
            status.proccessProgress = max(0.1, phase.proccessProgress)
            webSearchMessage.webSearchStatus = status
            await requestUpdate(view: currentMessageListView)
        }
        webSearchMessage.webSearchStatus.proccessProgress = 0
        await requestUpdate(view: currentMessageListView)

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
