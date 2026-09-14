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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PACKAGE_DIR}/build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
GODOT_BIN_DIR="$(cd "${PACKAGE_DIR}/../godot_editor/addons/example_plugin/bin" && pwd)"

TARGET="${1:-all}"

echo -e "${CYAN}==> Target output directory: ${GODOT_BIN_DIR}${NC}"
mkdir -p "${GODOT_BIN_DIR}"
mkdir -p "${BUILD_DIR}"

cd "${PACKAGE_DIR}"

build_macos() {
    echo -e "${CYAN}==> Building macOS dylib via SwiftPM...${NC}"
    swift build -c release --product GodotExamplePlugin

    BUILT_DYLIB="$(swift build -c release --show-bin-path)/libGodotExamplePlugin.dylib"
    if [ -f "${BUILT_DYLIB}" ]; then
        echo -e "${CYAN}==> Copying macOS dynamic library...${NC}"
        cp "${BUILT_DYLIB}" "${GODOT_BIN_DIR}/libGodotExamplePlugin.dylib"
        chmod 755 "${GODOT_BIN_DIR}/libGodotExamplePlugin.dylib"
        echo -e "${GREEN}==> libGodotExamplePlugin.dylib successfully deployed to bin/${NC}"
    else
        echo -e "${RED}[ERROR] Expected dylib not found at ${BUILT_DYLIB}${NC}" >&2
        exit 1
    fi
}

build_ios() {
    echo -e "${CYAN}==> Building iOS static XCFramework...${NC}"

    echo -e "${CYAN}>>> [1/4] Building iOS device slice (arm64)...${NC}"
    xcodebuild build \
        -scheme GodotExamplePluginStatic \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -derivedDataPath "${DERIVED_DATA}/device" \
        SKIP_INSTALL=NO \
        -quiet

    echo -e "${CYAN}>>> [2/4] Building iOS simulator slice (universal arm64 + x86_64)...${NC}"
    xcodebuild build \
        -scheme GodotExamplePluginStatic \
        -configuration Release \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "${DERIVED_DATA}/sim" \
        SKIP_INSTALL=NO \
        -quiet

    DEVICE_PRODUCTS_DIR="${DERIVED_DATA}/device/Build/Products/Release-iphoneos"
    SIM_PRODUCTS_DIR="${DERIVED_DATA}/sim/Build/Products/Release-iphonesimulator"

    echo -e "${CYAN}>>> [3/4] Packaging static libraries (.a)...${NC}"
    mkdir -p "${BUILD_DIR}/device"
    mkdir -p "${BUILD_DIR}/sim"

    DEVICE_LIB="${BUILD_DIR}/device/libGodotExamplePlugin.a"
    SIM_LIB="${BUILD_DIR}/sim/libGodotExamplePlugin.a"

    libtool -static -o "${DEVICE_LIB}" \
        "${DEVICE_PRODUCTS_DIR}/GodotExamplePlugin.o" \
        "${DEVICE_PRODUCTS_DIR}/GodotSwiftPlugin.o" \
        "${DEVICE_PRODUCTS_DIR}/CGDExtensionInterface.o"

    libtool -static -o "${SIM_LIB}" \
        "${SIM_PRODUCTS_DIR}/GodotExamplePlugin.o" \
        "${SIM_PRODUCTS_DIR}/GodotSwiftPlugin.o" \
        "${SIM_PRODUCTS_DIR}/CGDExtensionInterface.o"

    echo -e "${CYAN}>>> [4/4] Creating XCFramework...${NC}"
    rm -rf "${BUILD_DIR}/GodotExamplePlugin.xcframework"
    xcodebuild -create-xcframework \
        -library "${DEVICE_LIB}" \
        -library "${SIM_LIB}" \
        -output "${BUILD_DIR}/GodotExamplePlugin.xcframework"

    rm -rf "${GODOT_BIN_DIR}/GodotExamplePlugin.xcframework"
    cp -R "${BUILD_DIR}/GodotExamplePlugin.xcframework" "${GODOT_BIN_DIR}/GodotExamplePlugin.xcframework"
    echo -e "${GREEN}==> GodotExamplePlugin.xcframework successfully deployed to bin/${NC}"
}

case "${TARGET}" in
    macos)
        build_macos
        ;;
    ios)
        build_ios
        ;;
    all)
        build_macos
        build_ios
        ;;
    *)
        echo -e "${RED}[ERROR] Unknown target '${TARGET}'. Use 'macos', 'ios', or 'all'.${NC}" >&2
        exit 1
        ;;
esac

echo -e "\n${GREEN}==> Build completed successfully!${NC}\n"
