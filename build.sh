#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright © 2026 Jia Liu
#
# Builds the release executable and assembles a signed TabloDB.app bundle.
# Usage: ./build.sh

set -euo pipefail

APP_NAME="TabloDB"
BUILD_CONFIG="release"

# Resolve project root (script is in root)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# 1. Build the binary
echo "==> Building ${APP_NAME} (${BUILD_CONFIG})..."
swift build -c "$BUILD_CONFIG"

BIN_DIR="$(swift build -c "$BUILD_CONFIG" --show-bin-path)"
BINARY="${BIN_DIR}/${APP_NAME}"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at ${BINARY}"
    exit 1
fi

# 2. Assemble .app bundle structure (in root directory)
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
echo "==> Assembling ${APP_BUNDLE}..."

rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "$BINARY" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist from Resources/
cp "${ROOT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Copy pre-compiled icon assets (committed to git)
ICON_DIR="${ROOT_DIR}/Resources/Compiled"
if [ -f "${ICON_DIR}/Assets.car" ]; then
    cp "${ICON_DIR}/Assets.car" "${APP_BUNDLE}/Contents/Resources/Assets.car"
fi
if [ -f "${ICON_DIR}/${APP_NAME}.icns" ]; then
    cp "${ICON_DIR}/${APP_NAME}.icns" "${APP_BUNDLE}/Contents/Resources/${APP_NAME}.icns"
fi

# 3. Sign with local certificate (stable identity for TCC)
echo "==> Signing..."
if security find-identity -v -p codesigning | grep -q "Local Development Signing"; then
    codesign --force --deep --sign "Local Development Signing" "$APP_BUNDLE"
    echo "==> Signed ${APP_BUNDLE} using certificate"
else
    # Fallback to ad-hoc signing
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "==> Signed ${APP_BUNDLE} by ad-hoc"
fi

echo ""
echo "==> Done: ${APP_BUNDLE}"
echo "    Run:  open \"${APP_BUNDLE}\""
