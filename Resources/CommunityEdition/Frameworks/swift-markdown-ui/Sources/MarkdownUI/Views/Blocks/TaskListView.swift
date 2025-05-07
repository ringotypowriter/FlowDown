import SwiftUI

struct TaskListView: View {
    @Environment(\.theme.list) private var list
    @Environment(\.listLevel) private var listLevel

    private let isTight: Bool
    private let items: [RawTaskListItem]

    init(isTight: Bool, items: [RawTaskListItem]) {
        self.isTight = isTight
        self.items = items
    }

    var body: some View {
        list.makeBody(
            configuration: .init(
                label: .init(label),
                content: .init(block: .taskList(isTight: isTight, items: items))
            )
        )
    }

    private var label: some View {
        BlockSequence(items) { _, item in
            TaskListItemView(item: item)
        }
        .labelStyle(.titleAndIcon)
        .environment(\.listLevel, listLevel + 1)
        .environment(\.tightSpacingEnabled, isTight)
    }
}
