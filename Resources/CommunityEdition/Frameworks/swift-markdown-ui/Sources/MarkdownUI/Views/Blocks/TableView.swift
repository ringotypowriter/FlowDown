import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct TableView: View {
    @Environment(\.theme.table) private var table
    @Environment(\.tableBorderStyle.strokeStyle.lineWidth) private var borderWidth

    private let columnAlignments: [RawTableColumnAlignment]
    private let rows: [RawTableRow]

    init(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow]) {
        self.columnAlignments = columnAlignments
        self.rows = rows
    }

    var body: some View {
        table.makeBody(
            configuration: .init(
                label: .init(label),
                content: .init(block: .table(columnAlignments: columnAlignments, rows: rows))
            )
        )
    }

    private var label: some View {
        Grid(horizontalSpacing: borderWidth, verticalSpacing: borderWidth) {
            ForEach(0 ..< rowCount, id: \.self) { row in
                GridRow {
                    ForEach(0 ..< columnCount, id: \.self) { column in
                        TableCell(row: row, column: column, cell: rows[row].cells[column])
                            .gridColumnAlignment(.init(columnAlignments[column]))
                    }
                }
            }
        }
        .padding(borderWidth)
        .tableDecoration(
            rowCount: rowCount,
            columnCount: columnCount,
            background: TableBackgroundView.init,
            overlay: TableBorderView.init
        )
    }

    private var rowCount: Int {
        rows.count
    }

    private var columnCount: Int {
        columnAlignments.count
    }
}

private extension HorizontalAlignment {
    init(_ rawTableColumnAlignment: RawTableColumnAlignment) {
        switch rawTableColumnAlignment {
        case .none, .left:
            self = .leading
        case .center:
            self = .center
        case .right:
            self = .trailing
        }
    }
}
