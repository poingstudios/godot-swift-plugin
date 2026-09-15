#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2026-present Poing Studios
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

on_error() {
    local exit_code="$1"
    local line_no="$2"
    echo -e "\n${RED}================================================================${NC}" >&2
    echo -e "${RED}[ERROR] create_plugin.sh failed at line ${line_no} (exit code ${exit_code})${NC}" >&2
    echo -e "${RED}================================================================${NC}\n" >&2
    exit "${exit_code}"
}
trap 'on_error $? $LINENO' ERR

show_help() {
    echo "Usage: ./scripts/create_plugin.sh --name <PluginName> [options]"
    echo ""
    echo "Scaffolds a new Godot Swift plugin for iOS and macOS."
    echo ""
    echo "Options:"
    echo "  -n, --name <PluginName>        Plugin name in PascalCase (e.g. GodotGameCenter)"
    echo "  -o, --output-dir <path>        Output directory (default: ./<PluginName>)"
    echo "      --platforms <all|ios|macos> Target platforms: 'all' (iOS+macOS), 'ios' (iOS only), or 'macos' (macOS only) (default: all)"
    echo "      --build                    Compile initial binaries after scaffolding"
    echo "      --framework-path <path>    Local relative or absolute path to godot-swift-plugin"
    echo "  -h, --help                     Show this help message"
}

PLUGIN_NAME=""
OUTPUT_DIR=""
GODOT_VERSION="4.6"
FRAMEWORK_PATH=""
PLATFORMS_CHOICE="all"
RUN_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            PLUGIN_NAME="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --platforms)
            PLATFORMS_CHOICE="$2"
            shift 2
            ;;
        --build)
            RUN_BUILD=true
            shift
            ;;
        --framework-path)
            FRAMEWORK_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [ -z "${PLUGIN_NAME}" ]; then
                PLUGIN_NAME="$1"
                shift
            else
                echo -e "${RED}[ERROR] Unknown argument: $1${NC}" >&2
                show_help
                exit 1
            fi
            ;;
    esac
done

# Check if interactive mode is needed
prompt_input() {
    local prompt_msg="$1"
    local default_val="${2:-}"
    local result_var="$3"
    local user_input=""

    if [ -n "${default_val}" ]; then
        printf "%b [%s]: %b" "${prompt_msg}" "${default_val}" "${NC}" >&2
    else
        printf "%b: %b" "${prompt_msg}" "${NC}" >&2
    fi

    if [ -e /dev/tty ]; then
        read -r user_input < /dev/tty
    elif [ -t 0 ]; then
        read -r user_input
    else
        user_input=""
    fi

    if [ -z "${user_input}" ]; then
        user_input="${default_val}"
    fi

    printf -v "${result_var}" "%s" "${user_input}"
}

if [ -z "${PLUGIN_NAME}" ]; then
    if [ -e /dev/tty ] || [ -t 0 ]; then
        echo -e "\n${CYAN}╭─────────────────────────────────────────────────────────────╮${NC}"
        echo -e "${CYAN}│            Godot Swift Plugin — Project Wizard              │${NC}"
        echo -e "${CYAN}│      Create official-grade Godot plugins with pure Swift    │${NC}"
        echo -e "${CYAN}╰─────────────────────────────────────────────────────────────╯${NC}\n"

        while true; do
            prompt_input "${CYAN}? Plugin Name in PascalCase (e.g. GodotGameCenter)${NC}" "" PLUGIN_NAME
            if [[ "${PLUGIN_NAME}" =~ ^[A-Z][A-Za-z0-9_]*$ ]]; then
                break
            else
                echo -e "${RED}[!] Invalid name. Plugin name must start with a capital letter (PascalCase).${NC}" >&2
            fi
        done

        if [ -z "${OUTPUT_DIR}" ]; then
            prompt_input "${CYAN}? Output directory${NC}" "./${PLUGIN_NAME}" OUTPUT_DIR
        fi

        echo -e "\n${CYAN}? Supported platforms:${NC}"
        echo -e "  1) iOS + macOS ${GREEN}(Recommended for in-editor testing)${NC}"
        echo -e "  2) iOS only"
        echo -e "  3) macOS only"
        prompt_input "${CYAN}  Select platform option${NC}" "1" PLAT_OPT
        if [ "${PLAT_OPT}" = "2" ]; then
            PLATFORMS_CHOICE="ios"
        elif [ "${PLAT_OPT}" = "3" ]; then
            PLATFORMS_CHOICE="macos"
        else
            PLATFORMS_CHOICE="all"
        fi

        prompt_input "\n${CYAN}? Compile initial binaries now? (Y/n)${NC}" "Y" BUILD_OPT
        if [[ "${BUILD_OPT}" =~ ^[Yy]$ ]]; then
            RUN_BUILD=true
        fi
        echo ""
    else
        echo -e "${RED}[ERROR] Plugin name is required (--name <PluginName>)${NC}" >&2
        show_help
        exit 1
    fi
