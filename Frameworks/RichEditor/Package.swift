// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RichEditor",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macCatalyst(.v15),
    ],
    products: [
        .library(name: "RichEditor", targets: ["RichEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mischa-hildebrand/AlignedCollectionViewFlowLayout", from: "1.1.3"),
        .package(url: "https://github.com/Lakr233/AlertController", from: "1.0.1"),
        .package(url: "https://github.com/Lakr233/ScrubberKit", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
    ],
    targets: [
        .target(name: "RichEditor", dependencies: [
            "AlertController",
            "AlignedCollectionViewFlowLayout",
            "ScrubberKit",
            .product(name: "OrderedCollections", package: "swift-collections"),
        ]),
    ]
)
