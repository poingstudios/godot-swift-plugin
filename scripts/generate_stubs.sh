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
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STUB_SRC="${SCRIPT_DIR}/stubs/stub.c"

DEST_DIR="${1:-${REPO_ROOT}/templates/stubs}"
mkdir -p "${DEST_DIR}"
DEST_DIR="$(cd "${DEST_DIR}" && pwd)"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}==> Generating GDExtension Stubs${NC}"
echo -e "${CYAN}    Source:      ${STUB_SRC}${NC}"
echo -e "${CYAN}    Destination: ${DEST_DIR}${NC}"
echo -e "${CYAN}================================================================${NC}"

if [ ! -f "${STUB_SRC}" ]; then
    echo -e "${RED}[ERROR] Stub source file not found: ${STUB_SRC}${NC}" >&2
    exit 1
fi

TEMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# 1. macOS Universal dylib (Apple Silicon arm64 + Intel x86_64)
echo -e "${CYAN}>>> [1/4] Compiling macOS Universal stub (arm64 + x86_64)...${NC}"
if command -v clang >/dev/null 2>&1; then
    clang -shared -target arm64-apple-macos11.0 -fPIC "${STUB_SRC}" -o "${TEMP_DIR}/libstub_macos_arm64.dylib"
    clang -shared -target x86_64-apple-macos11.0 -fPIC "${STUB_SRC}" -o "${TEMP_DIR}/libstub_macos_x86_64.dylib"
    lipo -create "${TEMP_DIR}/libstub_macos_arm64.dylib" "${TEMP_DIR}/libstub_macos_x86_64.dylib" -output "${DEST_DIR}/libstub_macos.dylib"
    echo -e "${GREEN}    ✓ macOS Universal stub created:${NC} ${DEST_DIR}/libstub_macos.dylib"
else
    echo -e "${YELLOW}    ⚠ clang not available. Skipping macOS stub compilation.${NC}"
fi

# Find Android NDK LLVM toolchain if available
NDK_CLANG_X86=""
NDK_CLANG_ARM64=""
NDK_LLVM_BIN=""
if [ -d "${HOME}/Library/Android/sdk/ndk" ]; then
    LATEST_NDK="$(find "${HOME}/Library/Android/sdk/ndk" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -n 1)"
    if [ -n "${LATEST_NDK}" ] && [ -d "${LATEST_NDK}/toolchains/llvm/prebuilt" ]; then
        HOST_TAG="$(ls "${LATEST_NDK}/toolchains/llvm/prebuilt" | head -n 1)"
        NDK_LLVM_BIN="${LATEST_NDK}/toolchains/llvm/prebuilt/${HOST_TAG}/bin"
        NDK_CLANG_X86="$(find "${NDK_LLVM_BIN}" -name "x86_64-linux-android*-clang" | head -n 1)"
        NDK_CLANG_ARM64="$(find "${NDK_LLVM_BIN}" -name "aarch64-linux-android*-clang" | head -n 1)"
    fi
fi

# 2. Windows stubs (x86_64 & arm64 DLLs)
echo -e "${CYAN}>>> [2/5] Compiling Windows stubs (x86_64 & arm64)...${NC}"
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    x86_64-w64-mingw32-gcc -shared -s -O2 "${STUB_SRC}" -o "${DEST_DIR}/stub_windows_x86_64.dll"
    if command -v x86_64-w64-mingw32-strip >/dev/null 2>&1; then
        x86_64-w64-mingw32-strip "${DEST_DIR}/stub_windows_x86_64.dll" 2>/dev/null || true
    fi
    cp "${DEST_DIR}/stub_windows_x86_64.dll" "${DEST_DIR}/stub_windows.dll"
    echo -e "${GREEN}    ✓ Windows x86_64 stub created:${NC} ${DEST_DIR}/stub_windows_x86_64.dll"
elif [ -f "${DEST_DIR}/stub_windows_x86_64.dll" ]; then
    echo -e "${YELLOW}    ⚠ MinGW compiler not found. Keeping existing Windows x86_64 stub.${NC}"
fi

if [ -n "${NDK_LLVM_BIN}" ] && [ -x "${NDK_LLVM_BIN}/clang" ]; then
    "${NDK_LLVM_BIN}/clang" -target aarch64-windows-msvc -shared -nostdlib -fuse-ld=lld -Wl,-noentry -O2 "${STUB_SRC}" -o "${DEST_DIR}/stub_windows_arm64.dll" 2>/dev/null || true
    if [ -f "${DEST_DIR}/stub_windows_arm64.dll" ]; then
        echo -e "${GREEN}    ✓ Windows arm64 stub created:${NC} ${DEST_DIR}/stub_windows_arm64.dll"
    fi
fi

# 3. Linux stubs (x86_64 & arm64 Shared Objects)
echo -e "${CYAN}>>> [3/5] Compiling Linux stubs (x86_64 & arm64)...${NC}"
if [ -n "${NDK_CLANG_X86}" ] && [ -x "${NDK_CLANG_X86}" ]; then
    "${NDK_CLANG_X86}" -shared -fPIC -O2 "${STUB_SRC}" -o "${DEST_DIR}/libstub_linux_x86_64.so"
    cp "${DEST_DIR}/libstub_linux_x86_64.so" "${DEST_DIR}/libstub_linux.so"
    echo -e "${GREEN}    ✓ Linux x86_64 stub created:${NC} ${DEST_DIR}/libstub_linux_x86_64.so"
