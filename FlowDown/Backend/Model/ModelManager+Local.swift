//
//  ModelManager+Local.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/27/25.
//

import Combine
import CryptoKit
import Digger
import Foundation
import Hub
import MLX
import MLXLLM
import Storage
import ZIPFoundation

/*

 Model is stored in the following structure:

 - Models.Local
   - id
     - manifest
       - info.plist
     - content
       - <subfiles>

 Files outside these scope are removed once scanned.

 */

extension ModelCapabilities {
    var icon: String {
        switch self {
        case .visual: "eye"
//        case .stream: "arrow.up.arrow.down"
        case .tool: "hammer"
//        case .reasoning: "text.bubble"
        case .developerRole: "person.crop.circle.badge.checkmark"
        }
    }

    var title: String.LocalizationValue {
        switch self {
        case .visual: "Visual"
        case .tool: "Tool"
        case .developerRole: "Developer Role"
        }
    }

    var description: String.LocalizationValue {
        switch self {
        case .visual: "Visual model can be used for image recognition."
        case .tool: "This model can use client provided tools."
        case .developerRole: "This model requires developer role when dealing with prompt."
        }
    }
}

extension LocalModel {
    var modelDisplayName: String {
        var ret = model_identifier
        let scope = scopeIdentifier
        if !scope.isEmpty, ret.hasPrefix(scopeIdentifier + "/") {
            ret.removeFirst(scopeIdentifier.count + 1)
        }
        if ret.isEmpty { ret = String(localized: "Not Configured") }
        return ret
    }

    var scopeIdentifier: String {
        if model_identifier.contains("/") {
            return model_identifier.components(separatedBy: "/").first ?? ""
        }
        return ""
    }

    var inferenceHost: String { "localhost" }

    var auxiliaryIdentifier: String {
        [
            "@",
            inferenceHost,
            scopeIdentifier.isEmpty ? "" : "@\(scopeIdentifier)",
        ].filter { !$0.isEmpty }.joined()
    }

    var repoIdentifier: String {
        model_identifier
    }

    var tags: [String] {
        var input: [String] = []
        input.append(auxiliaryIdentifier)
        let caps = ModelCapabilities.allCases
            .filter { capabilities.contains($0) }
            .map(\.title)
            .map { String(localized: $0) }
        input.append(contentsOf: caps)
        return input.filter { !$0.isEmpty }
    }
}

