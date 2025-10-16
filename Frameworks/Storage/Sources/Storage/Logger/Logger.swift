//
//  Logger.swift
//  Storage
//
//  Created by king on 2025/10/14.
//

import os.log

extension Logger {
    static let loggingSubsystem: String = "wiki.qaq.flowdown"
    static let database = Logger(subsystem: Self.loggingSubsystem, category: "Database")
    static let syncEngine = Logger(subsystem: Self.loggingSubsystem, category: "SyncEngine")
}
