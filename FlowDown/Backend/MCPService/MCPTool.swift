//
//  MCPTool.swift
//  FlowDown
//
//  Created by 秋星桥 on 7/10/25.
//

import AlertController
import ChatClientKit
import ConfigurableKit
import Foundation
import Logger
import MCP
import RichEditor
import Storage
import UIKit

class MCPTool: ModelTool, @unchecked Sendable {
    // MARK: - Properties

    let toolInfo: MCPToolInfo
    let mcpService: MCPService

    // MARK: - Initialization

    init(toolInfo: MCPToolInfo, mcpService: MCPService) {
        self.toolInfo = toolInfo
        self.mcpService = mcpService
        super.init()
    }

    // MARK: - ModelTool Implementation

    override var shortDescription: String {
        toolInfo.description ?? String(localized: "MCP Tool")
    }

    override var interfaceName: String {
        toolInfo.name
    }

    override var functionName: String {
        toolInfo.name
    }

    override var definition: ChatRequestBody.Tool {
        let parameters = convertMCPSchemaToJSONValues(toolInfo.inputSchema)
        return .function(
            name: toolInfo.name,
            description: toolInfo.description ?? String(localized: "MCP Tool"),
            parameters: parameters,
            strict: false
        )
    }

    override var isEnabled: Bool {
        get { true }
        set { assertionFailure() }
    }

    override class var controlObject: ConfigurableObject {
        assertionFailure()
        return .init(
            icon: "hammer",
            title: "MCP Tool",
            explain: "Tools from connected MCP servers",
            key: "MCP.Tools.Enabled",
            defaultValue: true,
            annotation: .boolean
        )
    }

    // MARK: - Tool Execution

    override func execute(with input: String, anchorTo _: UIView) async throws -> String {
        do {
            var arguments: [String: Value]?
            if !input.isEmpty {
                let data = Data(input.utf8)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    arguments = json.compactMapValues { value in
                        convertJSONValueToMCPValue(value)
                    }
                }
            }

            let result = try await mcpService.callTool(
                name: toolInfo.name,
                arguments: arguments,
                from: toolInfo.serverID
            )

            return formatToolResult(result.content, isError: result.isError)
        } catch {
            throw error
        }
    }

    override func executeWithAttachments(
        with input: String,
        anchorTo _: UIView
    ) async throws -> ModelToolExecutionResult {
        do {
            var arguments: [String: Value]?
            if !input.isEmpty {
                let data = Data(input.utf8)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    arguments = json.compactMapValues { value in
                        convertJSONValueToMCPValue(value)
                    }
                }
            }

            let result = try await mcpService.callTool(
                name: toolInfo.name,
                arguments: arguments,
                from: toolInfo.serverID
            )

            return formatToolResultWithAttachments(result.content, isError: result.isError)
        } catch {
            throw error
        }
    }

    // MARK: - Private Helper Methods

    private func formatToolResult(_ contents: [Tool.Content], isError: Bool?) -> String {
        var result = ""

        for content in contents {
            switch content {
            case let .text(text):
                result += text
            case let .image(_, mimeType, _):
                result += "[Image: \(mimeType)]"
            case let .resource(uri, text, _):
                result += "[Resource: \(uri)]"
                if !text.isEmpty {
                    result += "\n\(text)"
                }
            case let .audio(_, mimeType):
                result += "[Audio: \(mimeType)]"
            }
            result += "\n"
        }

        if isError == true {
            result = "Error: \(result)"
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatToolResultWithAttachments(
        _ contents: [Tool.Content],
        isError: Bool?
    ) -> ModelToolExecutionResult {
        var textResult = ""
        var attachments: [RichEditorView.Object.Attachment] = []

        Logger.network.infoFile("MCP tool returned \(contents.count) content items")

        for (index, content) in contents.enumerated() {
            switch content {
            case let .text(text):
                textResult += text
                textResult += "\n"

            case let .image(value, mimeType, _):
                Logger.network.infoFile("  Item \(index): Image, mimeType=\(mimeType)")

                // 尝试提取图片数据
                if let imageData = extractData(from: value),
                   let image = UIImage(data: imageData),
                   let attachment = createImageAttachment(
                       image: image,
                       mimeType: mimeType,
                       index: index
                   )
                {
                    attachments.append(attachment)
                    textResult += "[Image: \(mimeType)]\n"
                    Logger.network.infoFile("  Successfully created attachment: size=\(imageData.count) bytes")
                } else {
                    textResult += "[Image: \(mimeType) - Failed to process]\n"
                    Logger.network.warning("Failed to process MCP tool image at index \(index)")
                }

            case let .resource(uri, text, _):
                textResult += "[Resource: \(uri)]"
                if !text.isEmpty {
                    textResult += "\n\(text)"
                }
                textResult += "\n"

            case let .audio(_, mimeType):
                textResult += "[Audio: \(mimeType)]\n"
            }
        }

        if isError == true {
            textResult = "Error: \(textResult)"
        }

        let finalText = textResult.trimmingCharacters(in: .whitespacesAndNewlines)
        return ModelToolExecutionResult(text: finalText, attachments: attachments)
    }

    // MARK: - Image Processing Helpers

    private func extractData(from base64String: String) -> Data? {
        // 尝试作为 base64 字符串解码
        Data(base64Encoded: base64String)
    }

    private func createImageAttachment(
        image: UIImage,
        mimeType: String,
        index: Int
    ) -> RichEditorView.Object.Attachment? {
        guard let compressed = compressImage(image) else {
            return nil
        }

        let suffix = "\(UUID().uuidString).\(mimeTypeToExtension(mimeType))"
        let previewData = image.jpegData(compressionQuality: 0.5) ?? Data()

        return RichEditorView.Object.Attachment(
            type: .image,
            name: String(localized: "Tool Image \(index + 1)"),
            previewImage: previewData,
            imageRepresentation: compressed,
            textRepresentation: "",
            storageSuffix: suffix
        )
    }

    private func compressImage(_ image: UIImage) -> Data? {
        var imageToCompress = image

        // 如果图片太大，先缩小尺寸
        if image.size.width > 1024 || image.size.height > 1024 {
            let aspectWidth = 1024 / image.size.width
            let aspectHeight = 1024 / image.size.height
            let aspectRatio = min(aspectWidth, aspectHeight)
            let newSize = CGSize(
                width: image.size.width * aspectRatio,
                height: image.size.height * aspectRatio
            )

            if let resized = resizeImage(image, to: newSize) {
                imageToCompress = resized
            }
        }

        // 压缩为 JPEG
        return imageToCompress.jpegData(compressionQuality: 0.1)
    }

    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func mimeTypeToExtension(_ mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "image/png":
            "png"
        case "image/jpeg", "image/jpg":
            "jpg"
        case "image/gif":
            "gif"
        case "image/webp":
            "webp"
        case "image/bmp":
            "bmp"
        case "image/tiff":
            "tiff"
        default:
            "jpg" // 默认使用 jpg
        }
    }
}

