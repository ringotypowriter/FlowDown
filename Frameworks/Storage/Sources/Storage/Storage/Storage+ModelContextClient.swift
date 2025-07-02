//
//  Storage+ModelContextClient.swift
//  Storage
//
//  Created by LiBr on 6/29/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    func modelContextClientList() -> [ModelContextClient] {
        (
            try? db.getObjects(
                fromTable: ModelContextClient.table,
                orderBy: [
                    ModelContextClient.Properties.id.order(.ascending),
                ]
            )
        ) ?? []
    }

    func modelContextClientMake() -> ModelContextClient {
        let object = ModelContextClient()
        object.isAutoIncrement = true
        try? db.insert([object], intoTable: ModelContextClient.table)
        object.isAutoIncrement = false
        object.id = object.lastInsertedRowID
        return object
    }

    func modelContextClientPut(object: ModelContextClient) {
        try? db.insertOrReplace(
            [object],
            intoTable: ModelContextClient.table
        )
    }

    func modelContextClientWith(_ identifier: ModelContextClient.ID) -> ModelContextClient? {
        try? db.getObject(
            fromTable: ModelContextClient.table,
            where: ModelContextClient.Properties.id == identifier
        )
    }

    func modelContextClientEdit(identifier: ModelContextClient.ID, _ block: @escaping (inout ModelContextClient) -> Void) {
        let read: ModelContextClient? = try? db.getObject(
            fromTable: ModelContextClient.table,
            where: ModelContextClient.Properties.id == identifier
        )
        guard var object = read else { return }
        block(&object)
        try? db.insertOrReplace(
            [object],
            intoTable: ModelContextClient.table
        )
    }

    func modelContextClientRemove(identifier: ModelContextClient.ID) {
        try? db.delete(
            fromTable: ModelContextClient.table,
            where: ModelContextClient.Properties.id == identifier
        )
    }
}
