//
//  UserDefaultStorageProvider.swift
//  MobileAffine
//
//  Created by 秋星桥 on 2024/6/28.
//

import CommonCrypto
import Foundation

private let dirname = "wiki.qaq.ai.gate"
private let dir = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent(dirname)

private extension String {
    var sha1: String {
        let data = Data(utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

class UserDefaultStorageProvider: PersistProvider {
    static let shared = UserDefaultStorageProvider()

    private init() {}

    func data(forKey: String) -> Data? {
        UserDefaults.standard.data(forKey: forKey)
    }

    func set(_ data: Data?, forKey: String) {
        UserDefaults.standard.set(data, forKey: forKey)
    }

    func removeObject(forKey: String) {
        UserDefaults.standard.removeObject(forKey: forKey)
    }
}

extension Persist {
    init(key: String, defaultValue: Value) {
        self.init(key: key, defaultValue: defaultValue, engine: UserDefaultStorageProvider.shared)
    }
}

extension PublishedPersist {
    init(key: String, defaultValue: Value) {
        self.init(key: key, defaultValue: defaultValue, engine: UserDefaultStorageProvider.shared)
    }
}
