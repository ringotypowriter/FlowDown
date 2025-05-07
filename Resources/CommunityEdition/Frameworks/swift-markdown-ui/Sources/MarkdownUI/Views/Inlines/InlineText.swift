import SwiftUI

struct InlineText: View {
    @Environment(\.inlineImageProvider) private var inlineImageProvider
    @Environment(\.baseURL) private var baseURL
    @Environment(\.imageBaseURL) private var imageBaseURL
    @Environment(\.softBreakMode) private var softBreakMode
    @Environment(\.theme) private var theme

    @State private var inlineImages: [String: Image] = [:]

    private let inlines: [InlineNode]

    init(_ inlines: [InlineNode]) {
        self.inlines = inlines
    }

    var body: some View {
        TextStyleAttributesReader { attributes in
            inlines.renderText(
                baseURL: baseURL,
                textStyles: .init(
                    code: theme.code,
                    emphasis: theme.emphasis,
                    strong: theme.strong,
                    strikethrough: theme.strikethrough,
                    link: theme.link
                ),
                images: inlineImages,
                softBreakMode: softBreakMode,
                attributes: attributes
            )
        }
        .task(id: inlines) {
            inlineImages = await (try? loadInlineImages()) ?? [:]
        }
    }

    private func loadInlineImages() async throws -> [String: Image] {
        let images = Set(inlines.compactMap(\.imageData))
        guard !images.isEmpty else { return [:] }

        return try await withThrowingTaskGroup(of: (String, Image).self) { taskGroup in
            for image in images {
                guard let url = URL(string: image.source, relativeTo: imageBaseURL) else {
                    continue
                }

                taskGroup.addTask {
                    try await (image.source, inlineImageProvider.image(with: url, label: image.alt))
                }
            }

            var inlineImages: [String: Image] = [:]

            for try await result in taskGroup {
                inlineImages[result.0] = result.1
            }

            return inlineImages
        }
    }
}
