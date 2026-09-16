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
    echo -e "\n${RED}✖ Error:${NC} build_plugin.sh failed at line ${line_no} (exit code ${exit_code})\n" >&2
    exit "${exit_code}"
}
trap 'on_error $? $LINENO' ERR


show_help() {
    print_welcome_banner
    echo "Usage: ./scripts/build_plugin.sh [options]"
    echo ""
    echo "Universal builder for Godot Swift plugins (macOS & iOS)."
    echo ""
    echo "Options:"
    echo "  -p, --package-dir <dir>    Path to Swift Package directory (default: auto-detected)"
    echo "  -n, --name <name>          Plugin library name (default: auto-detected from Package.swift)"
    echo "  -o, --output-dir <dir>     Output directory for binaries (default: auto-detected addon bin)"
    echo "  -t, --target <target>      Target platform: 'ios', 'macos', or 'all' (default: 'all')"
    echo "  -c, --configuration <cfg>  Build configuration: 'Release' or 'Debug' (default: 'Release')"
    echo "      --clean                Clean build directories before compiling"
    echo "  -h, --help                 Show this help message"
}

PACKAGE_DIR=""
PLUGIN_NAME=""
OUTPUT_DIR=""
TARGET="all"
CONFIG="Release"
CLEAN=false
QUIET_HEADER=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--package-dir)
            PACKAGE_DIR="$2"
            shift 2
            ;;
        -n|--name)
            PLUGIN_NAME="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -c|--configuration)
            CONFIG="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --quiet-header)
            QUIET_HEADER=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ "$1" =~ ^(ios|macos|all)$ ]]; then
                TARGET="$1"
                shift
            else
                echo -e "${RED}[ERROR] Unknown argument: $1${NC}" >&2
                show_help
                exit 1
            fi
            ;;
    esac
done

# 1. Resolve PACKAGE_DIR
if [ -z "${PACKAGE_DIR}" ]; then
    if [ -f "Package.swift" ]; then
        PACKAGE_DIR="$(pwd)"
    elif [ -f "platforms/apple/Package.swift" ]; then
        PACKAGE_DIR="$(pwd)/platforms/apple"
    elif [ -f "platforms/ios/Package.swift" ]; then
        PACKAGE_DIR="$(pwd)/platforms/ios"
    elif [ -f "example/apple/Package.swift" ]; then
        PACKAGE_DIR="$(pwd)/example/apple"
    elif [ -f "example/ios/Package.swift" ]; then
        PACKAGE_DIR="$(pwd)/example/ios"
    elif [ -f "apple/Package.swift" ]; then
        PACKAGE_DIR="$(pwd)/apple"
    elif [ -f "ios/Package.swift" ]; then
        PACKAGE_DIR="$(pwd)/ios"
    elif [ -f "../Package.swift" ]; then
        PACKAGE_DIR="$(cd .. && pwd)"
    else
        echo -e "  ${RED}✖ Error:${NC} Could not find Package.swift. Please specify --package-dir.\n" >&2
        exit 1
    fi
fi
PACKAGE_DIR="$(cd "${PACKAGE_DIR}" && pwd)"

if [ ! -f "${PACKAGE_DIR}/Package.swift" ]; then
    echo -e "  ${RED}✖ Error:${NC} No Package.swift found in: ${PACKAGE_DIR}\n" >&2
    exit 1
fi

# 2. Resolve PLUGIN_NAME
if [ -z "${PLUGIN_NAME}" ]; then
    PLUGIN_NAME="$(python3 -c "
import re
try:
    with open('${PACKAGE_DIR}/Package.swift') as f:
        m = re.search(r'name:\s*\"([^\"]+)\"', f.read())
        print(m.group(1) if m else '')
except Exception:
    pass
" 2>/dev/null || true)"
    if [ -z "${PLUGIN_NAME}" ]; then
        PLUGIN_NAME="$(basename "${PACKAGE_DIR}")"
    fi
fi

# 3. Resolve OUTPUT_DIR
if [ -z "${OUTPUT_DIR}" ]; then
    CANDIDATES=(
        "${PACKAGE_DIR}/../godot_editor/addons"
        "${PACKAGE_DIR}/../../godot_editor/addons"
        "${PACKAGE_DIR}/platforms/godot_editor/addons"
        "${PACKAGE_DIR}/addons"
        "${PACKAGE_DIR}/../addons"
    )
    for base in "${CANDIDATES[@]}"; do
        if [ -d "${base}" ]; then
            FIRST_ADDON="$(find "${base}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
            if [ -n "${FIRST_ADDON}" ]; then
                OUTPUT_DIR="${FIRST_ADDON}/bin"
                break
            fi
        fi
    done
    if [ -z "${OUTPUT_DIR}" ]; then
        OUTPUT_DIR="${PACKAGE_DIR}/build/artifacts"
    fi