fi

# Convert PascalCase to snake_case for folder and file names
SNAKE_NAME="$(python3 -c "
import re, sys
s = '${PLUGIN_NAME}'
s = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', s)
print(re.sub('([a-z0-9])([A-Z])', r'\1_\2', s).lower())
")"

if [ -z "${OUTPUT_DIR}" ]; then
    OUTPUT_DIR="$(pwd)/${PLUGIN_NAME}"
fi
mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}==> Scaffolding Godot Swift Plugin${NC}"
echo -e "${CYAN}    Plugin Name:   ${GREEN}${PLUGIN_NAME}${NC}"
echo -e "${CYAN}    Addon Slug:    ${GREEN}${SNAKE_NAME}${NC}"
echo -e "${CYAN}    Output Dir:    ${OUTPUT_DIR}${NC}"
echo -e "${CYAN}    Godot Version: ${GODOT_VERSION}+${NC}"
echo -e "${CYAN}================================================================${NC}"

# Setup Dependency string
if [ -n "${FRAMEWORK_PATH}" ]; then
    DEP_LINE=".package(path: \"${FRAMEWORK_PATH}\")"
elif [[ "${OUTPUT_DIR}" == "${REPO_ROOT}/"* ]] && [ -d "${REPO_ROOT}/Sources/GodotSwiftPlugin" ]; then
    REL_PATH="$(python3 -c "import os.path; print(os.path.relpath(os.path.realpath('${REPO_ROOT}'), os.path.realpath('${OUTPUT_DIR}/platforms/ios')))")"
    DEP_LINE=".package(path: \"${REL_PATH}\")"
else
    DEP_LINE=".package(url: \"https://github.com/poingstudios/godot-swift-plugin\", branch: \"master\")"
fi

# Create directory tree
mkdir -p "${OUTPUT_DIR}/platforms/ios/Sources/${PLUGIN_NAME}"
mkdir -p "${OUTPUT_DIR}/platforms/ios/Tests/${PLUGIN_NAME}Tests"
mkdir -p "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/internal"
mkdir -p "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/bin/stubs"
mkdir -p "${OUTPUT_DIR}/platforms/godot_editor/sample"
mkdir -p "${OUTPUT_DIR}/scripts"

# Copy GDExtension stubs for unsupported platforms
STUBS_SRC="${REPO_ROOT}/templates/stubs"
STUBS_DEST="${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/bin/stubs"
if [ -d "${STUBS_SRC}" ]; then
    cp -R "${STUBS_SRC}/"* "${STUBS_DEST}/"
