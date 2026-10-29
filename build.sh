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
SPARKLE_FRAMEWORK="${ROOT_DIR}/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    echo "==> Copying Sparkle.framework..."
    cp -R "$SPARKLE_FRAMEWORK" "${APP_BUNDLE}/Contents/Frameworks/"
fi

# Add rpath for frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# 3. Sign with local certificate (stable identity for TCC)
echo "==> Signing..."

# Test timestamp server connectivity
echo "==> Testing timestamp server..."
curl -I --connect-timeout 10 https://timestamp.apple.com || echo "Warning: timestamp server unreachable"

# Determine signing identity
SIGN_IDENTITY=""
if security find-identity -v -p codesigning | grep -q "Local Development Signing"; then
    SIGN_IDENTITY="Local Development Signing"
else
    SIGN_IDENTITY="-"
fi

# Sign Sparkle.framework components from inside out
SPARKLE_FW="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    echo "==> Signing Sparkle.framework components..."

    # Sign XPC services from inside out
    for XPC in "$SPARKLE_FW/Versions/B/XPCServices/Installer.xpc" \
               "$SPARKLE_FW/Versions/B/XPCServices/Downloader.xpc"; do
        if [ -d "$XPC" ]; then
            echo "  Signing: $XPC"
            codesign --force --sign "$SIGN_IDENTITY" -v "$XPC"
        fi
    done

    # Sign Updater.app
    UPDATER_APP="$SPARKLE_FW/Versions/B/Updater.app"
    if [ -d "$UPDATER_APP" ]; then
        echo "  Signing: $UPDATER_APP"
        codesign --force --sign "$SIGN_IDENTITY" -v "$UPDATER_APP"
    fi

    # Sign Autoupdate binary
    AUTOUPDATE="$SPARKLE_FW/Versions/B/Autoupdate"
    if [ -f "$AUTOUPDATE" ]; then
        echo "  Signing: $AUTOUPDATE"
        codesign --force --sign "$SIGN_IDENTITY" -v "$AUTOUPDATE"
    fi

    # Sign Sparkle library
    SPARKLE_LIB="$SPARKLE_FW/Versions/B/Sparkle"
    if [ -f "$SPARKLE_LIB" ]; then
        echo "  Signing: $SPARKLE_LIB"
        codesign --force --sign "$SIGN_IDENTITY" -v "$SPARKLE_LIB"
    fi

    # Sign the framework itself
    echo "  Signing: Sparkle.framework"
    codesign --force --sign "$SIGN_IDENTITY" -v "$SPARKLE_FW"
fi

# Sign the main app
echo "==> Signing main app..."
codesign --force --sign "$SIGN_IDENTITY" -v "$APP_BUNDLE"

echo "==> Signed ${APP_BUNDLE}"

# Verify signature
echo "==> Verifying signature..."
codesign -vvv --deep --strict "$APP_BUNDLE"

echo ""
echo "==> Done: ${APP_BUNDLE}"
echo "    Run:  open \"${APP_BUNDLE}\""
