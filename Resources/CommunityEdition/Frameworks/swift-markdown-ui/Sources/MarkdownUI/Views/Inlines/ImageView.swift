import SwiftUI

struct ImageView: View {
    @Environment(\.theme.image) private var image
    @Environment(\.imageProvider) private var imageProvider
    @Environment(\.imageBaseURL) private var baseURL

    private let data: RawImageData

    init(data: RawImageData) {
        self.data = data
    }

    var body: some View {
        image.makeBody(
            configuration: .init(
                label: .init(label),
                content: .init(block: content)
            )
        )
    }

    private var label: some View {
        imageProvider.makeImage(url: url)
            .link(destination: data.destination)
            .accessibilityLabel(data.alt)
    }

    private var content: BlockNode {
        if let destination = data.destination {
            .paragraph(
                content: [
                    .link(
                        destination: destination,
                        children: [.image(source: data.source, children: [.text(data.alt)])]
                    ),
                ]
            )
        } else {
            .paragraph(
                content: [.image(source: data.source, children: [.text(data.alt)])]
            )
        }
    }

    private var url: URL? {
        URL(string: data.source, relativeTo: baseURL)
    }
}

extension ImageView {
    init?(_ inlines: [InlineNode]) {
        guard inlines.count == 1, let data = inlines.first?.imageData else {
            return nil
        }
        self.init(data: data)
    }
}

private extension View {
    func link(destination: String?) -> some View {
        modifier(LinkModifier(destination: destination))
    }
}

private struct LinkModifier: ViewModifier {
    @Environment(\.baseURL) private var baseURL
    @Environment(\.openURL) private var openURL

    let destination: String?

    var url: URL? {
        destination.flatMap {
            URL(string: $0, relativeTo: baseURL)
        }
    }

    func body(content: Content) -> some View {
        if let url {
            Button {
                openURL(url)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
