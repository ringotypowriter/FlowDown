//
//  Storage+ModelContextClient.swift
//  Storage
//
//  Created by LiBr on 6/29/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    func modelContextClientList() -> [ModelContextServer] {
        (
            try? db.getObjects(
                fromTable: ModelContextServer.table,
                orderBy: [
                    ModelContextServer.Properties.id.order(.ascending),
                ]
            )
        ) ?? []
    }

    func modelContextClientMake() -> ModelContextServer {
        let object = ModelContextServer()
        try? db.insert([object], intoTable: ModelContextServer.table)
        return object
    }

    func modelContextClientPut(object: ModelContextServer) {
        try? db.insertOrReplace(
            [object],
            intoTable: ModelContextServer.table
        )
    }

    func modelContextClientWith(_ identifier: ModelContextServer.ID) -> ModelContextServer? {
        try? db.getObject(
            fromTable: ModelContextServer.table,
            where: ModelContextServer.Properties.id == identifier
        )
    }

    func modelContextClientEdit(identifier: ModelContextServer.ID, _ block: @escaping (inout ModelContextServer) -> Void) {
        let read: ModelContextServer? = try? db.getObject(
            fromTable: ModelContextServer.table,
            where: ModelContextServer.Properties.id == identifier
        )
        guard var object = read else { return }
        block(&object)
        try? db.insertOrReplace(
            [object],
            intoTable: ModelContextServer.table
        )
    }

    func modelContextClientRemove(identifier: ModelContextServer.ID) {
        try? db.delete(
            fromTable: ModelContextServer.table,
            where: ModelContextServer.Properties.id == identifier
        )
    }
}
