import SwiftUI

struct NumberedListView: View {
    @Environment(\.theme.list) private var list
    @Environment(\.theme.numberedListMarker) private var numberedListMarker
    @Environment(\.listLevel) private var listLevel

    @State private var markerWidth: CGFloat?

    private let isTight: Bool
    private let start: Int
    private let items: [RawListItem]

    init(isTight: Bool, start: Int, items: [RawListItem]) {
        self.isTight = isTight
        self.start = start
        self.items = items
    }

    var body: some View {
        list.makeBody(
            configuration: .init(
                label: .init(label),
                content: .init(
                    block: .numberedList(
                        isTight: isTight,
                        start: start,
                        items: items
                    )
                )
            )
        )
    }

    private var label: some View {
        ListItemSequence(
            items: items,
            start: start,
            markerStyle: numberedListMarker,
            markerWidth: markerWidth
        )
        .environment(\.listLevel, listLevel + 1)
        .environment(\.tightSpacingEnabled, isTight)
        .onColumnWidthChange { columnWidths in
            markerWidth = columnWidths[0]
        }
    }
}
