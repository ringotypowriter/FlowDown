//
//  ConversationSession+Images.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/20/25.
//

import ChatClientKit
import Foundation
import SwifterSwift
import UIKit
import Vision

private let languageIdentifiers: [String] = {
    var languageIdentifiers = Locale.LanguageCode.isoLanguageCodes.map(\.identifier)
    let englishIdentifier: String = Locale.LanguageCode.english.identifier
    let chineseIdentifier: String = Locale.LanguageCode.chinese.identifier
    if !languageIdentifiers.contains(englishIdentifier) {
        languageIdentifiers.append(englishIdentifier)
    }
    if !languageIdentifiers.contains(chineseIdentifier) {
        languageIdentifiers.append(chineseIdentifier)
    }
    return languageIdentifiers
}()

extension ConversationSession {
    func processImageToText(image: UIImage) async throws -> String {
        try checkCancellation()

        var messages: [ChatRequestBody.Message] = ModelManager.queryForDescribeTheImage().map {
            switch $0.participant {
            case .system:
                return .system(content: .text($0.document))
            case .assistant:
                assertionFailure()
                return .assistant(content: .text($0.document))
            case .user:
                assertionFailure()
                return .user(content: .text($0.document))
            }
        }

        guard let base64 = image.pngBase64String(),
              let url = URL(string: "data:image/png;base64,\(base64)")
        else {
            assertionFailure()
            return String(localized: "Unable to decode image.")
        }

        messages.append(.user(content: .parts([.imageURL(url)])))
        messages.append(.user(content: .text(String(localized: "Please describe the image."))))

        var decision: ModelManager.ModelIdentifier?
        if decision == nil,
           let model = models.auxiliary,
           ModelManager.shared.modelCapabilities(identifier: model).contains(.visual)
        { decision = model }
        if decision == nil,
           let model = models.visualAuxiliary,
           ModelManager.shared.modelCapabilities(identifier: model).contains(.visual)
        { decision = model }
        guard let decision else { return "" }

        print("[*] describing image with model: \(ModelManager.shared.modelName(identifier: decision))")

        try checkCancellation()
        let llmText = try? await ModelManager.shared.infer(
            with: decision,
            maxCompletionTokens: 2048,
            input: messages
        ).content
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let llmAns = llmText ?? String(localized: "Unable to identify the image with tool model.")

        var ans = ""
        ans += "[Image Description]\n\(llmAns)\n"

        try checkCancellation()
        if let ocrAns = try? await executeOpticalCharacterRecognition(on: image), !ocrAns.isEmpty {
            ans += "[Image Optical Character Recognition Result]\n\(ocrAns)\n"
        }

        try checkCancellation()
        if let qrAns = executeQRCodeRecognition(on: image), !qrAns.isEmpty {
            ans += "[QRCode Recognition]\n\(qrAns)\n"
        }

        print("[*] describing image returns:\n\(ans)")
        return ans
    }

    // OCR
    private func executeOpticalCharacterRecognition(on image: UIImage) async throws -> String? {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    cont.resume(returning: "")
                    return
                }

                let result: String = observations.map { observation in
                    observation.topCandidates(1).first?.string ?? ""
                }
                .joined(separator: "\n")
                cont.resume(returning: result)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = languageIdentifiers
            request.usesLanguageCorrection = true
            // perform request
            guard let cgIamge = image.cgImage else {
                cont.resume(returning: "")
                return
            }
            let handler = VNImageRequestHandler(cgImage: cgIamge)
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    private func executeQRCodeRecognition(on image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ) else {
            return nil
        }
        let features = detector.features(in: ciImage)
        let qrCodeFeatures = features.compactMap { $0 as? CIQRCodeFeature }
        guard let qrCode = qrCodeFeatures.first?.messageString else {
            return nil
        }
        return qrCode
    }
}
