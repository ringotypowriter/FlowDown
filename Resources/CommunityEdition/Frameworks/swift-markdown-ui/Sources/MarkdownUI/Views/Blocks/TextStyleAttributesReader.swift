import SwiftUI

struct TextStyleAttributesReader<Content: View>: View {
    @Environment(\.textStyle) private var textStyle

    private let content: (AttributeContainer) -> Content

    init(@ViewBuilder content: @escaping (_ attributes: AttributeContainer) -> Content) {
        self.content = content
    }

    var body: some View {
        content(attributes)
    }

    private var attributes: AttributeContainer {
        var attributes = AttributeContainer()
        textStyle._collectAttributes(in: &attributes)
        return attributes
    }
}
