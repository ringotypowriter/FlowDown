//
//  Created by ktiays on 2025/1/27.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext
import UIKit

final class TableView: UIView {
    typealias Rows = [NSAttributedString]

    private let tableViewPadding: CGFloat = 2
    private let cellPadding: CGFloat = 10
    private let maximumCellWidth: CGFloat = 200

    private lazy var scrollView: UIScrollView = .init()
    private lazy var gridView: GridView = .init()

    var contents: [Rows] = [] {
        didSet {
            configureCells()
            setNeedsLayout()
        }
    }

    private var cells: [LTXLabel] = []
    private var cellSizes: [CGSize] = []
    private var widths: [CGFloat] = []
    private var heights: [CGFloat] = []

    private var numberOfRows: Int {
        contents.count
    }

    private var numberOfColumns: Int {
        contents.first?.count ?? 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureSubviews() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        scrollView.addSubview(gridView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.clipsToBounds = false
        scrollView.frame = bounds
        scrollView.contentSize = intrinsicContentSize
        gridView.frame = bounds

        if cellSizes.isEmpty || cells.isEmpty {
            return
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        for row in 0 ..< numberOfRows {
            for column in 0 ..< numberOfColumns {
                let index = row * numberOfColumns + column
                let cellSize = cellSizes[index]
                let cell = cells[index]
                let idealCellSize = cell.intrinsicContentSize
                cell.frame = .init(
                    x: x + cellPadding + tableViewPadding,
                    y: y + (cellSize.height - idealCellSize.height) / 2 + tableViewPadding,
                    width: ceil(idealCellSize.width),
                    height: ceil(idealCellSize.height)
                )
                let columnWidth = widths[column]
                x += columnWidth
            }
            x = 0
            y += heights[row]
        }
    }

    var intrinsicContentHeight: CGFloat {
        ceil(heights.reduce(0, +)) + tableViewPadding * 2
    }

    override var intrinsicContentSize: CGSize {
        .init(
            width: ceil(widths.reduce(0, +)) + tableViewPadding * 2,
            height: intrinsicContentHeight
        )
    }

    private func configureCells() {
        cellSizes = .init(repeating: .zero, count: numberOfRows * numberOfColumns)
        cells.forEach { $0.removeFromSuperview() }
        cells.removeAll()
        widths = .init(repeating: 0, count: numberOfColumns)
        heights = .init(repeating: 0, count: numberOfRows)
        for (row, rowContent) in contents.enumerated() {
            var rowHeight: CGFloat = 0
            for (column, cellString) in rowContent.enumerated() {
                let index = row * rowContent.count + column
                let cell: LTXLabel
                if index >= cells.count {
                    cell = LTXLabel()
                    cell.isSelectable = true
                    cell.backgroundColor = .clear
                    cell.attributedText = cellString
                    cell.preferredMaxLayoutWidth = maximumCellWidth
                    scrollView.addSubview(cell)
                    cells.append(cell)
                } else {
                    cell = cells[index]
                    cell.attributedText = cellString
                }
                let contentSize = cell.intrinsicContentSize
                let cellSize = CGSize(
                    width: ceil(contentSize.width) + cellPadding * 2,
                    height: ceil(contentSize.height) + cellPadding * 2
                )
                cellSizes[index] = cellSize
                rowHeight = max(rowHeight, cellSize.height)
                let width = max(widths[column], cellSize.width)
                widths[column] = width
            }
            heights[row] = rowHeight
        }
        gridView.padding = tableViewPadding
        gridView.update(widths: widths, heights: heights)
    }
}

extension TableView {
    private final class GridView: UIView {
        private var widths: [CGFloat] = []
        private var heights: [CGFloat] = []
        private var totalWidth: CGFloat = 0
        private var totalHeight: CGFloat = 0

        private lazy var shapeLayer: CAShapeLayer = .init()
        var padding: CGFloat = 2

        override init(frame: CGRect) {
            super.init(frame: frame)

            shapeLayer.lineWidth = 1
            shapeLayer.strokeColor = UIColor.label.cgColor
            layer.addSublayer(shapeLayer)

            backgroundColor = .clear
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        @MainActor
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            shapeLayer.strokeColor = UIColor.label.cgColor
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            shapeLayer.frame = bounds

            let path = UIBezierPath()
            var x: CGFloat = padding
            path.move(to: .init(x: x, y: padding))
            path.addLine(to: .init(x: x, y: totalHeight + padding))
            for width in widths {
                x += width
                path.move(to: .init(x: x, y: padding))
                path.addLine(to: .init(x: x, y: totalHeight + padding))
            }

            var y: CGFloat = padding
            path.move(to: .init(x: padding, y: y))
            path.addLine(to: .init(x: totalWidth + padding, y: y))
            for height in heights {
                y += height
                path.move(to: .init(x: padding, y: y))
                path.addLine(to: .init(x: totalWidth + padding, y: y))
            }
            shapeLayer.path = path.cgPath
        }

        func update(widths: [CGFloat], heights: [CGFloat]) {
            self.widths = widths
            self.heights = heights
            totalWidth = widths.reduce(0, +)
            totalHeight = heights.reduce(0, +)
            setNeedsLayout()
        }
    }
}

extension TableView: LTXAttributeStringRepresentable {
    func attributedStringRepresentation() -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        for row in contents {
            let rowString = NSMutableAttributedString()
            for cell in row {
                rowString.append(cell)
                rowString.append(NSAttributedString(string: "\t"))
            }
            attributedString.append(rowString)
            if row != contents.last {
                attributedString.append(NSAttributedString(string: "\n"))
            }
        }
        return attributedString
    }
}
