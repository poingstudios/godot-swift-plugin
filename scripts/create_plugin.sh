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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
    # shellcheck source=scripts/common.sh
    source "${SCRIPT_DIR}/common.sh"
fi


on_error() {
    local exit_code="$1"
    local line_no="$2"
    echo -e "\n${RED}✖ Error:${NC} create_plugin.sh failed at line ${line_no} (exit code ${exit_code})\n" >&2
    exit "${exit_code}"
}
trap 'on_error $? $LINENO' ERR

show_help() {
    print_welcome_banner
    echo "Usage: ./scripts/create_plugin.sh --name <PluginName> [options]"
    echo ""
    echo "Creates a new Godot Swift plugin project for iOS and macOS."
    echo ""
    echo "Options:"
    echo "  -n, --name <PluginName>        Plugin name in PascalCase (e.g. GodotGameCenter)"
    echo "  -o, --output-dir <path>        Output directory (default: ./<PluginName>)"
    echo "      --platforms <ios|all|macos> Target platforms: 'ios' (iOS only), 'all' (iOS+macOS), or 'macos' (macOS only) (default: ios)"
    echo "      --build                    Compile initial binaries after creating the project"
    echo "      --framework-path <path>    Local relative or absolute path to godot-swift-plugin"
    echo "  -h, --help                     Show this help message"
}

PLUGIN_NAME=""
OUTPUT_DIR=""
GODOT_VERSION="4.6"
FRAMEWORK_PATH=""
PLATFORMS_CHOICE="ios"
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
        printf "%b %b[%s]%b: " "${prompt_msg}" "${DIM}" "${default_val}" "${NC}" >&2
    else
        printf "%b: " "${prompt_msg}" >&2
    fi

    if [ -t 0 ]; then
        read -e -r user_input
    elif [ -e /dev/tty ]; then
        read -e -r user_input < /dev/tty
    else
        user_input=""
    fi

    if [ -z "${user_input}" ]; then
        user_input="${default_val}"
    fi

    printf -v "${result_var}" "%s" "${user_input}"
}

prompt_select() {
    local prompt_msg="$1"
    local default_idx="$2"
    local result_var="$3"
    shift 3
    local options=("$@")
    local selected="${default_idx}"
    local total=${#options[@]}

    local tty_in="/dev/tty"
    if [ ! -e /dev/tty ] || [ ! -t 0 ]; then
        printf -v "${result_var}" "%s" "${selected}"
        return 0
    fi

    printf "\n%b:\n" "${prompt_msg}" >&2
    printf "\033[?25l" >&2

    local first_render=true
    while true; do
        if [ "${first_render}" = false ]; then
            for ((l=0; l<total; l++)); do
                printf "\033[1A\033[2K" >&2
            done
        else
            first_render=false
        fi

        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                printf "  \033[1;36m❯ %s\033[0m\n" "${options[$i]}" >&2
            else
                printf "    \033[2m%s\033[0m\n" "${options[$i]}" >&2
            fi
        done

        local key=""
        IFS= read -rsn1 key < "${tty_in}" || key=""
        if [ "$key" = $'\x1b' ]; then
            local rest=""
            read -rsn2 -t 1 rest < "${tty_in}" || rest=""
            key+="$rest"
        fi

        case "$key" in
            $'\x1b[A'|[kK])
                ((selected--)) || true
                if [ "$selected" -lt 0 ]; then
                    selected=$((total - 1))
                fi
                ;;
            $'\x1b[B'|[jJ])
                ((selected++)) || true
                if [ "$selected" -ge "$total" ]; then
                    selected=0
                fi
                ;;
            "")
                break
                ;;
            [1-9])
                local opt_idx=$((key - 1))
                if [ "$opt_idx" -ge 0 ] && [ "$opt_idx" -lt "$total" ]; then
                    selected=$opt_idx
                    break
                fi
                ;;
        esac
    done

    printf "\033[?25h" >&2

    for ((l=0; l<total; l++)); do
        printf "\033[1A\033[2K" >&2
    done
    printf "  \033[1;32m✓ %s\033[0m\n" "${options[$selected]}" >&2

    printf -v "${result_var}" "%s" "${selected}"
}

