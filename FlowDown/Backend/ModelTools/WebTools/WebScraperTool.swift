//
//  WebScraperTool.swift
//  FlowDown
//
//  Created on 2/28/25.
//

import AlertController
import ChatClientKit
import ConfigurableKit
import Foundation
import ScrubberKit
import UIKit

class MTWebScraperTool: ModelTool, @unchecked Sendable {
    override var shortDescription: String {
        "scrape content from web pages"
    }

    override var interfaceName: String {
        String(localized: "Web Scraper")
    }

    override var definition: ChatRequestBody.Tool {
        .function(
            name: "scrape_web_page",
            description: """
            Scrapes content from a given URL and returns the text content of the page.
            This can be used to get information from websites, read articles, or extract data.
            """,
            parameters: [
                "type": "object",
                "properties": [
                    "url": [
                        "type": "string",
                        "description": """
                        The URL of the web page to scrape. Must be a valid HTTP or HTTPS URL.
                        """,
                    ],
                ],
                "required": ["url"],
                "additionalProperties": false,
            ],
            strict: true
        )
    }

    override class var controlObject: ConfigurableObject {
        .init(
            icon: "globe",
            title: String(localized: "Web Scraper"),
            explain: String(localized: "Allows LLM to fetch and read content from web pages."),
            key: "wiki.qaq.ModelTools.WebScraperTool.enabled",
            defaultValue: true,
            annotation: .boolean
        )
    }

    override func execute(with input: String, anchorTo view: UIView) async throws -> String {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["url"] as? String,
              let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil
        else {
            throw NSError(
                domain: "MTWebScraperTool", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Invalid URL provided"),
                ]
            )
        }

        guard let viewController = await view.parentViewController else {
            throw NSError(
                domain: "MTWebScraperTool", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Could not find view controller"),
                ]
            )
        }

        let result = try await scrapeWithUserInteraction(url: url, controller: viewController)
        return result
    }

    @MainActor
    func scrapeWithUserInteraction(url: URL, controller: UIViewController) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let indicator = AlertProgressIndicatorViewController(
                title: String(localized: "Fetching Web Content")
            )

            controller.present(indicator, animated: true)

            Scrubber.document(for: url) { doc in
                indicator.dismiss(animated: true) {
                    guard let doc else {
                        continuation.resume(throwing: NSError(domain: String(localized: "Tool"), code: -1, userInfo: [
                            NSLocalizedDescriptionKey: String(localized: "Failed to fetch the web content."),
                        ]))
                        return
                    }

                    let maxSize = 32768
                    let truncatedContent = doc.textDocument.count > maxSize
                        ? String(doc.textDocument.prefix(maxSize)) + "..." + "\n" + String(localized: "Content truncated due to excessive length.")
                        : doc.textDocument

                    let result = String(localized: """
                    Web Content from: \(url.absoluteString)
                    Title: \(doc.title)

                    \(truncatedContent)
                    """)
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
