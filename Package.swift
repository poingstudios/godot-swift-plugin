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
        .plugin(
            name: "GodotBuildPlugin",
            targets: ["GodotBuildPlugin"]
        ),
    ],
    targets: [
        .target(
            name: "CGDExtensionInterface",
            path: "Sources/CGDExtensionInterface",
            publicHeadersPath: "include"
        ),
        .target(
            name: "GodotSwiftPlugin",
            dependencies: ["CGDExtensionInterface"],
            path: "Sources/GodotSwiftPlugin"
        ),
        .testTarget(
            name: "GodotSwiftPluginTests",
            dependencies: ["GodotSwiftPlugin"],
            path: "Tests/GodotSwiftPluginTests"
        ),
        .plugin(
            name: "GodotBuildPlugin",
            capability: .command(
                intent: .custom(
                    verb: "godot-build",
                    description: "Builds Godot Swift plugin binaries for iOS and macOS"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Outputs compiled binaries to Godot addon bin/ directory")
                ]
            ),
            path: "Plugins/GodotBuildPlugin"
        ),
    ]
)