if [ -z "${PLUGIN_NAME}" ]; then
    if [ -e /dev/tty ] || [ -t 0 ]; then
        print_welcome_banner

        while true; do
            prompt_input "${CYAN}? Plugin Name in PascalCase (e.g. GodotGameCenter)${NC}" "" PLUGIN_NAME
            if [[ "${PLUGIN_NAME}" =~ ^[A-Z][A-Za-z0-9_]*$ ]]; then
                break
            else
                echo -e "  ${RED}✖ Invalid name. Plugin name must start with a capital letter (PascalCase).${NC}" >&2
            fi
        done

        while true; do
            prompt_input "${CYAN}? Output directory${NC}" "./${PLUGIN_NAME}" OUTPUT_DIR
            if [ -d "${OUTPUT_DIR}" ] && [ -n "$(ls -A "${OUTPUT_DIR}" 2>/dev/null)" ]; then
                echo -e "  ${RED}✖ Directory '${OUTPUT_DIR}' already exists and is not empty. Please choose another path.${NC}" >&2
                OUTPUT_DIR=""
            else
                break
            fi
        done

        prompt_select "${CYAN}? Supported platforms${NC}" 0 PLAT_IDX \
            "iOS only" \
            "iOS + macOS" \
            "macOS only"

        if [ "${PLAT_IDX}" = "1" ]; then
            PLATFORMS_CHOICE="all"
        elif [ "${PLAT_IDX}" = "2" ]; then
            PLATFORMS_CHOICE="macos"
        else
            PLATFORMS_CHOICE="ios"
        fi

        prompt_select "${CYAN}? Compile initial binaries now?${NC}" 0 BUILD_IDX \
            "Yes" \
            "No"

        if [ "${BUILD_IDX}" = "0" ]; then
            RUN_BUILD=true
        fi
        echo ""
    else
        echo -e "${RED}✖ Error:${NC} Plugin name is required (--name <PluginName>)\n" >&2
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

if [ -d "${OUTPUT_DIR}" ] && [ -n "$(ls -A "${OUTPUT_DIR}" 2>/dev/null)" ]; then
    echo -e "${RED}✖ Error:${NC} Destination directory '${OUTPUT_DIR}' already exists and is not empty.\n" >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PLATFORMS_LABEL="iOS only"
if [ "${PLATFORMS_CHOICE}" = "all" ]; then
    PLATFORMS_LABEL="iOS + macOS"
elif [ "${PLATFORMS_CHOICE}" = "macos" ]; then
    PLATFORMS_LABEL="macOS only"
fi

echo -e "${BOLD}Creating Godot Swift Plugin...${NC}"
echo -e "  ${DIM}•${NC} Plugin Name:   ${GREEN}${PLUGIN_NAME}${NC}"
echo -e "  ${DIM}•${NC} Addon Slug:    ${GREEN}${SNAKE_NAME}${NC}"
echo -e "  ${DIM}•${NC} Directory:     ${OUTPUT_DIR}"
echo -e "  ${DIM}•${NC} Platforms:     ${PLATFORMS_LABEL}"
echo -e "  ${DIM}•${NC} Godot Version: ${GODOT_VERSION}+"
echo ""

# Setup Dependency string
if [ -n "${FRAMEWORK_PATH}" ]; then
    DEP_LINE=".package(path: \"${FRAMEWORK_PATH}\")"
elif [ -d "${REPO_ROOT}/Sources/GodotSwiftPlugin" ]; then
    REL_PATH="$(python3 -c "import os.path; print(os.path.relpath(os.path.realpath('${REPO_ROOT}'), os.path.realpath('${OUTPUT_DIR}/platforms/apple')))")"
    DEP_LINE=".package(path: \"${REL_PATH}\")"
else
    DEP_LINE=".package(url: \"https://github.com/poingstudios/godot-swift-plugin\", branch: \"master\")"
fi

