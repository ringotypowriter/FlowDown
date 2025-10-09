//
//  Attachment.swift
//  Objects
//
//  Created by 秋星桥 on 1/23/25.
//

import Foundation
import WCDBSwift

public final class Attachment: Identifiable, Codable, TableCodable {
    static let table: String = "AttachmentV2"

    public var id: String {
        objectId
    }

    public var objectId: String = UUID().uuidString
    public var messageId: String = .init()
    public var data: Data = .init()
    public var previewImageData: Data = .init()
    public var imageRepresentation: Data = .init()
    public var representedDocument: String = ""
    public var type: String = ""
    public var name: String = ""
    public var storageSuffix: String = ""

    public var version: Int = 0
    public var removed: Bool = false
    public var creation: Date = .now
    public var modified: Date = .now

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = Attachment
        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(objectId, isPrimary: true, isNotNull: true, isUnique: true)
            BindColumnConstraint(messageId, isNotNull: true, defaultTo: "")
            BindColumnConstraint(creation, isNotNull: true, defaultTo: Date.now)
            BindColumnConstraint(modified, isNotNull: true, defaultTo: Date.now)

            BindColumnConstraint(data, isNotNull: true, defaultTo: Data())
            BindColumnConstraint(previewImageData, isNotNull: true, defaultTo: Data())
            BindColumnConstraint(representedDocument, isNotNull: true, defaultTo: "")
            BindColumnConstraint(type, isNotNull: true, defaultTo: "")
            BindColumnConstraint(name, isNotNull: true, defaultTo: "")
            BindColumnConstraint(storageSuffix, isNotNull: true, defaultTo: "")
            BindColumnConstraint(imageRepresentation, isNotNull: true, defaultTo: Data())

            BindColumnConstraint(version, isNotNull: false, defaultTo: 0)
            BindColumnConstraint(removed, isNotNull: false, defaultTo: false)

            BindIndex(creation, namedWith: "_creationIndex")
            BindIndex(modified, namedWith: "_modifiedIndex")
            BindIndex(messageId, namedWith: "_messageIdIndex")
        }

        case objectId
        case messageId
        case data
        case previewImageData
        case imageRepresentation
        case representedDocument
        case type
        case name
        case storageSuffix

        case version
        case removed
        case creation
        case modified
    }

    func markModified() {
        version += 1
        modified = .now
    }
}
