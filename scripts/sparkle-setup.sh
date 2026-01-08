#!/bin/bash
# Sparkle EdDSA Key Setup
#
# This script generates an EdDSA key pair for Sparkle update signing.
# Run this ONCE during initial setup.
#
# Usage: ./scripts/sparkle-setup.sh
#
# After running:
# 1. Copy the PUBLIC key to Sources/App/Info.plist (SUPublicEDKey)
# 2. Store the PRIVATE key as a GitHub secret (SPARKLE_EDDSA_PRIVATE_KEY)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SPARKLE_VERSION="2.8.1"
TOOLS_DIR="$PROJECT_ROOT/.sparkle-tools"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=== Sparkle EdDSA Key Setup ==="
echo ""

# Find or download generate_keys tool
GENERATE_KEYS=""

# Check common locations first
for path in \
    "$TOOLS_DIR/bin/generate_keys" \
    "$PROJECT_ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_keys" \
    "/usr/local/bin/generate_keys"
do
    if [ -x "$path" ]; then
        GENERATE_KEYS="$path"
        break
    fi
done

# Download Sparkle tools if not found
if [ -z "$GENERATE_KEYS" ]; then
    echo -e "${YELLOW}Sparkle tools not found. Downloading...${NC}"
    echo ""

    mkdir -p "$TOOLS_DIR"
    DOWNLOAD_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    TEMP_DIR=$(mktemp -d)

    echo "Downloading Sparkle ${SPARKLE_VERSION}..."
    curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/Sparkle.tar.xz"

    echo "Extracting tools..."
    tar -xf "$TEMP_DIR/Sparkle.tar.xz" -C "$TEMP_DIR"

    # Copy only the tools we need
    mkdir -p "$TOOLS_DIR/bin"
    cp "$TEMP_DIR/bin/generate_keys" "$TOOLS_DIR/bin/"
    cp "$TEMP_DIR/bin/sign_update" "$TOOLS_DIR/bin/"
    chmod +x "$TOOLS_DIR/bin/"*

    rm -rf "$TEMP_DIR"

    GENERATE_KEYS="$TOOLS_DIR/bin/generate_keys"
    echo -e "${GREEN}Sparkle tools installed to $TOOLS_DIR${NC}"
    echo ""
fi

if [ ! -x "$GENERATE_KEYS" ]; then
    echo -e "${RED}Error: Failed to locate or download generate_keys tool.${NC}"
    exit 1
fi

echo "Using: $GENERATE_KEYS"
echo ""

# Generate or get existing keys
echo "Checking for existing keys or generating new ones..."
echo ""

# Run generate_keys (creates new key if none exists, or shows existing public key)
OUTPUT=$("$GENERATE_KEYS" 2>&1)
echo "$OUTPUT"
echo ""

# Extract public key
PUBLIC_KEY=$(echo "$OUTPUT" | grep -oE '[A-Za-z0-9+/]{43}=' | head -1)

# Export private key to temp file
TEMP_KEY_FILE=$(mktemp)
rm -f "$TEMP_KEY_FILE"  # generate_keys won't overwrite existing file
trap "rm -f $TEMP_KEY_FILE" EXIT

echo "Exporting private key..."
if "$GENERATE_KEYS" -x "$TEMP_KEY_FILE" 2>&1; then
    PRIVATE_KEY=$(cat "$TEMP_KEY_FILE")
    rm -f "$TEMP_KEY_FILE"
else
    PRIVATE_KEY=""
    echo -e "${YELLOW}Could not export private key. You may need to allow Keychain access.${NC}"
fi

echo ""
echo -e "${GREEN}=== Keys ===${NC}"
echo ""
echo -e "${BLUE}1. PUBLIC KEY (for Info.plist SUPublicEDKey):${NC}"
if [ -n "$PUBLIC_KEY" ]; then
    echo -e "   ${GREEN}$PUBLIC_KEY${NC}"
else
    echo -e "   ${RED}Not found${NC}"
fi
echo ""

echo -e "${BLUE}2. PRIVATE KEY (for GitHub secret SPARKLE_EDDSA_PRIVATE_KEY):${NC}"
if [ -n "$PRIVATE_KEY" ]; then
    echo -e "   ${GREEN}$PRIVATE_KEY${NC}"
else
    echo -e "   ${RED}Not found - check Keychain Access for 'Sparkle' entries${NC}"
fi
echo ""

# Offer to update Info.plist
INFO_PLIST="$PROJECT_ROOT/Sources/App/Info.plist"
if [ -f "$INFO_PLIST" ] && [ -n "$PUBLIC_KEY" ]; then
    CURRENT_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$INFO_PLIST" 2>/dev/null || echo "")
    if [ "$CURRENT_KEY" != "$PUBLIC_KEY" ]; then
        echo -e "${YELLOW}Would you like to update Info.plist with the public key? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $PUBLIC_KEY" "$INFO_PLIST"
            echo -e "${GREEN}Updated SUPublicEDKey in Info.plist${NC}"
        fi
    else
        echo -e "${GREEN}Info.plist already has the correct public key.${NC}"
    fi
fi

echo ""
echo -e "${RED}WARNING: The private key is sensitive - never commit it to the repository!${NC}"
echo ""
echo "=== Setup Complete ==="
