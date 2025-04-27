//
//  main.swift
//  Scrubber
//
//  Created by 秋星桥 on 2/18/25.
//

import ScrubberKit
import SwiftUI

struct ScrubberApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

ScrubberConfiguration.setup()
ScrubberApp.main()

#Preview {
    SearchProgressView(vm: .init(query: "Unixzii"))
}