# Create directory tree
mkdir -p "${OUTPUT_DIR}/platforms/apple/Sources/${PLUGIN_NAME}"
mkdir -p "${OUTPUT_DIR}/platforms/apple/Tests/${PLUGIN_NAME}Tests"
mkdir -p "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/internal"
mkdir -p "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/bin/stubs"
mkdir -p "${OUTPUT_DIR}/platforms/godot_editor/sample"
mkdir -p "${OUTPUT_DIR}/scripts"

# Copy GDExtension stubs for unsupported platforms
STUBS_SRC="${REPO_ROOT}/templates/stubs"
STUBS_DEST="${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/bin/stubs"

COMMON_STUBS=(
    "stub_windows.dll"
    "stub_windows_x86_64.dll"
    "stub_windows_arm64.dll"
    "libstub_linux.so"
    "libstub_linux_x86_64.so"
    "libstub_linux_arm64.so"
    "libstub_android.so"
    "libstub_android_arm64.so"
    "libstub_android_x86_64.so"
)

# macOS stub is only needed if the plugin is iOS-only
if [ "${PLATFORMS_CHOICE}" = "ios" ]; then
    COMMON_STUBS+=("libstub_macos.dylib")
fi

if [ -d "${STUBS_SRC}" ]; then
    for stub_file in "${COMMON_STUBS[@]}"; do
        if [ -f "${STUBS_SRC}/${stub_file}" ]; then
            cp "${STUBS_SRC}/${stub_file}" "${STUBS_DEST}/${stub_file}"
        fi
    done
    # iOS stub is only needed if the plugin is macOS-only
    if [ "${PLATFORMS_CHOICE}" = "macos" ] && [ -d "${STUBS_SRC}/stub_ios.xcframework" ]; then
        cp -R "${STUBS_SRC}/stub_ios.xcframework" "${STUBS_DEST}/"
    fi
else
    echo -e "  ${CYAN}↓${NC} Fetching precompiled GDExtension stubs from GitHub..."
    RAW_BASE="https://raw.githubusercontent.com/poingstudios/godot-swift-plugin/master/templates/stubs"
    for stub_file in "${COMMON_STUBS[@]}"; do
        curl -fsSL "${RAW_BASE}/${stub_file}" -o "${STUBS_DEST}/${stub_file}" 2>/dev/null || true
    done
    if [ "${PLATFORMS_CHOICE}" = "macos" ]; then
        mkdir -p "${STUBS_DEST}/stub_ios.xcframework/ios-arm64"
        mkdir -p "${STUBS_DEST}/stub_ios.xcframework/ios-arm64_x86_64-simulator"
        curl -fsSL "${RAW_BASE}/stub_ios.xcframework/Info.plist" -o "${STUBS_DEST}/stub_ios.xcframework/Info.plist" 2>/dev/null || true
        curl -fsSL "${RAW_BASE}/stub_ios.xcframework/ios-arm64/libstub_ios_device.a" -o "${STUBS_DEST}/stub_ios.xcframework/ios-arm64/libstub_ios_device.a" 2>/dev/null || true
        curl -fsSL "${RAW_BASE}/stub_ios.xcframework/ios-arm64_x86_64-simulator/libstub_ios_sim.a" -o "${STUBS_DEST}/stub_ios.xcframework/ios-arm64_x86_64-simulator/libstub_ios_sim.a" 2>/dev/null || true
    fi
fi

# 1. Package.swift
cat <<EOF > "${OUTPUT_DIR}/platforms/apple/Package.swift"
// swift-tools-version: 5.9

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
cat <<EOF > "${OUTPUT_DIR}/platforms/apple/Sources/${PLUGIN_NAME}/${PLUGIN_NAME}.swift"
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
cat <<EOF > "${OUTPUT_DIR}/platforms/apple/Tests/${PLUGIN_NAME}Tests/${PLUGIN_NAME}Tests.swift"
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
AUTHOR_NAME="$(git config user.name 2>/dev/null || echo "")"
cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/plugin.cfg"
[plugin]

name="${PLUGIN_NAME}"
description="${PLUGIN_NAME} iOS & macOS plugin for Godot."
author="${AUTHOR_NAME}"
version="1.0.0"
script="plugin.gd"
EOF


