//
//  Storage+CloudModel.swift
//  Storage
//
//  Created by 秋星桥 on 1/28/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    func cloudModelList() -> [CloudModel] {
        (
            try? db.getObjects(
                fromTable: CloudModel.table,
                where: CloudModel.Properties.removed == false,
                orderBy: [
                    CloudModel.Properties.model_identifier
                        .order(.ascending),
                ]
            )
        ) ?? []
    }

    func cloudModelPut(_ object: CloudModel) {
        object.markModified()
        try? db.insertOrReplace(
            [object],
            intoTable: CloudModel.table
        )
    }

    func cloudModel(with identifier: CloudModel.ID) -> CloudModel? {
        try? db.getObject(
            fromTable: CloudModel.table,
            where: CloudModel.Properties.objectId == identifier && CloudModel.Properties.removed == false
        )
    }

    func cloudModelEdit(identifier: CloudModel.ID, _ block: @escaping (inout CloudModel) -> Void) {
        let read: CloudModel? = try? db.getObject(
            fromTable: CloudModel.table,
            where: CloudModel.Properties.objectId == identifier
        )
        guard var object = read else { return }
        block(&object)
        object.markModified()
        try? db.insertOrReplace(
            [object],
            intoTable: CloudModel.table
        )
    }

    func cluodModelRemove(identifier: CloudModel.ID, handle: Handle? = nil) {
        let update = StatementUpdate().update(table: CloudModel.table)
            .set(CloudModel.Properties.version)
            .to(CloudModel.Properties.version + 1)
            .set(CloudModel.Properties.removed)
            .to(true)
            .set(CloudModel.Properties.modified)
            .to(Date.now)
            .where(CloudModel.Properties.objectId == identifier)

        if let handle {
            try? handle.exec(update)
        } else {
            try? db.exec(update)
        }
    }
}
