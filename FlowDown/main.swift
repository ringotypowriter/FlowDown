//
//  main.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

@_exported import Foundation
@_exported import SnapKit
@_exported import SwifterSwift
@_exported import UIKit

import Storage

#if !DEBUG
    fclose(stdout)
    fclose(stderr)

    Security.removeDebugger()
    guard Security.validateAppSignature() else {
        Security.crashOut()
    }
#endif

#if (os(macOS) || targetEnvironment(macCatalyst)) && ENABLE_SANDBOX_CHECK
    do {
        // make sure sandbox is enabled otherwise panic the app
        let sandboxTestDir = URL(fileURLWithPath: "/tmp/sandbox.test.\(UUID().uuidString)")
        FileManager.default.createFile(atPath: sandboxTestDir.path, contents: nil, attributes: nil)
        if FileManager.default.fileExists(atPath: sandboxTestDir.path) {
            fatalError("This app should not run outside of sandbox which may cause trouble.")
        }
    }
#endif

import OSLog

let logger = Logger.app
_ = LogStore.shared

import ConfigurableKit
import MLX

#if targetEnvironment(simulator) || arch(x86_64)
    ConfigurableKit.set(value: false, forKey: MLX.GPU.isSupportedKey)
    assert(!MLX.GPU.isSupported)
#else
    ConfigurableKit.set(value: true, forKey: MLX.GPU.isSupportedKey)
    assert(MLX.GPU.isSupported)
#endif

import Storage

let sdb: Storage = {
    do {
        return try Storage.db()
    } catch {
        fatalError(error.localizedDescription)
    }
}()

let syncEngine = SyncEngine(
    storage: sdb,
    containerIdentifier: CloudKitConfig.containerIdentifier,
    mode: .live,
    automaticallySync: true
)
Storage.setSyncEngine(syncEngine)

_ = ModelManager.shared
_ = ModelToolsManager.shared
_ = ConversationManager.shared
_ = MCPService.shared

DispatchQueue.global().async {
    let clean = FileManager.default
        .temporaryDirectory
        .appendingPathComponent("DisposableResources")
    try? FileManager.default.removeItem(at: clean)
}

#if os(macOS) || targetEnvironment(macCatalyst)
    _ = UpdateManager.shared
    FLDCatalystHelper.shared.install()
#endif

_ = UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)
