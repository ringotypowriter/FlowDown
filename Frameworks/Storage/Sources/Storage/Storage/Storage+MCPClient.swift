//
//  Storage+MCPClient.swift
//  Storage
//
//  Created by LiBr on 6/29/25.
//


import Foundation
import WCDBSwift

public extension Storage {
    func listMCPClients() -> [MCPClient] {
        (
            try? db.getObjects(
                fromTable: MCPClient.table,
                orderBy: [
                    MCPClient.Properties.id.order(.ascending)
                ]
            )
        ) ?? []
    }
    
    func insert(object: MCPClient) {
        object.isAutoIncrement = true 
        try? db.insert(
            [object],
            intoTable: MCPClient.table
        )
        object.isAutoIncrement = false
    }
    
    func replace(object: MCPClient) {
        try? db.insertOrReplace(
            [object],
            intoTable: MCPClient.table
        )
    }

    func mcpClient(identifier: MCPClient.ID) -> MCPClient? {
        try? db.getObject(
            fromTable: MCPClient.table,
            where: MCPClient.Properties.id == identifier
        )
    }
    
    func insertOrReplace(identifier: MCPClient.ID, _ block: @escaping (inout MCPClient) -> Void) {
        let read: MCPClient? = try? db.getObject(
            fromTable: MCPClient.table,
            where: MCPClient.Properties.id == identifier
        )
        guard var object = read else { return }
        block(&object)
        try? db.insertOrReplace(
            [object],
            intoTable: MCPClient.table
        )
    }
    
    func remove(mcpIdentifier: MCPClient.ID) {
        try? db.delete(
            fromTable: MCPClient.table,
            where: MCPClient.Properties.id == mcpIdentifier
        )
    }
}
