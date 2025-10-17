//
//  SyncQueryable.swift
//  Storage
//
//  Created by king on 2025/10/13.
//

import Foundation
import WCDBSwift

public struct SyncQueryProperties {
    let objectId: WCDBSwift.Property
    let modified: WCDBSwift.Property
    let removed: WCDBSwift.Property
}

public protocol SyncQueryable {
    static var SyncQuery: SyncQueryProperties { get }
}
