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
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/example/godot_editor"

GODOT_BIN="${GODOT_BIN:-}"
if [ -z "${GODOT_BIN}" ]; then
    if command -v godot &>/dev/null; then
        GODOT_BIN="godot"
    elif [ -f "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
        GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
    elif [ -f "/Applications/Godot_mono.app/Contents/MacOS/Godot" ]; then
        GODOT_BIN="/Applications/Godot_mono.app/Contents/MacOS/Godot"
    elif [ -f "${HOME}/Applications/Godot.app/Contents/MacOS/Godot" ]; then
        GODOT_BIN="${HOME}/Applications/Godot.app/Contents/MacOS/Godot"
    else
        echo "Error: Godot executable not found. Please set GODOT_BIN environment variable or install Godot to /Applications." >&2
        exit 1
    fi
fi

echo "==> Launching Godot with sample project (${PROJECT_DIR})..."
exec "${GODOT_BIN}" --path "${PROJECT_DIR}" "$@"
