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
        var outputDir: String?
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
            } else if arg == "-o" || arg == "--output-dir" {
                if i + 1 < arguments.count {
                    outputDir = arguments[i + 1]
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

        // 1. Resolve Output Directory (addons/<slug>/bin or build/artifacts fallback)
        if outputDir == nil {
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
        }

        let resolvedOutputDir = outputDir ?? context.package.directory.appending(subpath: "build/artifacts").string
        try fileManager.createDirectory(atPath: resolvedOutputDir, withIntermediateDirectories: true)

        // 2. Delegate build to universal builder (build_plugin.sh)
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

        guard let finalBuilder = builderScript else {
            print("[ERROR] Unable to locate scripts/build_plugin.sh from package dependencies or repository hierarchy.")
            Foundation.exit(1)
        }


        var builderArgs = [
            finalBuilder,
            "--package-dir", packageDir,
            "--name", pluginName,
            "--output-dir", resolvedOutputDir,
            "--target", target,
            "--configuration", config
        ]
        if clean {
            builderArgs.append("--clean")
        }
        builderArgs.append(contentsOf: passthroughArgs)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = builderArgs
        proc.standardOutput = FileHandle.standardOutput
        proc.standardError = FileHandle.standardError
        proc.standardInput = FileHandle.standardInput
        try proc.run()
        proc.waitUntilExit()

        if proc.terminationStatus != 0 {
            Foundation.exit(proc.terminationStatus)
        }
    }
}

