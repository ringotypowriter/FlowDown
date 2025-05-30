//
//  ModelManager+InferenceAux.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/15/25.
//

import Foundation
import UIKit

extension ModelManager {
    struct TemplateItem {
        enum Participant: String, Codable {
            case system
            case user
            case assistant
        }

        let participant: Participant
        let document: String
    }
}

extension ModelManager {
    static func queryForDescribeTheImage() -> [TemplateItem] {
        [
            .init(
                participant: .system,
                document:
                String(localized:
                    """
                    Please provide a detailed description of the following image. The description should include the main elements in the image, the scene, colors, objects, people, and any significant details. Aim to give comprehensive information to help understand the meaning or context of the image.

                    1. What is the overall theme or setting of the image?
                    2. Are there any specific objects, buildings, or natural landscapes in the image? If so, please describe them.
                    3. Are there any people in the image? If yes, describe their appearance, expressions, actions, and their relation to other elements.
                    4. How do the colors and lighting in the image appear? Are there any prominent colors or contrasts?
                    5. What is in the foreground and background of the image? Are there any important details to note?
                    6. Does the image convey any specific emotions or atmosphere? If so, describe the mood or feeling.
                    7. Any other details that you find important or interesting, please include them.

                    If you are unable to describe the image, you may output [Unable to Identify the image.].
                    """
                )
            ),
        ]
    }
}
