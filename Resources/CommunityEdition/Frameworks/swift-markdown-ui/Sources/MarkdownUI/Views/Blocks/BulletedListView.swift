import SwiftUI

struct BulletedListView: View {
    @Environment(\.theme.list) private var list
    @Environment(\.theme.bulletedListMarker) private var bulletedListMarker
    @Environment(\.listLevel) private var listLevel

    private let isTight: Bool
    private let items: [RawListItem]

    init(isTight: Bool, items: [RawListItem]) {
        self.isTight = isTight
        self.items = items
    }

    var body: some View {
        list.makeBody(
            configuration: .init(
                label: .init(label),
                content: .init(block: .bulletedList(isTight: isTight, items: items))
            )
        )
    }

    private var label: some View {
        ListItemSequence(items: items, markerStyle: bulletedListMarker)
            .environment(\.listLevel, listLevel + 1)
            .environment(\.tightSpacingEnabled, isTight)
    }
}