else
    echo -e "${CYAN}==> Fetching precompiled GDExtension stubs from GitHub...${NC}"
    RAW_BASE="https://raw.githubusercontent.com/poingstudios/godot-swift-plugin/master/templates/stubs"
    curl -fsSL "${RAW_BASE}/libstub_macos.dylib" -o "${STUBS_DEST}/libstub_macos.dylib" 2>/dev/null || true
    curl -fsSL "${RAW_BASE}/stub_windows.dll" -o "${STUBS_DEST}/stub_windows.dll" 2>/dev/null || true
    curl -fsSL "${RAW_BASE}/libstub_linux.so" -o "${STUBS_DEST}/libstub_linux.so" 2>/dev/null || true
    curl -fsSL "${RAW_BASE}/libstub_android.so" -o "${STUBS_DEST}/libstub_android.so" 2>/dev/null || true
    mkdir -p "${STUBS_DEST}/stub_ios.xcframework/ios-arm64"
    mkdir -p "${STUBS_DEST}/stub_ios.xcframework/ios-arm64_x86_64-simulator"
    curl -fsSL "${RAW_BASE}/stub_ios.xcframework/Info.plist" -o "${STUBS_DEST}/stub_ios.xcframework/Info.plist" 2>/dev/null || true
    curl -fsSL "${RAW_BASE}/stub_ios.xcframework/ios-arm64/libstub_ios_device.a" -o "${STUBS_DEST}/stub_ios.xcframework/ios-arm64/libstub_ios_device.a" 2>/dev/null || true
    curl -fsSL "${RAW_BASE}/stub_ios.xcframework/ios-arm64_x86_64-simulator/libstub_ios_sim.a" -o "${STUBS_DEST}/stub_ios.xcframework/ios-arm64_x86_64-simulator/libstub_ios_sim.a" 2>/dev/null || true
fi

# 1. Package.swift
cat <<EOF > "${OUTPUT_DIR}/platforms/ios/Package.swift"
// swift-tools-version: 5.9
// MIT License

import PackageDescription

let package = Package(
    name: "${PLUGIN_NAME}",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "${PLUGIN_NAME}",
            type: .dynamic,
            targets: ["${PLUGIN_NAME}"]
        ),
        .library(
            name: "${PLUGIN_NAME}Static",
            type: .static,
            targets: ["${PLUGIN_NAME}"]
        ),
    ],
    dependencies: [
        ${DEP_LINE}
    ],
    targets: [
        .target(
            name: "${PLUGIN_NAME}",
            dependencies: [
                .product(name: "GodotSwiftPlugin", package: "godot-swift-plugin")
            ],
            path: "Sources/${PLUGIN_NAME}"
        ),
        .testTarget(
            name: "${PLUGIN_NAME}Tests",
            dependencies: ["${PLUGIN_NAME}"],
            path: "Tests/${PLUGIN_NAME}Tests"
        ),
    ]
)
EOF

# 2. Plugin Swift Source
cat <<EOF > "${OUTPUT_DIR}/platforms/ios/Sources/${PLUGIN_NAME}/${PLUGIN_NAME}.swift"
// MIT License

import Foundation
import GodotSwiftPlugin

public final class ${PLUGIN_NAME}: GodotPlugin {
    public override class var pluginName: String { "${PLUGIN_NAME}" }

    @Signal
    public var sampleSignalEmitted

    public required init() {
        super.init()
    }

    @objc public func hello(name: String) -> String {
        return "Hello \(name) from \(${PLUGIN_NAME}.pluginName)!"
    }

    @objc public func trigger_sample_signal(message: String) {
        sampleSignalEmitted.emit(message)
    }
}
EOF

# 3. Unit Test Source
cat <<EOF > "${OUTPUT_DIR}/platforms/ios/Tests/${PLUGIN_NAME}Tests/${PLUGIN_NAME}Tests.swift"
// MIT License

import XCTest
@testable import ${PLUGIN_NAME}

final class ${PLUGIN_NAME}Tests: XCTestCase {
    func testHello() {
        let plugin = ${PLUGIN_NAME}()
        XCTAssertEqual(plugin.hello(name: "Godot"), "Hello Godot from ${PLUGIN_NAME}!")
    }
}
EOF

# 4. export_plugin.gd
cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/internal/export_plugin.gd"
# MIT License

extends EditorExportPlugin

const PLUGIN_NAME := "${PLUGIN_NAME}"


func _get_name() -> String:
	return PLUGIN_NAME


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformIOS


func _export_begin(
	features: PackedStringArray,
	_is_debug: bool,
	_path: String,
	_flags: int
) -> void:
	if not features.has("ios"):
		return

	_add_linker_flags("-ObjC")


func _add_linker_flags(flags: String) -> void:
	add_apple_embedded_platform_linker_flags(flags)
EOF

# 5. plugin.cfg
cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/plugin.cfg"
[plugin]

name="${PLUGIN_NAME}"
description="${PLUGIN_NAME} iOS & macOS plugin for Godot."
author="Poing Studios"
version="1.0.0"
script="plugin.gd"
EOF

