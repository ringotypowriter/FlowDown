//
//  Storage+ModelContextClient.swift
//  Storage
//
//  Created by LiBr on 6/29/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    func modelContextServerList() -> [ModelContextServer] {
        (
            try? db.getObjects(
                fromTable: ModelContextServer.table,
                where: ModelContextServer.Properties.removed == false,
                orderBy: [
                    ModelContextServer.Properties.id.order(.ascending),
                ]
            )
        ) ?? []
    }

    func modelContextServerMake() -> ModelContextServer {
        let object = ModelContextServer()
        try? db.insert([object], intoTable: ModelContextServer.table)
        return object
    }

    func modelContextServerPut(object: ModelContextServer) {
        object.markModified()
        try? db.insertOrReplace(
            [object],
            intoTable: ModelContextServer.table
        )
    }

    func modelContextServerWith(_ identifier: ModelContextServer.ID) -> ModelContextServer? {
        try? db.getObject(
            fromTable: ModelContextServer.table,
            where: ModelContextServer.Properties.id == identifier && ModelContextServer.Properties.removed == false
        )
    }

    func modelContextServerEdit(identifier: ModelContextServer.ID, _ block: @escaping (inout ModelContextServer) -> Void) {
        let read: ModelContextServer? = try? db.getObject(
            fromTable: ModelContextServer.table,
            where: ModelContextServer.Properties.id == identifier
        )
        guard var object = read else { return }
        block(&object)
        object.markModified()
        try? db.insertOrReplace(
            [object],
            intoTable: ModelContextServer.table
        )
    }

    func modelContextServerRemove(identifier: ModelContextServer.ID, handle: Handle? = nil) {
        let update = StatementUpdate().update(table: ModelContextServer.table)
            .set(ModelContextServer.Properties.version)
            .to(ModelContextServer.Properties.version + 1)
            .set(ModelContextServer.Properties.removed)
            .to(true)
            .set(ModelContextServer.Properties.modified)
            .to(Date.now)
            .where(ModelContextServer.Properties.id == identifier)

        if let handle {
            try? handle.exec(update)
        } else {
            try? db.exec(update)
        }
    }
}
