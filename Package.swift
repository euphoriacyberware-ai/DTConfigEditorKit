// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DTConfigEditorKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "DTConfigEditorKit",
            targets: ["DTConfigEditorKit"]
        ),
        .library(
            name: "DTConfigBridge",
            targets: ["DTConfigBridge"]
        ),
        .executable(
            name: "configlint",
            targets: ["configlint"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(path: "Reference/DTClient"),
    ],
    targets: [
        .target(name: "DTConfigCore"),
        .executableTarget(
            name: "configlint",
            dependencies: [
                "DTConfigCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "DTConfigBridge",
            dependencies: [
                "DTConfigCore",
                .product(name: "DrawThingsClient", package: "DTClient"),
            ]
        ),
        .target(
            name: "DTConfigEditorKit",
            dependencies: ["DTConfigCore"]
        ),
        .testTarget(
            name: "DTConfigCoreTests",
            dependencies: ["DTConfigCore"]
        ),
        .testTarget(
            name: "ConfigLintTests",
            dependencies: ["DTConfigCore"]
        ),
        .testTarget(
            name: "DTConfigBridgeTests",
            dependencies: [
                "DTConfigBridge",
                "DTConfigCore",
                .product(name: "DrawThingsClient", package: "DTClient"),
            ]
        ),
        .testTarget(
            name: "DTConfigEditorKitTests",
            dependencies: ["DTConfigEditorKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
