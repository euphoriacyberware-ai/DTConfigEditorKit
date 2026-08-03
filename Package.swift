// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DTConfigEditorKit",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DTConfigEditorKit",
            targets: ["DTConfigEditorKit"]
        ),
    ],
    targets: [
        .target(name: "DTConfigCore"),
        .target(
            name: "DTConfigEditorKit",
            dependencies: ["DTConfigCore"]
        ),
        .testTarget(
            name: "DTConfigCoreTests",
            dependencies: ["DTConfigCore"]
        ),
        .testTarget(
            name: "DTConfigEditorKitTests",
            dependencies: ["DTConfigEditorKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
