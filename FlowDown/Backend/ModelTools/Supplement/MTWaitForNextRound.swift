//
//  MTWaitForNextRound.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/27/25.
//

import ChatClientKit
import ConfigurableKit
import Foundation

class MTWaitForNextRound: ModelTool {
    override var shortDescription: String {
        "wait for next message from user"
    }

    override var interfaceName: String {
        String(localized: "Request User Input")
    }

    override var definition: ChatRequestBody.Tool {
        .function(
            name: "wait_for_next_round",
            description: "Wait for next message from user. Can be used when requesting additional information.",
            parameters: [
                "type": "object",
                "properties": [:],
                "required": [],
            ],
            strict: nil
        )
    }

    override class var controlObject: ConfigurableObject {
        fatalError("MTWaitForNextRound does not have a control object.")
    }

    override func execute(with input: String, anchorTo view: UIView) async throws -> String {
        _ = input
        _ = view
        assertionFailure()
        throw NSError()
    }
}
