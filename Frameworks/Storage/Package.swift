// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [
        .iOS(.v15),
        .macCatalyst(.v15),
        .macOS(.v11),
    ],
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(path: "../MarkdownNode"),
        .package(url: "https://github.com/Tencent/wcdb", from: "2.1.9"),
    ],
    targets: [
        .target(name: "Storage", dependencies: [
            "MarkdownNode",
            .product(name: "WCDBSwift", package: "wcdb"),
        ]),
    ]
)
