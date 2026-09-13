#!/usr/bin/env bash
# MIT License
# Copyright (c) 2026-present Poing Studios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Running Godot Swift Plugin test suite..."
swift test --package-path "${PACKAGE_DIR}"
echo "==> All tests passed successfully!"