# 6. plugin.gd
cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/plugin.gd"
# MIT License

@tool
extends EditorPlugin

const ExportPlugin := preload("internal/export_plugin.gd")
var _export_plugin: ExportPlugin


func _enter_tree() -> void:
	_export_plugin = ExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
EOF

# 7. <slug>.gd (GDScript public API)
cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/${SNAKE_NAME}.gd"
# MIT License

class_name ${PLUGIN_NAME}
extends RefCounted

signal sample_signal_emitted(message: String)

static var _singleton: Object


static func get_singleton() -> Object:
	if _singleton == null:
		if Engine.has_singleton("${PLUGIN_NAME}"):
			_singleton = Engine.get_singleton("${PLUGIN_NAME}")
	return _singleton


static func hello(p_name: String) -> String:
	var s := get_singleton()
	if s and s.has_method("hello"):
		return s.hello(p_name)
	return "Plugin ${PLUGIN_NAME} not available on this platform"
EOF

# 8. <slug>.gdextension
MACOS_LIB_ENTRY=""
if [ "${PLATFORMS_CHOICE}" = "ios" ]; then
    MACOS_LIB_ENTRY="macos.debug = \"res://addons/${SNAKE_NAME}/bin/stubs/libstub_macos.dylib\"
macos.release = \"res://addons/${SNAKE_NAME}/bin/stubs/libstub_macos.dylib\""
else
    MACOS_LIB_ENTRY="macos.debug = \"res://addons/${SNAKE_NAME}/bin/lib${PLUGIN_NAME}.dylib\"
macos.release = \"res://addons/${SNAKE_NAME}/bin/lib${PLUGIN_NAME}.dylib\""
fi

IOS_LIB_ENTRY=""
if [ "${PLATFORMS_CHOICE}" = "macos" ]; then
    IOS_LIB_ENTRY="ios.debug = \"res://addons/${SNAKE_NAME}/bin/stubs/stub_ios.xcframework\"
ios.release = \"res://addons/${SNAKE_NAME}/bin/stubs/stub_ios.xcframework\"
ios.simulator.debug = \"res://addons/${SNAKE_NAME}/bin/stubs/stub_ios.xcframework\"
ios.simulator.release = \"res://addons/${SNAKE_NAME}/bin/stubs/stub_ios.xcframework\""
else
    IOS_LIB_ENTRY="ios.debug = \"res://addons/${SNAKE_NAME}/bin/${PLUGIN_NAME}.xcframework\"
ios.release = \"res://addons/${SNAKE_NAME}/bin/${PLUGIN_NAME}.xcframework\"
ios.simulator.debug = \"res://addons/${SNAKE_NAME}/bin/${PLUGIN_NAME}.xcframework\"
ios.simulator.release = \"res://addons/${SNAKE_NAME}/bin/${PLUGIN_NAME}.xcframework\""
fi

INCLUDE_TAGS_STR="[\"ios\", \"macos\"]"
if [ "${PLATFORMS_CHOICE}" = "ios" ]; then
    INCLUDE_TAGS_STR="[\"ios\"]"
elif [ "${PLATFORMS_CHOICE}" = "macos" ]; then
    INCLUDE_TAGS_STR="[\"macos\"]"
fi

cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/${SNAKE_NAME}.gdextension"
[configuration]
entry_symbol = "godot_swift_extension_init"
compatibility_minimum = "${GODOT_VERSION}"
include_tags = ${INCLUDE_TAGS_STR}

[libraries]
${MACOS_LIB_ENTRY}
${IOS_LIB_ENTRY}
windows.debug.x86_64 = "res://addons/${SNAKE_NAME}/bin/stubs/stub_windows_x86_64.dll"
windows.release.x86_64 = "res://addons/${SNAKE_NAME}/bin/stubs/stub_windows_x86_64.dll"
windows.debug.arm64 = "res://addons/${SNAKE_NAME}/bin/stubs/stub_windows_arm64.dll"
windows.release.arm64 = "res://addons/${SNAKE_NAME}/bin/stubs/stub_windows_arm64.dll"

