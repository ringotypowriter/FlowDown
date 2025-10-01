//
//  Security.swift
//  Axchange
//
//  Created by 秋星桥 on 2024/12/2.
//

import Foundation
import Security

enum Security {
    private static func secCall<T>(_ exec: (_ input: UnsafeMutablePointer<T?>) -> (OSStatus)) throws -> T {
        let pointer = UnsafeMutablePointer<T?>.allocate(capacity: 1)
        let err = exec(pointer)
        guard err == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        guard let value = pointer.pointee else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        return value
    }

    @inline(__always)
    static func validateAppSignature() -> Bool {
        true
    }

    static func removeDebugger() {
        #if !DEBUG
            do {
                typealias ptrace = @convention(c) (_ request: Int, _ pid: Int, _ addr: Int, _ data: Int) -> AnyObject
                let open = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_NOW)
                if unsafeBitCast(open, to: Int.self) > 0x1024 {
                    let result = dlsym(open, "ptrace")
                    if let result {
                        let target = unsafeBitCast(result, to: ptrace.self)
                        _ = target(0x1F, 0, 0, 0)
                    }
                }
            }
        #endif
    }

    static func crashOut() -> Never {
        fatalError("Binary integrity validation failed.")
    }
}
