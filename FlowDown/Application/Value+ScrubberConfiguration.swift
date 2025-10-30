//
//  Value+ScrubberConfiguration.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/22/25.
//

import Combine
import ConfigurableKit
import Foundation
import ScrubberKit

extension ScrubberConfiguration {
    static let googleEnabledKey = "app.scrubber.engine.google.enabled"
    static let duckduckgoEnabledKey = "app.scrubber.engine.duckduckgo.enabled"
    static let yahooEnabledKey = "app.scrubber.engine.yahoo.enabled"
    static let bingEnabledKey = "app.scrubber.engine.bing.enabled"

    static let limitKey = "app.scrubber.engine.limit"

    private static var cancellables: Set<AnyCancellable> = []

    static let engineConfigChanged: PassthroughSubject<Void, Never> = .init()

    nonisolated(unsafe) static let googleEnabledConfigurableObject: ConfigurableObject = .init(
        icon: "sparkle.magnifyingglass",
        title: "Google Search",
        explain: "Web search will fetch results from Google if enabled.",
        key: googleEnabledKey,
        defaultValue: true,
        annotation: .boolean
    )
    nonisolated(unsafe) static let duckduckgoEnabledConfigurableObject: ConfigurableObject = .init(
        icon: "sparkle.magnifyingglass",
        title: "Duck Duck Go Search",
        explain: "Web search will fetch results from Duck Duck Go if enabled.",
        key: duckduckgoEnabledKey,
        defaultValue: true,
        annotation: .boolean
    )
    nonisolated(unsafe) static let yahooEnabledConfigurableObject: ConfigurableObject = .init(
        icon: "sparkle.magnifyingglass",
        title: "Yahoo Search",
        explain: "Web search will fetch results from Yahoo if enabled.",
        key: yahooEnabledKey,
        defaultValue: true,
        annotation: .boolean
    )
    nonisolated(unsafe) static let bingEnabledConfigurableObject: ConfigurableObject = .init(
        icon: "sparkle.magnifyingglass",
        title: "Bing Search",
        explain: "Web search will fetch results from Bing if enabled.",
        key: bingEnabledKey,
        defaultValue: true,
        annotation: .boolean
    )

    nonisolated(unsafe) static let limitConfigurableObject: ConfigurableObject = .init(
        icon: "number.circle",
        title: "Search Limit",
        explain: "The maximum number of search results to fetch.",
        key: limitKey,
        defaultValue: 20,
        annotation: .list { [
            .init(title: "5 Pages", rawValue: 5),
            .init(title: "10 Pages", rawValue: 10),
            .init(title: "15 Pages", rawValue: 15),
            .init(title: "20 Pages", rawValue: 20),
            .init(title: "Unlimited Pages", rawValue: 100),
        ] }
    )

    static var limitConfigurableObjectValue: Int {
        ConfigurableKit.value(forKey: limitKey) ?? 20
    }

    static func subscribeToConfigurableItem() {
        assert(cancellables.isEmpty)

        let publisher: AnyPublisher<(Bool, Bool, Bool, Bool), Never> = Publishers.CombineLatest4(
            ConfigurableKit.publisher(forKey: googleEnabledKey, type: Bool.self)
                .compactMap { $0 ?? true }
                .eraseToAnyPublisher(),
            ConfigurableKit.publisher(forKey: duckduckgoEnabledKey, type: Bool.self)
                .compactMap { $0 ?? true }
                .eraseToAnyPublisher(),
            ConfigurableKit.publisher(forKey: yahooEnabledKey, type: Bool.self)
                .compactMap { $0 ?? true }
                .eraseToAnyPublisher(),
            ConfigurableKit.publisher(forKey: bingEnabledKey, type: Bool.self)
                .compactMap { $0 ?? true }
                .eraseToAnyPublisher()
        )
        .eraseToAnyPublisher()

        let disabledEnginesPublisher = publisher
            .map { g, d, y, b in
                var disabledEnginesBuilder: Set<ScrubEngine> = []
                if !g { disabledEnginesBuilder.insert(.google) }
                if !d { disabledEnginesBuilder.insert(.duckduckgo) }
                if !y { disabledEnginesBuilder.insert(.yahoo) }
                if !b { disabledEnginesBuilder.insert(.bing) }
                return disabledEnginesBuilder
            }
            .eraseToAnyPublisher()

        disabledEnginesPublisher
            .ensureMainThread()
            .sink { input in
                if input.count == ScrubEngine.allCases.count {
                    disabledEngines = []
                    ConfigurableKit.set(value: true, forKey: googleEnabledKey)
                } else {
                    disabledEngines = input
                }
            }
            .store(in: &cancellables)
    }
}
