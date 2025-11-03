//
//  QuickSettingBar+Delegate.swift
//  RichEditor
//
//  Created by 秋星桥 on 1/18/25.
//

import Foundation
import UIKit

extension QuickSettingBar {
    protocol Delegate: AnyObject {
        func quickSettingBarOnValueChagned()
        func quickSettingBarBuildModelSelectionMenu() -> [UIMenuElement]
        func quickSettingBarBuildAlternativeToolsMenu(isEnabled: Bool, requestReload: @escaping (Bool) -> Void) -> [UIMenuElement]
        func quickSettingBarToggleThinkingMode()
        func quickSettingBarRequestThinkingModeState() -> QuickSettingBar.ThinkingModeState?
        func quickSettingBarBuildReasoningEffortMenu() -> [UIMenuElement]
        func quickSettingBarRequestReasoningEffortState() -> QuickSettingBar.ReasoningEffortState?
    }
}
