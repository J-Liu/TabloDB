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
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

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

# Copy Sparkle.framework
SPARKLE_BUILD_DIR="$(swift build -c "$BUILD_CONFIG" --show-bin-path)"
SPARKLE_FRAMEWORK="${SPARKLE_BUILD_DIR}/../../release/Sparkle.framework"
if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
    # Try alternate path
    SPARKLE_FRAMEWORK="${ROOT_DIR}/.build/release/Sparkle.framework"
fi
echo "==> DEBUG: SPARKLE_FRAMEWORK path: $SPARKLE_FRAMEWORK"
echo "==> DEBUG: SPARKLE_FRAMEWORK exists: $([ -d "$SPARKLE_FRAMEWORK" ] && echo 'YES' || echo 'NO')"

if [ -d "$SPARKLE_FRAMEWORK" ]; then
    echo "==> Copying Sparkle.framework..."
    cp -R "$SPARKLE_FRAMEWORK" "${APP_BUNDLE}/Contents/Frameworks/"

    # Debug: Show Sparkle framework contents and existing signatures
    echo "==> DEBUG: Sparkle.framework contents:"
    ls -la "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B/" 2>/dev/null || echo "  No Versions/B directory"

    echo "==> DEBUG: Checking existing signatures in Sparkle:"
    echo "  Sparkle.framework:"
    codesign -dvvv "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework" 2>&1 | head -20 || echo "    Not signed"

    echo "  Autoupdate:"
    codesign -dvvv "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>&1 | head -10 || echo "    Not found/not signed"

    echo "  Updater.app:"
    codesign -dvvv "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" 2>&1 | head -10 || echo "    Not found/not signed"

    for XPC in "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/"*.xpc; do
        if [ -d "$XPC" ]; then
            echo "  $(basename $XPC):"
            codesign -dvvv "$XPC" 2>&1 | head -10 || echo "    Not signed"
        fi
    done
fi

# Add rpath for frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# 3. Sign with local certificate (stable identity for TCC)
echo "==> Signing..."
echo "==> DEBUG: Checking available signing identities:"
security find-identity -v -p codesigning

echo "==> DEBUG: Determining signing identity..."
if security find-identity -v -p codesigning | grep -q "Local Development Signing"; then
    SIGN_IDENTITY="Local Development Signing"
    echo "==> DEBUG: Will use certificate: Local Development Signing"
else
    SIGN_IDENTITY="-"
    echo "==> DEBUG: Will use ad-hoc signing"
fi

echo "==> DEBUG: Testing timestamp server connectivity..."
echo "  Testing Apple timestamp server:"
curl -I --connect-timeout 5 https://timestamp.apple.com 2>&1 | head -5 || echo "    FAILED to connect"

echo "==> DEBUG: Starting codesign with verbose output..."
echo "  Command: codesign --force --deep --sign \"$SIGN_IDENTITY\" -v \"$APP_BUNDLE\""
echo "  This may take a while if timestamp server is unreachable..."

codesign --force --deep --sign "$SIGN_IDENTITY" -v "$APP_BUNDLE"
echo "==> Signed ${APP_BUNDLE} using $SIGN_IDENTITY"

echo "==> DEBUG: Verifying final signature:"
codesign -dvvv --deep --strict "$APP_BUNDLE" 2>&1 | head -30

echo ""
echo "==> Done: ${APP_BUNDLE}"
echo "    Run:  open \"${APP_BUNDLE}\""
