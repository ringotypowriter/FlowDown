//
//  Created by ktiays on 2025/1/15.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import UIKit

public protocol ThatListViewAdapter: AnyObject {
    typealias ItemType = (any Identifiable)
    typealias RowKind = (any Hashable)

    /// Asks the adapater for the height to use for a row in a specified location.
    func thatListView(_ list: ThatListView, heightFor item: ItemType, at index: Int) -> CGFloat

    func thatListView(_ list: ThatListView, configureRowView rowView: ThatListRowView, for item: ItemType, at index: Int)

    func thatListView(_ list: ThatListView, rowKindFor item: ItemType, at index: Int) -> RowKind

    /// Asks the adapter for a new row view to insert in a particular location of the list view.
    func makeThatListRowView(for kind: RowKind) -> ThatListRowView

    /// Informs the adapter when a context menu will appear.
    func thatListView(_ list: ThatListView, willDisplayContextMenuAt point: CGPoint, for item: ItemType, at index: Int, view: ThatListRowView)
}
