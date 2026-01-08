#!/bin/bash
#
# notarize-app.sh - Notarize a macOS app with Apple
#
# Usage: ./scripts/notarize-app.sh <app-bundle> <api-key-path> <key-id> <issuer-id>
#
# Example:
#   ./scripts/notarize-app.sh SkillsManager.app ~/AuthKey_ABC123.p8 ABC123 12345678-1234-1234-1234-123456789012
#
# Environment variables (alternative to arguments):
#   APP_STORE_CONNECT_API_KEY_PATH - Path to .p8 file
#   APP_STORE_CONNECT_KEY_ID       - Key ID
#   APP_STORE_CONNECT_ISSUER_ID    - Issuer ID
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_BUNDLE="$1"
API_KEY_PATH="${2:-$APP_STORE_CONNECT_API_KEY_PATH}"
KEY_ID="${3:-$APP_STORE_CONNECT_KEY_ID}"
ISSUER_ID="${4:-$APP_STORE_CONNECT_ISSUER_ID}"

if [ -z "$APP_BUNDLE" ]; then
    echo "Usage: $0 <app-bundle> [api-key-path] [key-id] [issuer-id]"
    echo ""
    echo "Arguments:"
    echo "  app-bundle     Path to the signed .app bundle"
    echo "  api-key-path   Path to App Store Connect API key (.p8 file)"
    echo "  key-id         App Store Connect Key ID"
    echo "  issuer-id      App Store Connect Issuer ID"
    echo ""
    echo "Or set environment variables:"
    echo "  APP_STORE_CONNECT_API_KEY_PATH"
    echo "  APP_STORE_CONNECT_KEY_ID"
    echo "  APP_STORE_CONNECT_ISSUER_ID"
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}ERROR: App bundle not found: $APP_BUNDLE${NC}"
    exit 1
fi

if [ -z "$API_KEY_PATH" ] || [ -z "$KEY_ID" ] || [ -z "$ISSUER_ID" ]; then
    echo -e "${RED}ERROR: Missing API credentials${NC}"
    echo "Provide via arguments or environment variables"
    exit 1
fi

if [ ! -f "$API_KEY_PATH" ]; then
    echo -e "${RED}ERROR: API key file not found: $API_KEY_PATH${NC}"
    exit 1
fi

APP_NAME=$(basename "$APP_BUNDLE" .app)
TEMP_DIR=$(mktemp -d)
ZIP_FILE="$TEMP_DIR/${APP_NAME}.zip"

trap "rm -rf $TEMP_DIR" EXIT

echo "========================================"
echo "  Notarizing $APP_NAME"
echo "========================================"
echo ""
echo "App Bundle: $APP_BUNDLE"
echo "Key ID:     $KEY_ID"
echo ""

# Create ZIP for notarization
echo "--- Creating ZIP archive ---"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_FILE"
echo "Created: $ZIP_FILE"
echo ""

# Submit for notarization
echo "--- Submitting for notarization ---"
echo "This may take several minutes..."
echo ""

RESULT_FILE="$TEMP_DIR/result.json"

set +e
xcrun notarytool submit "$ZIP_FILE" \
    --key "$API_KEY_PATH" \
    --key-id "$KEY_ID" \
    --issuer "$ISSUER_ID" \
    --output-format json \
    --wait \
    --timeout 30m > "$RESULT_FILE" 2>&1
NOTARIZE_STATUS=$?
set -e

# Parse result
SUBMISSION_ID=$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$RESULT_FILE" | head -1 | cut -d'"' -f4)
STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$RESULT_FILE" | head -1 | cut -d'"' -f4)

echo "Submission ID: $SUBMISSION_ID"
echo "Status: $STATUS"
echo ""

# Handle failure
if [ "$STATUS" != "Accepted" ]; then
    echo -e "${RED}Notarization FAILED${NC}"
    echo ""
    echo "=== Notarization Result ==="
    cat "$RESULT_FILE"
    echo ""

    if [ -n "$SUBMISSION_ID" ]; then
        echo "=== Fetching detailed log ==="
        LOG_FILE="$TEMP_DIR/log.json"
        xcrun notarytool log "$SUBMISSION_ID" \
            --key "$API_KEY_PATH" \
            --key-id "$KEY_ID" \
            --issuer "$ISSUER_ID" \
            "$LOG_FILE" 2>&1 || true

        if [ -f "$LOG_FILE" ]; then
            cat "$LOG_FILE"
        fi
    fi
    exit 1
fi

echo -e "${GREEN}Notarization ACCEPTED!${NC}"
echo ""

# Staple the notarization ticket
echo "--- Stapling notarization ticket ---"
xcrun stapler staple "$APP_BUNDLE"

# Verify
echo ""
echo "--- Verifying notarization ---"
if xcrun stapler validate "$APP_BUNDLE"; then
    echo ""
    echo -e "${GREEN}SUCCESS: App is notarized and stapled${NC}"
else
    echo ""
    echo -e "${RED}ERROR: Stapler validation failed${NC}"
    exit 1
fi

echo ""
echo "========================================"
echo "  Done!"
echo "========================================"
echo ""
echo "Your app is ready for distribution."
