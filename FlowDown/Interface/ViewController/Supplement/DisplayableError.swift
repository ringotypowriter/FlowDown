//
//  Created by ktiays on 2025/2/28.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Foundation

protocol DisplayableError: Error {
    var displayableText: String { get }
}
