//
//  ModelManager.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/27/25.
//

import Combine
import ConfigurableKit
import Foundation
import OrderedCollections
import Storage

class ModelManager: NSObject {
    static let shared = ModelManager()

    typealias ModelIdentifier = String
    typealias LocalModelIdentifier = LocalModel.ID
    typealias CloudModelIdentifier = CloudModel.ID

    let localModelDir: URL
    let localModelDownloadTempDir: URL

    var localModels: CurrentValueSubject<[LocalModel], Never> = .init([])
    var cloudModels: CurrentValueSubject<[CloudModel], Never> = .init([])

    let modelChangedPublisher: PassthroughSubject<Void, Never> = .init()

    let encoder = PropertyListEncoder()
    let decoder = PropertyListDecoder()

    @BareCodableStorage(key: "Model.Inference.Prompt.Default", defaultValue: PromptType.complete)
    var defaultPrompt: PromptType
    @BareCodableStorage(key: "Model.Inference.Prompt.Additional", defaultValue: "")
    var additionalPrompt: String
    @BareCodableStorage(key: "Model.Inference.Prompt.Temperature", defaultValue: 0.75)
    var temperature: Float

    @BareCodableStorage(key: "Model.Default.Conversation", defaultValue: "")
    // swiftformat:disable:next redundantFileprivate
    fileprivate var defaultModelForConversation: String { didSet { checkDefaultModels() } }
    @BareCodableStorage(key: "Model.Default.Auxiliary.UseCurrentChatModel", defaultValue: true)
    // swiftformat:disable:next redundantFileprivate
    fileprivate var defaultModelForAuxiliaryTaskWillUseCurrentChatModel: Bool { didSet { checkDefaultModels() } }
    @BareCodableStorage(key: "Model.Default.Auxiliary", defaultValue: "")
    // swiftformat:disable:next redundantFileprivate
    fileprivate var defaultModelForAuxiliaryTask: String { didSet { checkDefaultModels() } }
    @BareCodableStorage(key: "Model.Default.AuxiliaryVisual", defaultValue: "")
    // swiftformat:disable:next redundantFileprivate
    fileprivate var defaultModelForAuxiliaryVisualTask: String { didSet { checkDefaultModels() } }

    @BareCodableStorage(key: "Model.IsFirstBoot", defaultValue: true)
    fileprivate var isFirstBoot: Bool

    var cancellables: Set<AnyCancellable> = []

    override private init() {
        assert(LocalModelIdentifier.self == ModelIdentifier.self)
        assert(CloudModelIdentifier.self == ModelIdentifier.self)

        let base = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        localModelDir = base.appendingPathComponent("Models.Local")
        localModelDownloadTempDir = base.appendingPathComponent("Models.Local.Temp")

        super.init()

        try? FileManager.default.createDirectory(
            at: localModelDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? FileManager.default.createDirectory(
            at: localModelDownloadTempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        localModels.send(scanLocalModels())
        cloudModels.send(scanCloudModels())

        if isFirstBoot, localModels.value.isEmpty, cloudModels.value.isEmpty {
            for model in CloudModel.BuiltinModel.allCases.map(\.model) {
                _ = newCloudModel(profile: model)
            }
        }
        defer { isFirstBoot = false }

        // make sure after scan!
        Publishers.CombineLatest(
            localModels,
            cloudModels
        )
        .ensureMainThread()
        .sink { [weak self] _ in
            self?.modelChangedPublisher.send(())
            self?.checkDefaultModels()
        }
        .store(in: &cancellables)

        Self.defaultPromptConfigurableObject.whenValueChange(type: PromptType.RawValue.self) { [weak self] output in
            guard let output, let value = PromptType(rawValue: output) else { return }
            self?.defaultPrompt = value
        }
        Self.temperatureConfigurableObject.whenValueChange(type: Float.self) { [weak self] output in
            self?.temperature = output ?? 0.75
        }
    }

    func checkDefaultModels() {
        if !defaultModelForConversation.isEmpty,
           localModel(identifier: defaultModelForConversation) == nil,
           cloudModel(identifier: defaultModelForConversation) == nil
        {
            print("[*] reset defaultModelForConversation due to not found")
            defaultModelForConversation = ""
        }

        if !defaultModelForAuxiliaryTask.isEmpty,
           localModel(identifier: defaultModelForAuxiliaryTask) == nil,
           cloudModel(identifier: defaultModelForAuxiliaryTask) == nil
        {
            print("[*] reset defaultModelForAuxiliaryTask due to not found")
            defaultModelForAuxiliaryTask = ""
        }

        if !defaultModelForAuxiliaryVisualTask.isEmpty {
            let localModelSatisfied = localModel(identifier: defaultModelForAuxiliaryVisualTask)?.capabilities.contains(.visual) ?? false
            let cloudModelSatisfied = cloudModel(identifier: defaultModelForAuxiliaryVisualTask)?.capabilities.contains(.visual) ?? false
            if !localModelSatisfied, !cloudModelSatisfied {
                print("[*] reset defaultModelForAuxiliaryVisualTask due to not found")
                defaultModelForAuxiliaryVisualTask = ""
            }
        }
    }

    func modelName(identifier: ModelIdentifier?) -> String {
        guard let identifier else { return "-" }
        return nil
            ?? cloudModel(identifier: identifier)?.modelFullName
            ?? localModel(identifier: identifier)?.model_identifier
            ?? "-"
    }

    func modelCapabilities(identifier: ModelIdentifier) -> Set<ModelCapabilities> {
        if let cloudModel = cloudModel(identifier: identifier) {
            return cloudModel.capabilities
        }
        if let localModel = localModel(identifier: identifier) {
            return localModel.capabilities
        }
        return []
    }

    func modelContextLength(identifier: ModelIdentifier) -> Int {
        if let cloudModel = cloudModel(identifier: identifier) {
            return cloudModel.context.rawValue
        }
        if let localModel = localModel(identifier: identifier) {
            return localModel.context.rawValue
        }
        return 8192
    }
}

extension ModelManager.ModelIdentifier {
    static var defaultModelForAuxiliaryTaskWillUseCurrentChatModel: Bool {
        get { ModelManager.shared.defaultModelForAuxiliaryTaskWillUseCurrentChatModel }
        set { ModelManager.shared.defaultModelForAuxiliaryTaskWillUseCurrentChatModel = newValue }
    }

    static var defaultModelForConversation: Self {
        get { ModelManager.shared.defaultModelForConversation }
        set { ModelManager.shared.defaultModelForConversation = newValue }
    }

    static var defaultModelForAuxiliaryTask: Self {
        get {
            if defaultModelForAuxiliaryTaskWillUseCurrentChatModel {
                ModelManager.shared.defaultModelForConversation
            } else {
                ModelManager.shared.defaultModelForAuxiliaryTask
            }
        }
        set { ModelManager.shared.defaultModelForAuxiliaryTask = newValue }
    }

    static var defaultModelForAuxiliaryVisualTask: Self {
        get { ModelManager.shared.defaultModelForAuxiliaryVisualTask }
        set { ModelManager.shared.defaultModelForAuxiliaryVisualTask = newValue }
    }
}