# 6. plugin.gd
cat <<EOF > "${OUTPUT_DIR}/platforms/godot_editor/addons/${SNAKE_NAME}/plugin.gd"
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
	if s:
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
PACKAGE_DIR="\${SCRIPT_DIR}/../platforms/apple"

exec swift package --package-path "\${PACKAGE_DIR}" --disable-sandbox --allow-writing-to-package-directory godot-build "\$@"
EOF
chmod +x "${OUTPUT_DIR}/scripts/build_local.sh"

# 12. Minimal scripts/test_local.sh
cat <<EOF > "${OUTPUT_DIR}/scripts/test_local.sh"
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec swift test --package-path "\${SCRIPT_DIR}/../platforms/apple"
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

Godot 4.x plugin for iOS and macOS, powered by [Godot Swift Plugin](https://github.com/poingstudios/godot-swift-plugin).

## Getting Started

### 1. Run in Godot Editor
1. Open **Godot Engine ${GODOT_VERSION}+**.
2. Import and open \`platforms/godot_editor\`.
3. Press **F5** to run the sample scene (\`sample/sample.tscn\`).

### 2. Write Your Swift Code
- Native Swift code is located at:
  \`platforms/apple/Sources/${PLUGIN_NAME}/${PLUGIN_NAME}.swift\`

### 3. Rebuild Binaries
Whenever you modify your Swift code, recompile:
\`\`\`bash
# Build for iOS only
./scripts/build_local.sh ios

# Build for all platforms (iOS + macOS)
./scripts/build_local.sh all
\`\`\`

### 4. Run Unit Tests
\`\`\`bash
./scripts/test_local.sh
\`\`\`

### 5. Export to iOS (Xcode)
1. In Godot, go to **Project > Export...**
2. Add an **iOS** preset and click **Export Project**.
3. Open the exported \`.xcodeproj\` in **Xcode** and run on your iOS Device or Simulator.
EOF

echo -e "  ${GREEN}✓${NC} Project files generated successfully\n"

if [ "${RUN_BUILD}" = true ]; then
    (cd "${OUTPUT_DIR}" && ./scripts/build_local.sh "${PLATFORMS_CHOICE}")
fi

echo -e "\n${BOLD}Next steps:${NC}"
echo -e "  1. ${CYAN}Navigate to your project:${NC}"
echo -e "     cd ${OUTPUT_DIR}\n"
if [ "${RUN_BUILD}" != true ]; then
    echo -e "  2. ${CYAN}Compile plugin binaries:${NC}"
    echo -e "     ./scripts/build_local.sh ${PLATFORMS_CHOICE}\n"
    echo -e "  3. ${CYAN}Open in Godot Engine (${GODOT_VERSION}+):${NC}"
    echo -e "     Open 'platforms/godot_editor' and press ${BOLD}F5${NC} to run the sample scene\n"
    echo -e "  4. ${CYAN}Write your Swift code:${NC}"
    echo -e "     Edit 'platforms/apple/Sources/${PLUGIN_NAME}/${PLUGIN_NAME}.swift'\n"
    echo -e "  5. ${CYAN}Run Swift unit tests:${NC}"
    echo -e "     ./scripts/test_local.sh\n"
else
    echo -e "  2. ${CYAN}Open in Godot Engine (${GODOT_VERSION}+):${NC}"
    echo -e "     Open 'platforms/godot_editor' and press ${BOLD}F5${NC} to run the sample scene\n"
    echo -e "  3. ${CYAN}Write your Swift code:${NC}"
    echo -e "     Edit 'platforms/apple/Sources/${PLUGIN_NAME}/${PLUGIN_NAME}.swift'\n"
    echo -e "  4. ${CYAN}Rebuild binaries anytime:${NC}"
    echo -e "     ./scripts/build_local.sh ${PLATFORMS_CHOICE}\n"
    echo -e "  5. ${CYAN}Run Swift unit tests:${NC}"
    echo -e "     ./scripts/test_local.sh\n"
fi

print_finish_banner
