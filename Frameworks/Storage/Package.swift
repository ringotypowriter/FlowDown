// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
    ],
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/MarkdownView", from: "3.4.2"),
        .package(url: "https://github.com/Tencent/wcdb", from: "2.1.11"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.2.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19"),
        .package(path: "../Logger"),
    ],
    targets: [
        .target(name: "Storage", dependencies: [
            .product(name: "MarkdownParser", package: "MarkdownView"),
            .product(name: "WCDBSwift", package: "wcdb"),
            .product(name: "OrderedCollections", package: "swift-collections"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            .product(name: "Logger", package: "Logger"),
        ]),
    ]
)
