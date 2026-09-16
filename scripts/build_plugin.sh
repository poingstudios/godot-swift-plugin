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
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

on_error() {
    local exit_code="$1"
    local line_no="$2"
    echo -e "\n${RED}✖ Error:${NC} build_plugin.sh failed at line ${line_no} (exit code ${exit_code})\n" >&2
    exit "${exit_code}"
}
trap 'on_error $? $LINENO' ERR

run_step() {
    local est_secs=15
    local step_label=""
    local success_label=""

    if [[ "$1" =~ ^[0-9]+$ ]]; then
        est_secs="$1"
        step_label="$2"
        success_label="$3"
        shift 3
    else
        step_label="$1"
        success_label="$2"
        shift 2
    fi

    BUILD_CURRENT_STEP=$(( ${BUILD_CURRENT_STEP:-0} + 1 ))
    local step_idx="${BUILD_CURRENT_STEP}"
    local total_steps="${BUILD_TOTAL_STEPS:-1}"

    local base_pct=$(( (step_idx - 1) * 100 / total_steps ))
    local target_pct=$(( step_idx * 100 / total_steps ))
    local span=$(( target_pct - base_pct ))

    local tty_out=""
    if [ -t 2 ]; then
        tty_out="/dev/stderr"
    elif [ -t 1 ]; then
        tty_out="/dev/stdout"
    elif [ -c /dev/tty ] && { : > /dev/tty; } 2>/dev/null; then
        tty_out="/dev/tty"
    fi

    local log_file
    log_file="$(mktemp /tmp/gsp_step_XXXXXX)"

    local spinner_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local delay=0.08
    local bar_width=12
    local start_time=$(date +%s)

    "$@" > "${log_file}" 2>&1 &
    local pid=$!

    if [ -n "${tty_out}" ]; then
        printf "\033[?25l" > "${tty_out}"
        local tick=0
        while kill -0 "${pid}" 2>/dev/null; do
            local spin="${spinner_chars[tick % ${#spinner_chars[@]}]}"
            local elapsed=$(( $(date +%s) - start_time ))

            local elapsed_ms=$(( tick * 80 ))
            local inc=$(( elapsed_ms * span / (est_secs * 1000) ))
            if [ "${inc}" -ge "${span}" ]; then
                inc=$(( span - 1 ))
            fi
            local pct=$(( base_pct + inc ))

            local filled_cnt=$(( pct * bar_width / 100 ))
            local empty_cnt=$(( bar_width - filled_cnt ))
            local filled=""
            local empty=""
            [ "${filled_cnt}" -gt 0 ] && filled=$(printf "%*s" "${filled_cnt}" | tr " " "█")
            [ "${empty_cnt}" -gt 0 ] && empty=$(printf "%*s" "${empty_cnt}" | tr " " "░")

            printf "\r\033[K  \033[1;36m%s\033[0m \033[2m[\033[0m\033[36m%s\033[0m\033[2m%s]\033[0m \033[1m%3d%%\033[0m  %s \033[2m(%ds)\033[0m" \
                "${spin}" "${filled}" "${empty}" "${pct}" "${step_label}" "${elapsed}" > "${tty_out}"
            tick=$(( tick + 1 ))
            sleep "${delay}"
        done
        printf "\033[?25h" > "${tty_out}"
    else
        printf "  \033[2m•\033[0m %s...\n" "${step_label}" >&2
    fi

    wait "${pid}"
    local exit_code=$?
    local total_elapsed=$(( $(date +%s) - start_time ))

    local warnings=()
    if [ -f "${log_file}" ]; then
        while IFS= read -r wline; do
            [ -n "${wline}" ] && warnings+=("${wline}")
        done < <(grep -E "(warning:|⚠️)" "${log_file}" 2>/dev/null | grep -v "no_warning_for_no_symbols" | head -n 5 || true)
    fi

    if [ "${exit_code}" -eq 0 ]; then
        if [ ${#warnings[@]} -gt 0 ]; then
            if [ -n "${tty_out}" ]; then
                printf "\r\033[K  \033[1;33m⚠\033[0m %s \033[2m(%d warning%s)\033[0m \033[2m(%ds)\033[0m\n" "${success_label}" "${#warnings[@]}" "$([ ${#warnings[@]} -gt 1 ] && echo "s" || echo "")" "${total_elapsed}" > "${tty_out}"
            else
                printf "  \033[1;33m⚠\033[0m %s \033[2m(%d warning%s)\033[0m \033[2m(%ds)\033[0m\n" "${success_label}" "${#warnings[@]}" "$([ ${#warnings[@]} -gt 1 ] && echo "s" || echo "")" "${total_elapsed}" >&2
            fi
            for w in "${warnings[@]}"; do
                printf "    \033[33m%s\033[0m\n" "${w}" >&2
            done
        else
            if [ -n "${tty_out}" ]; then
                printf "\r\033[K  \033[1;32m✓\033[0m %s \033[2m(%ds)\033[0m\n" "${success_label}" "${total_elapsed}" > "${tty_out}"
            else
                printf "  \033[1;32m✓\033[0m %s \033[2m(%ds)\033[0m\n" "${success_label}" "${total_elapsed}" >&2
            fi
        fi
        rm -f "${log_file}"
        return 0
    else
        if [ -n "${tty_out}" ]; then
            printf "\r\033[K  \033[1;31m✖\033[0m %s \033[1;31m(failed after %ds)\033[0m\n\n" "${step_label}" "${total_elapsed}" > "${tty_out}"
        else
            printf "  \033[1;31m✖\033[0m %s \033[1;31m(failed after %ds)\033[0m\n\n" "${step_label}" "${total_elapsed}" >&2
        fi
        if [ -f "${log_file}" ]; then
            cat "${log_file}" >&2
            rm -f "${log_file}"
        fi
        return "${exit_code}"
    fi
}

show_help() {
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
    elif [ -f "platforms/ios/Package.swift" ]; then
        PACKAGE_DIR="$(pwd)/platforms/ios"
    elif [ -f "ios/Package.swift" ]; then
        PACKAGE_DIR="$(pwd)/ios"
    elif [ -f "../Package.swift" ]; then
        PACKAGE_DIR="$(cd .. && pwd)"
    else
        echo -e "${RED}[ERROR] Could not find Package.swift. Please specify --package-dir.${NC}" >&2
        exit 1
    fi
fi
PACKAGE_DIR="$(cd "${PACKAGE_DIR}" && pwd)"

if [ ! -f "${PACKAGE_DIR}/Package.swift" ]; then
    echo -e "${RED}[ERROR] No Package.swift found in: ${PACKAGE_DIR}${NC}" >&2
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
                if [ -d "${FIRST_ADDON}/ios/bin" ]; then
                    OUTPUT_DIR="${FIRST_ADDON}/ios/bin"
                    break
                elif [ -d "${FIRST_ADDON}/bin" ]; then
                    OUTPUT_DIR="${FIRST_ADDON}/bin"
                    break
                else
                    OUTPUT_DIR="${FIRST_ADDON}/bin"
                    break
                fi
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
        echo -e "${RED}[ERROR] Required tool '${tool}' is not installed or not in PATH.${NC}" >&2
        exit 1
    fi
done

if [ "$CLEAN" = true ]; then
    echo -e "${CYAN}==> Cleaning build directory: ${BUILD_DIR}...${NC}"
    rm -rf "${BUILD_DIR}"
fi
mkdir -p "${BUILD_DIR}"

build_macos() {
    local dynamic_product
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
        if [ "${TARGET}" == "macos" ]; then
            echo -e "${RED}[ERROR] Package does not define a dynamic library product for macOS.${NC}" >&2
            exit 1
        else
            echo -e "${YELLOW}==> [macOS] Skipping macOS build (no dynamic library product defined in Package.swift)${NC}"
            return 0
        fi
    fi

    echo -e "\n${CYAN}==> [macOS] Compiling dynamic library via SwiftPM (${dynamic_product})...${NC}"
    local cfg_lower
    cfg_lower="$(echo "${CONFIG}" | tr '[:upper:]' '[:lower:]')"
    local spm_build_dir="${BUILD_DIR}/spm"

    compile_macos_slice() {
        swift build --package-path "${PACKAGE_DIR}" --build-path "${spm_build_dir}" -c "${cfg_lower}" --product "${dynamic_product}"
        local bin_path
        bin_path="$(swift build --package-path "${PACKAGE_DIR}" --build-path "${spm_build_dir}" -c "${cfg_lower}" --show-bin-path)"
        local dylib="${bin_path}/lib${dynamic_product}.dylib"
        if [ -f "${dylib}" ]; then
            cp "${dylib}" "${OUTPUT_DIR}/lib${dynamic_product}.dylib"
            chmod 755 "${OUTPUT_DIR}/lib${dynamic_product}.dylib"
        else
            echo -e "${RED}[ERROR] Built dylib not found at: ${dylib}${NC}" >&2
            return 1
        fi
    }

    run_step 8 "[macOS] Compiling dynamic library (${dynamic_product})" \
             "[macOS] lib${dynamic_product}.dylib deployed" \
             compile_macos_slice
}

build_ios() {
    cd "${PACKAGE_DIR}"

    local scheme="${PLUGIN_NAME}Static"
    if ! xcodebuild -list 2>/dev/null | grep -q "${scheme}"; then
        scheme="${PLUGIN_NAME}"
    fi

    local device_products="${DERIVED_DATA}/device/Build/Products/${CONFIG}-iphoneos"
    local sim_products="${DERIVED_DATA}/sim/Build/Products/${CONFIG}-iphonesimulator"
    local device_lib="${BUILD_DIR}/lib${PLUGIN_NAME}-device.a"
    local sim_lib="${BUILD_DIR}/lib${PLUGIN_NAME}-sim.a"
    local xcframework_build="${BUILD_DIR}/${PLUGIN_NAME}.xcframework"
    local xcframework_dest="${OUTPUT_DIR}/${PLUGIN_NAME}.xcframework"

    # 1. iOS Device Slice
    run_step 18 "[iOS 1/4] Compiling device slice (arm64)" \
             "[iOS 1/4] Device slice compiled (arm64)" \
             xcodebuild build \
                 -scheme "${scheme}" \
                 -configuration "${CONFIG}" \
                 -destination "generic/platform=iOS" \
                 -derivedDataPath "${DERIVED_DATA}/device" \
                 SKIP_INSTALL=NO \
                 -quiet

    # 2. iOS Simulator Slice
    run_step 18 "[iOS 2/4] Compiling simulator slice (universal)" \
             "[iOS 2/4] Simulator slice compiled (universal)" \
             xcodebuild build \
                 -scheme "${scheme}" \
                 -configuration "${CONFIG}" \
                 -destination "generic/platform=iOS Simulator" \
                 -derivedDataPath "${DERIVED_DATA}/sim" \
                 SKIP_INSTALL=NO \
                 -quiet

    # 3. Dynamic Object Harvesting & Static Library Archiving
    assemble_static_libs() {
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
                echo -e "${RED}[ERROR] No object files found in ${device_products}${NC}" >&2
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
                echo -e "${RED}[ERROR] No object files found in ${sim_products}${NC}" >&2
                return 1
            fi
            libtool -static -no_warning_for_no_symbols -o "${sim_lib}" "${sim_objs[@]}"
        fi
    }

    run_step 3 "[iOS 3/4] Assembling static libraries" \
             "[iOS 3/4] Static libraries assembled" \
             assemble_static_libs

    # 4. Create XCFramework
    create_xcframework_step() {
        rm -rf "${xcframework_build}"
        xcodebuild -create-xcframework \
            -library "${device_lib}" \
            -library "${sim_lib}" \
            -output "${xcframework_build}"

        rm -rf "${xcframework_dest}"
        cp -R "${xcframework_build}" "${xcframework_dest}"
    }

    run_step 2 "[iOS 4/4] Creating universal XCFramework" \
             "[iOS 4/4] ${PLUGIN_NAME}.xcframework created" \
             create_xcframework_step
}

BUILD_CURRENT_STEP=0
case "${TARGET}" in
    macos)
        BUILD_TOTAL_STEPS=1
        build_macos
        ;;
    ios)
        BUILD_TOTAL_STEPS=4
        build_ios
        ;;
    all)
        BUILD_TOTAL_STEPS=5
        build_macos
        build_ios
        ;;
    *)
        echo -e "${RED}[ERROR] Unknown target '${TARGET}'. Use 'macos', 'ios', or 'all'.${NC}" >&2
        exit 1
        ;;
esac

if [ "${QUIET_HEADER}" = false ]; then
    echo -e "\n  ${GREEN}✓${NC} Build completed successfully (${OUTPUT_DIR})\n"
fi
