//
//  Storage+Export.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/5/25.
//

import Foundation
import Storage
import ZIPFoundation

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

extension Storage {
    func exportZipFile() -> Result<URL, Error> {
        assert(!Thread.isMainThread)

        let result = exportDatabase()
        switch result {
        case let .success(databaseOutput):
            let tempURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(
                at: tempURL,
                withIntermediateDirectories: true
            )
            let zipURL = tempURL
                .appendingPathComponent(
                    String(
                        format: String(localized: "Exported Database %@"),
                        dateFormatter.string(from: Date())
                    )
                )
                .appendingPathExtension("zip")
            do {
                try FileManager.default.zipItem(at: databaseOutput, to: zipURL, shouldKeepParent: false)
                try? FileManager.default.removeItem(at: databaseOutput)
                return .success(zipURL)
            } catch {
                return .failure(error)
            }
        case let .failure(failure):
            return .failure(failure)
        }
    }
}
