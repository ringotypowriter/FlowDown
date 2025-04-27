//
//  LocalModel.swift
//  Storage
//
//  Created by 秋星桥 on 1/27/25.
//

import Foundation

public struct LocalModel: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var model_identifier: String
    public var downloaded: Date
    public var size: UInt64
    public var capabilities: Set<ModelCapabilities> = []
    public var context: ModelContextLength

    public init(
        id: String = UUID().uuidString,
        model_identifier: String,
        downloaded: Date,
        size: UInt64,
        capabilities: Set<ModelCapabilities>,
        context: ModelContextLength = .short_8k
    ) {
        self.id = id
        self.model_identifier = model_identifier
        self.downloaded = downloaded
        self.size = size
        self.capabilities = capabilities
        self.context = context
    }
}
