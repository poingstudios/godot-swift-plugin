// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GodotSwiftPlugin",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "GodotSwiftPlugin",
            type: .static,
            targets: ["GodotSwiftPlugin"]
        ),
    ],
    targets: [
        .target(
            name: "GodotSwiftPlugin",
            dependencies: [],
            path: "Sources/GodotSwiftPlugin",
            exclude: ["Bridge"]
        ),
        .testTarget(
            name: "GodotSwiftPluginTests",
            dependencies: ["GodotSwiftPlugin"],
            path: "Tests/GodotSwiftPluginTests"
        ),
    ]
)
