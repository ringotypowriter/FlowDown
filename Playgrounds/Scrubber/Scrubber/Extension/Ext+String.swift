//
//  Ext+String.swift
//  Scrubber
//
//  Created by 秋星桥 on 2/18/25.
//

import Foundation

extension String {
    var sanitizedFileName: String {
        components(separatedBy: .init(charactersIn: #"/\:?%*|"<>"#))
            .joined(separator: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