linux.debug.x86_64 = "res://addons/${SNAKE_NAME}/bin/stubs/libstub_linux_x86_64.so"
linux.release.x86_64 = "res://addons/${SNAKE_NAME}/bin/stubs/libstub_linux_x86_64.so"
linux.debug.arm64 = "res://addons/${SNAKE_NAME}/bin/stubs/libstub_linux_arm64.so"
linux.release.arm64 = "res://addons/${SNAKE_NAME}/bin/stubs/libstub_linux_arm64.so"

android.debug.arm64 = "res://addons/${SNAKE_NAME}/bin/stubs/libstub_android_arm64.so"
android.release.arm64 = "res://addons/${SNAKE_NAME}/bin/stubs/libstub_android_arm64.so"
android.debug.x86_64 = "res://addons/${SNAKE_NAME}/bin/stubs/libstub_android_x86_64.so"
android.release.x86_64 = "res://addons/${SNAKE_NAME}/bin/stubs/libstub_android_x86_64.so"
EOF

# 9. project.godot
cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/project.godot"
; Engine configuration file.
config_version=5

[application]

config/name="${PLUGIN_NAME}"
run/main_scene="res://sample/sample.tscn"
config/features=PackedStringArray("${GODOT_VERSION}", "Forward Plus")

[editor_plugins]

enabled=PackedStringArray("res://addons/${SNAKE_NAME}/plugin.cfg")
EOF

# 10. Sample Scene & Script
cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/sample/sample.gd"
extends Control

const ${PLUGIN_NAME} := preload("res://addons/${SNAKE_NAME}/${SNAKE_NAME}.gd")


func _ready() -> void:
	print(${PLUGIN_NAME}.hello("World"))
EOF

cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/sample/sample.tscn"
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://sample/sample.gd" id="1_sample"]

[node name="Sample" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_sample")

[node name="Label" type="Label" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -20.0
offset_right = 100.0
offset_bottom = 20.0
grow_horizontal = 2
grow_vertical = 2
text = "${PLUGIN_NAME} Sample"
horizontal_alignment = 1
EOF

# 11. Minimal scripts/build_local.sh wrapper delegating to SPM command plugin
cat <<EOF > "${OUTPUT_DIR}/scripts/build_local.sh"
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="\${SCRIPT_DIR}/../platforms/ios"

exec swift package --package-path "\${PACKAGE_DIR}" --disable-sandbox --allow-writing-to-package-directory godot-build "\$@"
EOF
chmod +x "${OUTPUT_DIR}/scripts/build_local.sh"

# 12. Minimal scripts/test_local.sh
cat <<EOF > "${OUTPUT_DIR}/scripts/test_local.sh"
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec swift test --package-path "\${SCRIPT_DIR}/../platforms/ios"
EOF
chmod +x "${OUTPUT_DIR}/scripts/test_local.sh"

# 13. .gitignore
cat <<EOF > "${OUTPUT_DIR}/.gitignore"
.DS_Store
.build/
.swiftpm/
DerivedData/
build/
*.xcworkspace
*.xcuserdata

.godot/
*.translation
*.pck
*.apk
*.aab
EOF

# 14. README.md
cat <<EOF > "${OUTPUT_DIR}/README.md"
# ${PLUGIN_NAME}

Official-grade Godot 4.x plugin for iOS and macOS, powered by [Godot Swift Plugin](https://github.com/poingstudios/godot-swift-plugin).

## Quickstart

### 1. Build Binaries
\`\`\`bash
./scripts/build_local.sh all
\`\`\`

### 2. Run Unit Tests
\`\`\`bash
./scripts/test_local.sh
\`\`\`
EOF

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}==> Plugin '${PLUGIN_NAME}' successfully scaffolded at:${NC}"
echo -e "${GREEN}    ${OUTPUT_DIR}${NC}"
echo -e "${GREEN}================================================================${NC}\n"

if [ "${RUN_BUILD}" = true ]; then
    echo -e "${CYAN}==> Running initial compilation (${PLATFORMS_CHOICE})...${NC}"
    (cd "${OUTPUT_DIR}" && ./scripts/build_local.sh "${PLATFORMS_CHOICE}")
else
    echo -e "${GREEN}==> To compile manually:${NC}"
    echo -e "${GREEN}    cd ${OUTPUT_DIR} && ./scripts/build_local.sh all${NC}\n"
fi
