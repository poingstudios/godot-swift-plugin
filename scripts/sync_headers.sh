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

# ANSI color codes for clear visual alerts
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

on_error() {
    local exit_code="$1"
    local line_no="$2"
    echo -e "\n${RED}================================================================${NC}" >&2
    echo -e "${RED}[ERROR] sync_headers.sh failed at line ${line_no} (exit code ${exit_code})${NC}" >&2
    echo -e "${RED}================================================================${NC}\n" >&2
    exit "${exit_code}"
}
trap 'on_error $? $LINENO' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SUBMODULE_DIR="${ROOT_DIR}/thirdparty/godot-cpp"
JSON_INTERFACE="${SUBMODULE_DIR}/gdextension/gdextension_interface.json"
MAKE_HEADER_SCRIPT="${SUBMODULE_DIR}/make_interface_header.py"
OUTPUT_DIR="${ROOT_DIR}/Sources/CGDExtensionInterface/include"
OUTPUT_HEADER="${OUTPUT_DIR}/gdextension_interface.h"

echo -e "==> Checking godot-cpp submodule..."

if [ ! -d "${SUBMODULE_DIR}" ] || [ ! -f "${JSON_INTERFACE}" ]; then
    echo -e "${YELLOW}[!] Submodule 'thirdparty/godot-cpp' is missing or uninitialized.${NC}"
    echo -e "    Attempting to initialize git submodule..."
    git -C "${ROOT_DIR}" submodule update --init --recursive "thirdparty/godot-cpp"
fi

if [ ! -f "${JSON_INTERFACE}" ]; then
    echo -e "${RED}[ERROR] File not found: ${JSON_INTERFACE}${NC}" >&2
    echo -e "${RED}Please verify that the godot-cpp submodule is properly initialized.${NC}" >&2
    exit 1
fi

if [ ! -f "${MAKE_HEADER_SCRIPT}" ]; then
    echo -e "${RED}[ERROR] File not found: ${MAKE_HEADER_SCRIPT}${NC}" >&2
    exit 1
fi

echo -e "==> Generating GDExtension interface header..."
mkdir -p "${OUTPUT_DIR}"

python3 -c "import sys; sys.path.append('${SUBMODULE_DIR}'); from make_interface_header import generate_gdextension_interface_header; generate_gdextension_interface_header('${OUTPUT_HEADER}', '${JSON_INTERFACE}')"

if [ ! -f "${OUTPUT_HEADER}" ] || [ ! -s "${OUTPUT_HEADER}" ]; then
    echo -e "${RED}[ERROR] Generated header '${OUTPUT_HEADER}' is missing or empty!${NC}" >&2
    exit 1
fi

HEADER_LINES="$(wc -l < "${OUTPUT_HEADER}" | tr -d ' ')"
echo -e "${GREEN}==> Successfully generated ${OUTPUT_HEADER} (${HEADER_LINES} lines)${NC}"
