//
//  Storage+CloudModel.swift
//  Storage
//
//  Created by 秋星桥 on 1/28/25.
//

import Foundation
import WCDBSwift

public extension Storage {
    func listCloudModels() -> [CloudModel] {
        (
            try? db.getObjects(
                fromTable: CloudModel.table,
                orderBy: [
                    CloudModel.Properties.model_identifier
                        .order(.ascending),
                ]
            )
        ) ?? []
    }

    func insertOrReplace(object: CloudModel) {
        try? db.insertOrReplace(
            [object],
            intoTable: CloudModel.table
        )
    }

    func cloudModel(identifier: CloudModel.ID) -> CloudModel? {
        try? db.getObject(
            fromTable: CloudModel.table,
            where: CloudModel.Properties.id == identifier
        )
    }

    func insertOrReplace(identifier: CloudModel.ID, _ block: @escaping (inout CloudModel) -> Void) {
        let read: CloudModel? = try? db.getObject(
            fromTable: CloudModel.table,
            where: CloudModel.Properties.id == identifier
        )
        guard var object = read else { return }
        block(&object)
        try? db.insertOrReplace(
            [object],
            intoTable: CloudModel.table
        )
    }

    func remove(identifier: CloudModel.ID) {
        try? db.delete(
            fromTable: CloudModel.table,
            where: CloudModel.Properties.id == identifier
        )
    }
}