elif command -v x86_64-linux-gnu-gcc >/dev/null 2>&1; then
    x86_64-linux-gnu-gcc -shared -fPIC -s -O2 "${STUB_SRC}" -o "${DEST_DIR}/libstub_linux_x86_64.so"
    cp "${DEST_DIR}/libstub_linux_x86_64.so" "${DEST_DIR}/libstub_linux.so"
    echo -e "${GREEN}    ✓ Linux x86_64 stub created:${NC} ${DEST_DIR}/libstub_linux_x86_64.so"
fi

if [ -n "${NDK_CLANG_ARM64}" ] && [ -x "${NDK_CLANG_ARM64}" ]; then
    "${NDK_CLANG_ARM64}" -shared -fPIC -O2 "${STUB_SRC}" -o "${DEST_DIR}/libstub_linux_arm64.so"
    echo -e "${GREEN}    ✓ Linux arm64 stub created:${NC} ${DEST_DIR}/libstub_linux_arm64.so"
fi

# 4. Android stubs (ARM64 & x86_64 Shared Objects)
echo -e "${CYAN}>>> [4/5] Compiling Android stubs (arm64 & x86_64)...${NC}"
if [ -n "${NDK_CLANG_ARM64}" ] && [ -x "${NDK_CLANG_ARM64}" ]; then
    "${NDK_CLANG_ARM64}" -shared -fPIC -O2 "${STUB_SRC}" -o "${DEST_DIR}/libstub_android_arm64.so"
    cp "${DEST_DIR}/libstub_android_arm64.so" "${DEST_DIR}/libstub_android.so"
    echo -e "${GREEN}    ✓ Android ARM64 stub created:${NC} ${DEST_DIR}/libstub_android_arm64.so"
fi

if [ -n "${NDK_CLANG_X86}" ] && [ -x "${NDK_CLANG_X86}" ]; then
    "${NDK_CLANG_X86}" -shared -fPIC -O2 "${STUB_SRC}" -o "${DEST_DIR}/libstub_android_x86_64.so"
    echo -e "${GREEN}    ✓ Android x86_64 stub created:${NC} ${DEST_DIR}/libstub_android_x86_64.so"
fi

# 5. iOS Universal static XCFramework stub (Device arm64 + Simulator arm64/x86_64)
echo -e "${CYAN}>>> [5/5] Compiling iOS Universal static XCFramework stub (.xcframework)...${NC}"
if command -v xcrun >/dev/null 2>&1 && xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    IPHONEOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
    IPHONESIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

    clang -target arm64-apple-ios14.0 -isysroot "${IPHONEOS_SDK}" -fPIC -O2 -c "${STUB_SRC}" -o "${TEMP_DIR}/stub_ios_device.o"
    ar rcs "${TEMP_DIR}/libstub_ios_device.a" "${TEMP_DIR}/stub_ios_device.o"

    clang -target arm64-apple-ios14.0-simulator -isysroot "${IPHONESIM_SDK}" -fPIC -O2 -c "${STUB_SRC}" -o "${TEMP_DIR}/stub_ios_sim_arm64.o"
    clang -target x86_64-apple-ios14.0-simulator -isysroot "${IPHONESIM_SDK}" -fPIC -O2 -c "${STUB_SRC}" -o "${TEMP_DIR}/stub_ios_sim_x86.o"
    ar rcs "${TEMP_DIR}/libstub_ios_sim_arm64.a" "${TEMP_DIR}/stub_ios_sim_arm64.o"
    ar rcs "${TEMP_DIR}/libstub_ios_sim_x86.a" "${TEMP_DIR}/stub_ios_sim_x86.o"
    lipo -create "${TEMP_DIR}/libstub_ios_sim_arm64.a" "${TEMP_DIR}/libstub_ios_sim_x86.a" -output "${TEMP_DIR}/libstub_ios_sim.a"

    rm -rf "${DEST_DIR}/stub_ios.xcframework"
    xcodebuild -create-xcframework \
        -library "${TEMP_DIR}/libstub_ios_device.a" \
        -library "${TEMP_DIR}/libstub_ios_sim.a" \
        -output "${DEST_DIR}/stub_ios.xcframework" >/dev/null
    echo -e "${GREEN}    ✓ iOS XCFramework stub created:${NC} ${DEST_DIR}/stub_ios.xcframework"
elif [ -d "${DEST_DIR}/stub_ios.xcframework" ]; then
    echo -e "${YELLOW}    ⚠ Xcode iOS SDK not found. Keeping existing iOS stub.${NC}"
else
    echo -e "${YELLOW}    ⚠ Xcode iOS SDK not found. Skipping iOS XCFramework stub.${NC}"
fi

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}==> GDExtension stubs successfully processed in:${NC}"
echo -e "${GREEN}    ${DEST_DIR}${NC}"
echo -e "${GREEN}================================================================${NC}"
ls -lh "${DEST_DIR}"