fi
mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

BUILD_DIR="${PACKAGE_DIR}/build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"

if [ "${QUIET_HEADER}" = false ]; then
    print_welcome_banner
    echo -e "${BOLD}Building Godot Swift Plugin...${NC}"
    echo -e "  ${DIM}•${NC} Plugin Name:   ${GREEN}${PLUGIN_NAME}${NC}"
    echo -e "  ${DIM}•${NC} Package Dir:   ${PACKAGE_DIR}"
    echo -e "  ${DIM}•${NC} Output Dir:    ${OUTPUT_DIR}"
    echo -e "  ${DIM}•${NC} Target:        ${TARGET}"
    echo -e "  ${DIM}•${NC} Configuration: ${CONFIG}"
    echo ""
fi

# Check prerequisites
for tool in swift xcodebuild libtool xcrun; do
    if ! command -v "${tool}" &> /dev/null; then
        echo -e "  ${RED}✖ Error:${NC} Required tool '${tool}' is not installed or not in PATH.\n" >&2
        exit 1
    fi
done

if [ "$CLEAN" = true ]; then
    echo -e "  ${DIM}•${NC} Cleaning build directory: ${BUILD_DIR}..."
    rm -rf "${BUILD_DIR}"
fi
mkdir -p "${BUILD_DIR}"

compile_macos_slice() {
    local cfg_lower
    cfg_lower="$(echo "${CONFIG}" | tr '[:upper:]' '[:lower:]')"
    local spm_build_dir="${BUILD_DIR}/spm"
    swift build --package-path "${PACKAGE_DIR}" --build-path "${spm_build_dir}" -c "${cfg_lower}" --product "${dynamic_product}"
    local bin_path
    bin_path="$(swift build --package-path "${PACKAGE_DIR}" --build-path "${spm_build_dir}" -c "${cfg_lower}" --show-bin-path)"
    local dylib="${bin_path}/lib${dynamic_product}.dylib"
    if [ -f "${dylib}" ]; then
        cp "${dylib}" "${OUTPUT_DIR}/lib${dynamic_product}.dylib"
        chmod 755 "${OUTPUT_DIR}/lib${dynamic_product}.dylib"
    else
        echo -e "  ${RED}✖ Error:${NC} Built dylib not found at: ${dylib}\n" >&2
        return 1
    fi
}

compile_ios_device() {
    (cd "${PACKAGE_DIR}" && xcodebuild build \
        -scheme "${scheme}" \
        -configuration "${CONFIG}" \
        -destination "generic/platform=iOS" \
        -derivedDataPath "${DERIVED_DATA}/device" \
        SKIP_INSTALL=NO \
        -quiet)
}

compile_ios_simulator() {
    (cd "${PACKAGE_DIR}" && xcodebuild build \
        -scheme "${scheme}" \
        -configuration "${CONFIG}" \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "${DERIVED_DATA}/sim" \
        SKIP_INSTALL=NO \
        -quiet)
}

