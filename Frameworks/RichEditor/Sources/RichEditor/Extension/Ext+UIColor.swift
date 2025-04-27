//
//  Ext+UIColor.swift
//  RichEditor
//
//  Created by 秋星桥 on 2025/1/16.
//

import Foundation
import UIKit

extension UIColor {
    static let tint = UIColor.label
    static let accent: UIColor = {
        if let color = UIColor(named: "AccentColor") {
            return color
        }
        if let color = UIColor(named: "accentColor") {
            return color
        }
        if let color = UIColor(named: "Accent") {
            return color
        }
        if let color = UIColor(named: "accent") {
            return color
        }
        return .systemBlue
    }()
}
