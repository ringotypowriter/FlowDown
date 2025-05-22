import SwiftUI

struct BlockSequence<Data, Content>: View
    where
    Data: Sequence,
    Data.Element: Hashable,
    Content: View
{
    @Environment(\.multilineTextAlignment) private var textAlignment
    @Environment(\.tightSpacingEnabled) private var tightSpacingEnabled

    @State private var blockMargins: [Int: BlockMargin] = [:]

    private let data: [Indexed<Data.Element>]
    private let content: (Int, Data.Element) -> Content

    init(
        _ data: Data,
        @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
    ) {
        self.data = data.indexed()
        self.content = content
    }

    var body: some View {
        VStack(alignment: textAlignment.alignment.horizontal, spacing: 0) {
            ForEach(data, id: \.self) { element in
                content(element.index, element.value)
                    .onPreferenceChange(BlockMarginsPreference.self) { value in
                        blockMargins[element.hashValue] = value
                    }
                    .padding(.top, topPaddingLength(for: element))
            }
        }
    }

    private func topPaddingLength(for element: Indexed<Data.Element>) -> CGFloat? {
        guard element.index > 0 else {
            return 0
        }

        let topSpacing = blockMargins[element.hashValue]?.top
        let predecessor = data[element.index - 1]
        let predecessorBottomSpacing =
            tightSpacingEnabled ? 0 : blockMargins[predecessor.hashValue]?.bottom

        return [topSpacing, predecessorBottomSpacing]
            .compactMap(\.self)
            .max()
    }
}

extension BlockSequence where Data == [BlockNode], Content == BlockNode {
    init(_ blocks: [BlockNode]) {
        self.init(blocks) { $1 }
    }
}

private extension TextAlignment {
    var alignment: Alignment {
        switch self {
        case .leading:
            .leading
        case .center:
            .center
        case .trailing:
            .trailing
        }
    }
}
