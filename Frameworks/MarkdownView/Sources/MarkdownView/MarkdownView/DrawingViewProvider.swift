//
//  Created by ktiays on 2025/1/31.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import ObjectPool
import UIKit

private class ViewBox<T: UIView>: ObjectPool<T> {
    override func acquire() -> T {
        while true {
            let item = super.acquire()
            if item.superview != nil {
                print("Warning: Attempting to acquire a view that already has a superview. Ignore it. \(item)")
                continue
            }
            return item
        }
    }

    override func release(_ item: T) {
        item.removeFromSuperview()
        super.release(item)
    }
}

public final class DrawingViewProvider {
    private let codeViewPool: ViewBox<CodeView> = .init {
        CodeView()
    }

    private let tableViewPool: ViewBox<TableView> = .init {
        TableView()
    }

    var ignoresCharacterSetSuffixForCodeHighlighting: CharacterSet?

    public init() {}

    func acquireCodeView() -> CodeView {
        codeViewPool.acquire()
    }

    func releaseCodeView(_ codeView: CodeView) {
        codeView.removeFromSuperview()
        codeViewPool.release(codeView)
    }

    func acquireTableView() -> TableView {
        tableViewPool.acquire()
    }

    func releaseTableView(_ tableView: TableView) {
        tableView.removeFromSuperview()
        tableViewPool.release(tableView)
    }
}
