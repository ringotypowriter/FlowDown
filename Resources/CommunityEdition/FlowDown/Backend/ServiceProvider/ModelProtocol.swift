//
//  ModelProtocol.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/1/9.
//

import Foundation

protocol ModelProtocol {
    init(provider: ServiceProvider, identifier: String) throws

    func execute(
        input: Any,
        updatingResult: @escaping (Any) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}