assemble_ios_static_libs() {
    if [ ! -d "${device_products}" ]; then
        device_products="${DERIVED_DATA}/device/Build/Products/Debug-iphoneos"
    fi
    if [ ! -d "${sim_products}" ]; then
        sim_products="${DERIVED_DATA}/sim/Build/Products/Debug-iphonesimulator"
    fi

    if [ -f "${device_products}/lib${PLUGIN_NAME}.a" ]; then
        cp "${device_products}/lib${PLUGIN_NAME}.a" "${device_lib}"
    else
        local dev_objs=()
        while IFS= read -r obj; do
            dev_objs+=("${obj}")
        done < <(find "${device_products}" -maxdepth 1 \( -name "*.o" -o -name "*.a" \) ! -name "*Tests*" ! -name "*PackageDescription*" | sort)

        if [ ${#dev_objs[@]} -eq 0 ]; then
            echo -e "  ${RED}✖ Error:${NC} No object files found in ${device_products}\n" >&2
            return 1
        fi
        libtool -static -no_warning_for_no_symbols -o "${device_lib}" "${dev_objs[@]}"
    fi

    if [ -f "${sim_products}/lib${PLUGIN_NAME}.a" ]; then
        cp "${sim_products}/lib${PLUGIN_NAME}.a" "${sim_lib}"
    else
        local sim_objs=()
        while IFS= read -r obj; do
            sim_objs+=("${obj}")
        done < <(find "${sim_products}" -maxdepth 1 \( -name "*.o" -o -name "*.a" \) ! -name "*Tests*" ! -name "*PackageDescription*" | sort)

        if [ ${#sim_objs[@]} -eq 0 ]; then
            echo -e "  ${RED}✖ Error:${NC} No object files found in ${sim_products}\n" >&2
            return 1
        fi
        libtool -static -no_warning_for_no_symbols -o "${sim_lib}" "${sim_objs[@]}"
    fi
}

create_ios_xcframework() {
    rm -rf "${xcframework_build}"
    xcodebuild -create-xcframework \
        -library "${device_lib}" \
        -library "${sim_lib}" \
        -output "${xcframework_build}"

    rm -rf "${xcframework_dest}"
    cp -R "${xcframework_build}" "${xcframework_dest}"
}

pipeline_reset

# Register macOS step if targeting macOS or all
if [ "${TARGET}" = "macos" ] || [ "${TARGET}" = "all" ]; then
    dynamic_product="$(python3 -c "
import re
try:
    with open('${PACKAGE_DIR}/Package.swift') as f:
        content = f.read()
        m = re.search(r'\.library\(\s*name:\s*\"([^\"]+)\"[^)]*type:\s*\.dynamic', content)
        if not m:
            m = re.search(r'type:\s*\.dynamic[^)]*name:\s*\"([^\"]+)\"', content)
        print(m.group(1) if m else '')
except Exception:
    print('')
" 2>/dev/null || true)"

    if [ -z "${dynamic_product}" ]; then
        if [ "${TARGET}" = "macos" ]; then
            echo -e "  ${RED}✖ Error:${NC} Package does not define a dynamic library product for macOS.\n" >&2
            exit 1
        else
            echo -e "  ${YELLOW}⚠ Skipping macOS build (no dynamic library product defined in Package.swift)${NC}"
        fi
    else
        pipeline_add_step "macOS" 8 \
            "Compiling dynamic library (${dynamic_product})" \
            "lib${dynamic_product}.dylib deployed" \
            compile_macos_slice
    fi
fi

# Register iOS steps if targeting iOS or all
if [ "${TARGET}" = "ios" ] || [ "${TARGET}" = "all" ]; then
    scheme="${PLUGIN_NAME}Static"
    if ! (cd "${PACKAGE_DIR}" && xcodebuild -list 2>/dev/null | grep -q "${scheme}"); then
        scheme="${PLUGIN_NAME}"
    fi

    device_products="${DERIVED_DATA}/device/Build/Products/${CONFIG}-iphoneos"
    sim_products="${DERIVED_DATA}/sim/Build/Products/${CONFIG}-iphonesimulator"
    device_lib="${BUILD_DIR}/lib${PLUGIN_NAME}-device.a"
    sim_lib="${BUILD_DIR}/lib${PLUGIN_NAME}-sim.a"
    xcframework_build="${BUILD_DIR}/${PLUGIN_NAME}.xcframework"
    xcframework_dest="${OUTPUT_DIR}/${PLUGIN_NAME}.xcframework"

    pipeline_add_step "iOS" 18 \
        "Compiling device slice (arm64)" \
        "Device slice compiled (arm64)" \
        compile_ios_device

    pipeline_add_step "iOS" 18 \
        "Compiling simulator slice (universal)" \
        "Simulator slice compiled (universal)" \
        compile_ios_simulator

    pipeline_add_step "iOS" 3 \
        "Assembling static libraries" \
        "Static libraries assembled" \
        assemble_ios_static_libs

    pipeline_add_step "iOS" 2 \
        "Creating universal XCFramework" \
        "${PLUGIN_NAME}.xcframework created" \
        create_ios_xcframework
fi

if [ "$(pipeline_count)" -eq 0 ]; then
    echo -e "  ${RED}✖ Error:${NC} No build steps registered for target '${TARGET}'.\n" >&2
    exit 1
fi

pipeline_run


if [ "${QUIET_HEADER}" = false ]; then
    echo -e "\n  ${GREEN}✓${NC} Build completed successfully (${TARGET})\n"

    echo -e "${BOLD}Next steps:${NC}"
    rel_editor="platforms/godot_editor"
    if [ ! -d "${rel_editor}" ] && [ -d "example/godot_editor" ]; then
        rel_editor="example/godot_editor"
    fi
    echo -e "  1. ${CYAN}Open in Godot Engine (4.6+):${NC}"
    echo -e "     Open '${rel_editor}' and press ${BOLD}F5${NC} to run your scene\n"
    echo -e "  2. ${CYAN}Run Swift unit tests:${NC}"
    echo -e "     swift test --package-path ${PACKAGE_DIR}\n"

    print_finish_banner
fi
