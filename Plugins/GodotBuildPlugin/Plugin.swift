// MIT License
//
// Copyright (c) 2026-present Poing Studios
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import PackagePlugin
import Foundation

@main
struct GodotBuildPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let packageDir = context.package.directory.string
        let pluginName = context.package.displayName
        let fileManager = FileManager.default

        var target = "all"
        var config = "Release"
        var clean = false
        var passthroughArgs: [String] = []

        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            if arg == "-t" || arg == "--target" {
                if i + 1 < arguments.count {
                    target = arguments[i + 1]
                    i += 2
                    continue
                }
            } else if arg == "-c" || arg == "--configuration" {
                if i + 1 < arguments.count {
                    config = arguments[i + 1]
                    i += 2
                    continue
                }
            } else if arg == "--clean" {
                clean = true
                i += 1
                continue
            } else if ["ios", "macos", "all"].contains(arg) {
                target = arg
                i += 1
                continue
            } else {
                passthroughArgs.append(arg)
                i += 1
            }
        }

        // 1. Resolve Output Directory (addons/<slug>/bin)
        var outputDir: String?
        let searchCandidates = [
            context.package.directory.appending(subpath: "../godot_editor/addons").string,
            context.package.directory.appending(subpath: "../../godot_editor/addons").string,
            context.package.directory.appending(subpath: "platforms/godot_editor/addons").string,
            context.package.directory.appending(subpath: "../addons").string,
            context.package.directory.appending(subpath: "addons").string
        ]

        for parent in searchCandidates {
            if fileManager.fileExists(atPath: parent) {
                if let items = try? fileManager.subpathsOfDirectory(atPath: parent) {
                    for item in items {
                        if item.hasSuffix("/bin") || item == "bin" {
                            outputDir = URL(fileURLWithPath: parent).appendingPathComponent(item).path
                            break
                        }
                    }
                }
            }
            if outputDir != nil { break }
        }

        guard let resolvedOutputDir = outputDir else {
            print("[ERROR] Could not auto-detect Godot addon 'bin' directory. Please ensure an 'addons/<slug>/bin' exists.")
            Foundation.exit(1)
        }

        try fileManager.createDirectory(atPath: resolvedOutputDir, withIntermediateDirectories: true)

        print("\u{001B}[1mBuilding Godot Swift Plugin...\u{001B}[0m")
        print("  \u{001B}[2m•\u{001B}[0m Plugin:        \(pluginName)")
        print("  \u{001B}[2m•\u{001B}[0m Target:        \(target)")
        print("  \u{001B}[2m•\u{001B}[0m Configuration: \(config)")
        print("  \u{001B}[2m•\u{001B}[0m Output:        \(resolvedOutputDir)\n")

        // 2. Build macOS dynamic library if requested
        if target == "macos" || target == "all" {
            print("\n==> [macOS] Building dynamic library via SwiftPM...")
            let buildParams = PackageManager.BuildParameters(
                configuration: config.lowercased() == "debug" ? .debug : .release,
                logging: .concise
            )

            let result = try packageManager.build(
                .product(pluginName),
                parameters: buildParams
            )

            if !result.succeeded {
                print("[ERROR] macOS compilation failed via SwiftPM PackageManager.")
                Foundation.exit(1)
            }

            for artifact in result.builtArtifacts {
                if artifact.path.extension == "dylib" {
                    let destDylib = URL(fileURLWithPath: resolvedOutputDir).appendingPathComponent("lib\(pluginName).dylib").path
                    if fileManager.fileExists(atPath: destDylib) {
                        try? fileManager.removeItem(atPath: destDylib)
                    }
                    try fileManager.copyItem(atPath: artifact.path.string, toPath: destDylib)
                    let chmodProc = Process()
                    chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
                    chmodProc.arguments = ["755", destDylib]
                    try? chmodProc.run()
                    chmodProc.waitUntilExit()
                    print("==> [macOS] lib\(pluginName).dylib deployed to: \(destDylib)")
                    break
                }
            }
        }

        // 3. Build iOS XCFramework if requested
        if target == "ios" || target == "all" {
            var builderScript: String?

            for dep in context.package.dependencies {
                let candidate = dep.package.directory.appending(subpath: "scripts/build_plugin.sh").string
                if fileManager.fileExists(atPath: candidate) {
                    builderScript = candidate
                    break
                }
            }

            if builderScript == nil {
                let scriptCandidates = [
                    context.package.directory.appending(subpath: "../../scripts/build_plugin.sh").string,
                    context.package.directory.appending(subpath: "../../../scripts/build_plugin.sh").string,
                    context.package.directory.appending(subpath: "scripts/build_plugin.sh").string,
                    context.package.directory.appending(subpath: ".build/checkouts/godot-swift-plugin/scripts/build_plugin.sh").string
                ]

                for candidate in scriptCandidates {
                    if fileManager.fileExists(atPath: candidate) {
                        builderScript = candidate
                        break
                    }
                }
            }

            if builderScript == nil {
                let cacheDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".cache/godot-swift").path
                try? fileManager.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
                let cachedScript = URL(fileURLWithPath: cacheDir).appendingPathComponent("build_plugin.sh").path
                if !fileManager.fileExists(atPath: cachedScript) {
                    print("==> Downloading universal builder script...")
                    let curlProc = Process()
                    curlProc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                    curlProc.arguments = ["-fsSL", "https://raw.githubusercontent.com/poingstudios/godot-swift-plugin/master/scripts/build_plugin.sh", "-o", cachedScript]
                    try curlProc.run()
                    curlProc.waitUntilExit()
                    let chmodProc = Process()
                    chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
                    chmodProc.arguments = ["+x", cachedScript]
                    try? chmodProc.run()
                    chmodProc.waitUntilExit()
                }
                builderScript = cachedScript
            }

            guard let finalBuilder = builderScript else {
                print("[ERROR] Unable to locate or download build_plugin.sh for iOS packaging.")
                Foundation.exit(1)
            }

            var builderArgs = [
                finalBuilder,
                "--package-dir", packageDir,
                "--name", pluginName,
                "--output-dir", resolvedOutputDir,
                "--target", "ios",
                "--configuration", config,
                "--quiet-header"
            ]
            if clean {
                builderArgs.append("--clean")
            }
            builderArgs.append(contentsOf: passthroughArgs)

            let iosProc = Process()
            iosProc.executableURL = URL(fileURLWithPath: "/bin/bash")
            iosProc.arguments = builderArgs
            iosProc.standardOutput = FileHandle.standardOutput
            iosProc.standardError = FileHandle.standardError
            iosProc.standardInput = FileHandle.standardInput
            try iosProc.run()
            iosProc.waitUntilExit()

            if iosProc.terminationStatus != 0 {
                Foundation.exit(iosProc.terminationStatus)
            }
        }

        print("\n  \u{001B}[1;32m✓\u{001B}[0m Build completed successfully (\(target))\n")
    }
}
