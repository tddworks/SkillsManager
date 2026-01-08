#!/bin/bash
#
# sign-app.sh - Sign a macOS app bundle with Developer ID
#
# Usage: ./scripts/sign-app.sh <app-bundle> <signing-identity> [entitlements-path]
#
# Example:
#   ./scripts/sign-app.sh SkillsManager.app "Developer ID Application: Your Name (TEAMID)"
#   ./scripts/sign-app.sh SkillsManager.app "Developer ID Application: Your Name" Sources/App/entitlements.plist
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_BUNDLE="$1"
SIGNING_IDENTITY="$2"
ENTITLEMENTS="${3:-Sources/App/entitlements.plist}"

if [ -z "$APP_BUNDLE" ] || [ -z "$SIGNING_IDENTITY" ]; then
    echo "Usage: $0 <app-bundle> <signing-identity> [entitlements-path]"
    echo ""
    echo "Arguments:"
    echo "  app-bundle        Path to the .app bundle (e.g., SkillsManager.app)"
    echo "  signing-identity  Code signing identity (e.g., 'Developer ID Application: Name (TEAMID)')"
    echo "  entitlements      Path to entitlements.plist (default: Sources/App/entitlements.plist)"
    echo ""
    echo "Find your identity with: security find-identity -v -p codesigning"
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}ERROR: App bundle not found: $APP_BUNDLE${NC}"
    exit 1
fi

if [ ! -f "$ENTITLEMENTS" ]; then
    echo -e "${RED}ERROR: Entitlements file not found: $ENTITLEMENTS${NC}"
    exit 1
fi

APP_NAME=$(basename "$APP_BUNDLE" .app)
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"

echo "========================================"
echo "  Signing $APP_NAME"
echo "========================================"
echo ""
echo "App Bundle:  $APP_BUNDLE"
echo "Identity:    $SIGNING_IDENTITY"
echo "Entitlements: $ENTITLEMENTS"
echo ""

# Sign all frameworks (--deep signs all nested components)
if [ -d "$FRAMEWORKS_DIR" ]; then
    for framework in "$FRAMEWORKS_DIR"/*.framework; do
        if [ -d "$framework" ]; then
            echo "--- Signing $(basename "$framework") ---"
            codesign --force --deep --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$framework"
        fi
    done
    echo ""
fi

# Sign main executable with entitlements
echo "--- Signing main executable ---"
codesign --force --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --timestamp \
    --options runtime \
    "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Sign app bundle
echo "--- Signing app bundle ---"
codesign --force --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --timestamp \
    --options runtime \
    "$APP_BUNDLE"

# Verify signature
echo ""
echo "--- Verifying signature ---"
if codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"; then
    echo ""
    echo -e "${GREEN}SUCCESS: App bundle is properly signed${NC}"
else
    echo ""
    echo -e "${RED}ERROR: Signature verification failed${NC}"
    exit 1
fi

echo ""
echo "========================================"
echo "  Done!"
echo "========================================"
