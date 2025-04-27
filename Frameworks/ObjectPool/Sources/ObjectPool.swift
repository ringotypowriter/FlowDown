//
//  Created by ktiays on 2025/2/6.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import DequeModule
import Foundation

/// A general-purpose pool of objects.
open class ObjectPool<T> {
    private let factory: () -> T
    private lazy var objects: Deque<T> = .init()

    public init(_ factory: @escaping () -> T) {
        self.factory = factory
    }

    open func acquire() -> T {
        if let object = objects.popLast() {
            object
        } else {
            factory()
        }
    }

    open func release(_ object: T) {
        objects.append(object)
    }
}
