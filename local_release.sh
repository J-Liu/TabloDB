#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright © 2026 Jia Liu
#
# Local release script for when CI can't reach timestamp server
# Usage: ./local_release.sh <version>
# Example: ./local_release.sh 0.1.0

set -euo pipefail

if [ -z "$1" ]; then
    echo "Usage: ./local_release.sh <version>"
    echo "Example: ./local_release.sh 0.1.0"
    exit 1
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# 1. Build
echo "==> Building..."
swift build -c release

# 2. Run build.sh (will sign with local cert)
./build.sh

# 3. Create zip
echo "==> Creating zip..."
ZIP="TabloDB-${VERSION}.zip"
rm -f "$ZIP"
zip -r "$ZIP" TabloDB.app

# 4. Sparkle sign
echo "==> Signing with Sparkle..."

# Try to get key from keychain first, then environment variable
SPARKLE_KEY=""
if security find-generic-password -s "Sparkle" -a "com.jialiu.tablodb" -w 2>/dev/null; then
    SPARKLE_KEY=$(security find-generic-password -s "Sparkle" -a "com.jialiu.tablodb" -w 2>/dev/null)
elif [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    SPARKLE_KEY="$SPARKLE_PRIVATE_KEY"
else
    echo "Error: Sparkle private key not found"
    echo "Either store in keychain: security add-generic-password -s 'Sparkle' -a 'com.jialiu.tablodb' -w 'your-key'"
    echo "Or set environment variable: export SPARKLE_PRIVATE_KEY='your-key'"
    exit 1
fi

echo "$SPARKLE_KEY" > /tmp/sparkle_key.txt
RAW=$(./.build/artifacts/sparkle/Sparkle/bin/sign_update "$ZIP" --ed-key-file /tmp/sparkle_key.txt)
rm /tmp/sparkle_key.txt

SIGNATURE=$(echo "$RAW" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
LENGTH=$(stat -f%z "$ZIP")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" TabloDB.app/Contents/Info.plist)
DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

echo "==> Signature: $SIGNATURE"
echo "==> Length: $LENGTH"
echo "==> Build: $BUILD_NUMBER"

# 5. Update appcast.xml
echo "==> Updating appcast.xml..."
NEW_ITEM=$(cat <<EOF
<item>
    <title>Version ${VERSION}</title>
    <pubDate>${DATE}</pubDate>
    <sparkle:version>${BUILD_NUMBER}</sparkle:version>
    <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <enclosure
        url="https://github.com/J-Liu/TabloDB/releases/download/v${VERSION}/TabloDB-${VERSION}.zip"
        sparkle:edSignature="${SIGNATURE}"
        length="${LENGTH}"
        type="application/octet-stream"/>
</item>
EOF
)

python3 - <<PYEOF
import re
path = "docs/appcast.xml"
with open(path) as f:
    content = f.read()

new_item = """${NEW_ITEM}"""

content = re.sub(
    r'(<language>en</language>)',
    r'\1\n\n    ' + new_item,
    content,
    count=1
)

with open(path, "w") as f:
    f.write(content)
PYEOF

echo ""
echo "==> Done!"
echo "1. Upload TabloDB-${VERSION}.zip to GitHub Release"
echo "2. Commit and push docs/appcast.xml"
echo "   git add docs/appcast.xml"
echo "   git commit -m 'Update appcast for v${VERSION}'"
echo "   git push"