extension MCPTool {
    private func convertMCPSchemaToJSONValues(_ mcpSchema: Value?) -> [String: JSONValue] {
        guard let mcpSchema else {
            return ["type": .string("object"), "properties": .object([:]), "additionalProperties": .bool(false)]
        }

        if case let .object(dict) = convertMCPValueToJSONValue(mcpSchema) {
            return dict
        }
        return ["type": .string("object"), "properties": .object([:]), "additionalProperties": .bool(false)]
    }

    private func convertMCPValueToJSONValue(_ value: Value) -> JSONValue {
        switch value {
        case let .string(string):
            .string(string)
        case let .int(int):
            .int(int)
        case let .double(double):
            .double(double)
        case let .bool(bool):
            .bool(bool)
        case let .array(values):
            .array(values.map { convertMCPValueToJSONValue($0) })
        case let .object(dict):
            .object(dict.mapValues { convertMCPValueToJSONValue($0) })
        case .null:
            .null(NSNull())
        case let .data(mimeType: mimeType, _):
            .string("[Data: \(mimeType ?? "unknown")]")
        }
    }

    func convertJSONValueToMCPValue(_ jsonValue: Any) -> Value? {
        switch jsonValue {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if number.isBool {
                return .bool(number.boolValue)
            } else if number.isInteger {
                return .int(number.intValue)
            } else {
                return .double(number.doubleValue)
            }
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let array as [Any]:
            let values = array.compactMap { convertJSONValueToMCPValue($0) }
            return .array(values)
        case let dict as [String: Any]:
            let pairs = dict.compactMapValues { convertJSONValueToMCPValue($0) }
            return .object(pairs)
        case is NSNull:
            return .null
        default:
            return nil
        }
    }
}
