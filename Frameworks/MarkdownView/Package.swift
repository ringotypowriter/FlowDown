// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownView",
    platforms: [
        .iOS(.v14),
        .macCatalyst(.v14),
    ],
    products: [
        .library(name: "MarkdownView", targets: ["MarkdownView"]),
    ],
    dependencies: [
        .package(path: "../MarkdownNode"),
        .package(path: "../ObjectPool"),
        .package(url: "https://github.com/Lakr233/Splash", from: "0.17.0"),
        .package(url: "https://github.com/Lakr233/Litext", from: "0.4.1"),
        .package(url: "https://github.com/apple/swift-cmark", from: "0.5.0"),
    ],
    targets: [
        .target(name: "MarkdownView", dependencies: [
            "Litext",
            "Splash",
            "MarkdownParser",
            "ObjectPool",
        ]),
        .target(name: "MarkdownParser", dependencies: [
            "MarkdownNode",
            .product(name: "cmark-gfm", package: "swift-cmark"),
            .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
        ]),
    ]
)