extension ModelManager {
    func scanLocalModels() -> [LocalModel] {
        guard MLX.GPU.isSupported else { return [] }

        let contents = try? FileManager.default.contentsOfDirectory(
            at: localModelDir,
            includingPropertiesForKeys: nil,
            options: []
        )
        var ans = [LocalModel]()
        for content in contents ?? [] {
            let url = localModelDir.appendingPathComponent(content.lastPathComponent)
            let manifest = url
                .appendingPathComponent("manifest")
                .appendingPathComponent("info")
                .appendingPathExtension("plist")
            guard FileManager.default.fileExists(atPath: manifest.path),
                  let data = try? Data(contentsOf: manifest),
                  var model = try? decoder.decode(LocalModel.self, from: data),
                  FileManager.default.fileExists(atPath: self.modelContent(for: model).path),
                  dirForLocalModel(identifier: model.id) == url // otherwise it's a hacked model
            else {
                Logger.model.errorFile("removing invalid model: \(url)")
                try? FileManager.default.removeItem(at: url)
                continue
            }

            if model.id.isEmpty { model.id = UUID().uuidString }
            ans.append(model)

            let dirContent = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )
            for item in dirContent ?? [] {
                if item.lastPathComponent == "manifest" || item.lastPathComponent == "content" { continue }
                Logger.model.errorFile("removing unknown item: \(item)")
                try? FileManager.default.removeItem(at: item)
            }
        }
        Logger.model.infoFile("scanned \(ans.count) local models")
        return ans.sorted(by: \.id)
    }

    func dirForLocalModel(identifier mid: LocalModelIdentifier) -> URL {
        localModelDir.appendingPathComponent(mid)
    }

    // the name of the model, as id from hub
    func tempDirForDownloadLocalModel(model_identifier: String) -> URL {
        func hash(identifier mid: String) -> String {
            let data = Data(mid.utf8)
            let hash = Insecure.SHA1.hash(data: data)
            return hash.map { String(format: "%02hhx", $0) }.joined()
        }
        return localModelDownloadTempDir.appendingPathComponent(hash(identifier: model_identifier))
    }

    func localModel(identifier mid: LocalModelIdentifier) -> LocalModel? {
        localModels.value.first { $0.id.lowercased() == mid.lowercased() }
    }

    func calibrateLocalModelSize(identifier: LocalModelIdentifier) -> Int64 {
        guard let model = localModel(identifier: identifier) else { return 0 }
        let contentDir = modelContent(for: model)
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        let contents = FileManager.default.enumerator(at: contentDir, includingPropertiesForKeys: keys)
        for case let fileURL as URL in contents ?? NSEnumerator() {
            do {
                let values = try fileURL.resourceValues(forKeys: Set(keys))
                if values.isDirectory != true {
                    size += Int64(values.fileSize ?? 0)
                }
            } catch {
                Logger.model.errorFile("error getting size for \(fileURL): \(error)")
                continue
            }
        }
        editLocalModel(identifier: identifier) {
            $0.size = .init(size)
        }
        return size
    }

    func editLocalModel(identifier mid: LocalModelIdentifier, block: @escaping (inout LocalModel) -> Void) {
        guard var model = localModel(identifier: mid) else { return }
        block(&model)
        let url = dirForLocalModel(identifier: mid)
        let manifest = url
            .appendingPathComponent("manifest")
            .appendingPathComponent("info")
            .appendingPathExtension("plist")
        try? encoder.encode(model).write(to: manifest)
        localModels.send(scanLocalModels())
    }

    func localModelExists(identifier mid: LocalModelIdentifier) -> Bool {
        localModels.value.contains { $0.id.lowercased() == mid.lowercased() }
    }

    // HuggingFace Identifier, eg: mlx-community/Qwen2-VL-7B-Instruct-4bit
    func localModelExists(repoIdentifier: String) -> Bool {
        localModels.value.contains {
            $0.repoIdentifier.lowercased() == repoIdentifier.lowercased()
        }
    }

    func removeLocalModel(identifier mid: LocalModelIdentifier) {
        let url = dirForLocalModel(identifier: mid)
        try? FileManager.default.removeItem(at: url)
        localModels.send(scanLocalModels())
    }

    func removeLocalModel(repoIdentifier: String) {
        let model = localModels.value.first {
            $0.repoIdentifier.lowercased() == repoIdentifier.lowercased()
        }
        guard let mid = model?.id else { return }
        removeLocalModel(identifier: mid)
    }

    func modelContent(for model: LocalModel) -> URL {
        dirForLocalModel(identifier: model.id).appendingPathComponent("content")
    }

    func pack(model: LocalModel, completion: @escaping (URL?, _ cleanUpBlock: @escaping () -> Void) -> Void) {
        let url = dirForLocalModel(identifier: model.id)
        let item = model.model_identifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .sanitizedFileName
        let tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("DisposeableResources")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        let cleanUpBlock: () -> Void = { try? FileManager.default.removeItem(at: tempDir) }
        let zipFile = tempDir.appendingPathComponent(item).appendingPathExtension("zip")
        DispatchQueue.global().async {
            do {
                let copy = tempDir.appendingPathComponent("Export-\(item)")
                try FileManager.default.copyItem(at: url, to: copy)
                try FileManager.default.zipItem(
                    at: copy,
                    to: zipFile,
                    shouldKeepParent: false,
                    compressionMethod: .none
                )
                completion(zipFile, cleanUpBlock)
            } catch {
                completion(nil, cleanUpBlock)
            }
        }
    }

    func unpackAndImport(modelAt url: URL) -> Result<LocalModel> {
        assert(!Thread.isMainThread)
        guard MLX.GPU.isSupported else {
            return .failure(NSError(domain: "MLX", code: 2, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "Your device does not support MLX."),
            ]))
        }
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DisposableResources")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let zipFile = tempDir.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: zipFile)
            try FileManager.default.unzipItem(at: zipFile, to: tempDir)
            let manifest = tempDir
                .appendingPathComponent("manifest")
                .appendingPathComponent("info")
                .appendingPathExtension("plist")
            guard FileManager.default.fileExists(atPath: manifest.path),
                  let data = try? Data(contentsOf: manifest),
                  let model = try? decoder.decode(LocalModel.self, from: data)
            else {
                throw NSError(domain: "ModelManager", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Invalid model file."),
                ])
            }
            if model.id.isEmpty {
                throw NSError(
                    domain: "Model",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "Invalid model identifier.")]
                )
            }
            let target = dirForLocalModel(identifier: model.id)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: tempDir, to: target)
            localModels.send(scanLocalModels())
            return .success(model)
        } catch {
            return .failure(error)
        }
    }
}
