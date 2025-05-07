import SwiftUI

struct TableBorderView: View {
    @Environment(\.tableBorderStyle) private var tableBorderStyle

    private let tableBounds: TableBounds

    init(tableBounds: TableBounds) {
        self.tableBounds = tableBounds
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            let rectangles = tableBorderStyle.visibleBorders.rectangles(
                tableBounds, borderWidth
            )
            ForEach(0 ..< rectangles.count, id: \.self) {
                let rectangle = rectangles[$0]
                Rectangle()
                    .strokeBorder(tableBorderStyle.color, style: tableBorderStyle.strokeStyle)
                    .offset(x: rectangle.minX, y: rectangle.minY)
                    .frame(width: rectangle.width, height: rectangle.height)
            }
        }
    }

    private var borderWidth: CGFloat {
        tableBorderStyle.strokeStyle.lineWidth
    }
}
