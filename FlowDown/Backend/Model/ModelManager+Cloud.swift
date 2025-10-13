//
//  ModelManager+Cloud.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/28/25.
//

import CommonCrypto
import Foundation
import Storage

extension CloudModel {
    var modelDisplayName: String {
        var ret = model_identifier
        let scope = scopeIdentifier
        if !scope.isEmpty, ret.hasPrefix(scopeIdentifier + "/") {
            ret.removeFirst(scopeIdentifier.count + 1)
        }
        if ret.isEmpty { ret = String(localized: "Not Configured") }
        return ret
    }

    var modelFullName: String {
        let host = URL(string: endpoint)?.host
        return [
            model_identifier,
            host,
        ].compactMap(\.self).joined(separator: "@")
    }

    var scopeIdentifier: String {
        if model_identifier.contains("/") {
            return model_identifier.components(separatedBy: "/").first ?? ""
        }
        return ""
    }

    var inferenceHost: String { URL(string: endpoint)?.host ?? "" }

    var auxiliaryIdentifier: String {
        [
            "@",
            inferenceHost,
            scopeIdentifier.isEmpty ? "" : "@\(scopeIdentifier)",
        ].filter { !$0.isEmpty }.joined()
    }

    var tags: [String] {
        var input: [String] = []
        input.append(auxiliaryIdentifier)
        let caps = ModelCapabilities.allCases.filter { capabilities.contains($0) }.map(\.title)
        input.append(contentsOf: caps)
        return input.filter { !$0.isEmpty }
    }
}

extension ModelManager {
    func scanCloudModels() -> [CloudModel] {
        let models: [CloudModel] = sdb.cloudModelList()
        for model in models where model.id.isEmpty {
            // Ensure all models have a valid ID
            model.objectId = UUID().uuidString
            sdb.cluodModelRemove(identifier: "")
            sdb.cloudModelEdit(identifier: model.objectId) { $0.objectId = model.objectId }
            return scanCloudModels()
        }
        return models
    }

    func newCloudModel() -> CloudModel {
        let object = CloudModel(deviceId: Storage.deviceId)
        sdb.cloudModelPut(object)
        defer { cloudModels.send(scanCloudModels()) }
        return object
    }

    func newCloudModel(profile: CloudModel) -> CloudModel {
        profile.objectId = UUID().uuidString
        sdb.cloudModelPut(profile)
        defer { cloudModels.send(scanCloudModels()) }
        return profile
    }

    func insertCloudModel(_ model: CloudModel) {
        sdb.cloudModelPut(model)
        cloudModels.send(scanCloudModels())
    }

    func cloudModel(identifier: CloudModelIdentifier?) -> CloudModel? {
        guard let identifier else { return nil }
        return sdb.cloudModel(with: identifier)
    }

    func removeCloudModel(identifier: CloudModelIdentifier) {
        sdb.cluodModelRemove(identifier: identifier)
        cloudModels.send(scanCloudModels())
    }

    func editCloudModel(identifier: CloudModelIdentifier?, block: @escaping (inout CloudModel) -> Void) {
        guard let identifier else { return }
        sdb.cloudModelEdit(identifier: identifier, block)
        cloudModels.send(scanCloudModels())
    }

    func fetchModelList(identifier: CloudModelIdentifier?, block: @escaping ([String]) -> Void) {
        guard let model = cloudModel(identifier: identifier) else {
            block([])
            return
        }
        let endpoint = model.endpoint
        var model_list_endpoint = model.model_list_endpoint
        if model_list_endpoint.contains("$INFERENCE_ENDPOINT$") {
            if model.endpoint.isEmpty {
                block([])
                return
            }
            model_list_endpoint = model_list_endpoint.replacingOccurrences(of: "$INFERENCE_ENDPOINT$", with: endpoint)
        }
        guard !model_list_endpoint.isEmpty, let url = URL(string: model_list_endpoint)?.standardized else {
            block([])
            return
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        if !model.token.isEmpty { request.setValue("Bearer \(model.token)", forHTTPHeaderField: "Authorization") }
        for (key, value) in model.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let dic = try? JSONSerialization.jsonObject(with: data, options: [])
            else { return block([]) }
            let value = self.scrubModel(fromDic: dic).sorted()
            block(value)
        }.resume()
    }

    private func scrubModel(fromDic dic: Any) -> [String] {
        if let dic = dic as? [String: Any],
           let data = dic["data"] as? [[String: Any]]
        {
            data.compactMap { $0["id"] as? String }
        } else if let data = dic as? [[String: Any]] {
            data.compactMap { $0["id"] as? String }
        } else {
            []
        }
    }

    func importCloudModel(at url: URL) throws -> CloudModel {
        let decoder = PropertyListDecoder()
        let data = try Data(contentsOf: url)
        let model = try decoder.decode(CloudModel.self, from: data)
        if model.objectId.isEmpty { model.objectId = UUID().uuidString }
        insertCloudModel(model)
        return model
    }
}
