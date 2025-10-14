//
//  Logger.swift
//  Storage
//
//  Created by king on 2025/10/14.
//

import os.log

extension Logger {
    static let loggingSubsystem: String = "com.flowdown.storage"
    static let database = Logger(subsystem: Self.loggingSubsystem, category: "Database")
    static let syncEngine = Logger(subsystem: Self.loggingSubsystem, category: "SyncEngine")
}
