import SwiftUI

struct TaskListItemView: View {
    @Environment(\.theme.listItem) private var listItem
    @Environment(\.theme.taskListMarker) private var taskListMarker

    private let item: RawTaskListItem

    init(item: RawTaskListItem) {
        self.item = item
    }

    var body: some View {
        listItem.makeBody(
            configuration: .init(
                label: .init(label),
                content: .init(blocks: item.children)
            )
        )
    }

    private var label: some View {
        Label {
            BlockSequence(item.children)
        } icon: {
            taskListMarker.makeBody(configuration: .init(isCompleted: item.isCompleted))
                .textStyleFont()
        }
    }
}
