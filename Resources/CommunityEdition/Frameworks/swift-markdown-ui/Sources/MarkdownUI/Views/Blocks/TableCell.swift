import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct TableCell: View {
    @Environment(\.theme.tableCell) private var tableCell

    private let row: Int
    private let column: Int
    private let cell: RawTableCell

    init(row: Int, column: Int, cell: RawTableCell) {
        self.row = row
        self.column = column
        self.cell = cell
    }

    var body: some View {
        tableCell.makeBody(
            configuration: .init(
                row: row,
                column: column,
                label: .init(label),
                content: .init(block: .paragraph(content: cell.content))
            )
        )
        .tableCellBounds(forRow: row, column: column)
    }

    @ViewBuilder private var label: some View {
        if let imageFlow = ImageFlow(cell.content) {
            imageFlow
        } else {
            InlineText(cell.content)
        }
    }
}
