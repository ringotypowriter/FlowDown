//
//  main.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

@_exported import ConfigurableKit
@_exported import Foundation
@_exported import SnapKit
@_exported import SwifterSwift
@_exported import UIKit

import ConfigurableKit

#if DEBUG
    ConfigurableKit.printEveryValueChange()
#endif

_ = UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)
