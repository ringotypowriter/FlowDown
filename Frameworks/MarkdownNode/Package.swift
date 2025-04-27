// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownNode",
    products: [
        .library(name: "MarkdownNode", targets: ["MarkdownNode"]),
    ],
    targets: [
        .target(name: "MarkdownNode"),
    ]
)
