#!/bin/bash
#
# build-app.sh - Build SkillsManager.app bundle for local use
#
# Produces a properly bundled, ad-hoc signed macOS application at
# build/SkillsManager.app. The bundle has a Dock icon, app menu,
# and Sparkle.framework wired up — i.e. behaves like a real installed
# app rather than a raw `swift run` executable.
#
# Usage:
#   ./scripts/build-app.sh            # build, then `open` the app
#   ./scripts/build-app.sh --no-open  # build only
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

OPEN_AFTER_BUILD=1
for arg in "$@"; do
    case "$arg" in
        --no-open) OPEN_AFTER_BUILD=0 ;;
        --open) OPEN_AFTER_BUILD=1 ;;  # kept for back-compat; now the default
        -h|--help)
            sed -n '2,15p' "$0"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $arg${NC}"
            exit 1
            ;;
    esac
done

# Locate repo root (script lives in scripts/). Resolve symlinks so the
# script works when invoked through a symlink in ~/Documents/BashScriptSource.
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="SkillsManager"
BUNDLE_NAME="SkillsManager.app"
BUILD_DIR="$REPO_ROOT/build"
APP_BUNDLE="$BUILD_DIR/$BUNDLE_NAME"
RELEASE_DIR="$REPO_ROOT/.build/release"

echo -e "${YELLOW}==> Building release binary${NC}"
swift build -c release

if [ ! -f "$RELEASE_DIR/$APP_NAME" ]; then
    echo -e "${RED}ERROR: Release binary not found at $RELEASE_DIR/$APP_NAME${NC}"
    exit 1
fi

echo -e "${YELLOW}==> Creating bundle structure at $APP_BUNDLE${NC}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

echo -e "${YELLOW}==> Copying executable${NC}"
cp "$RELEASE_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo -e "${YELLOW}==> Copying Info.plist${NC}"
cp Sources/App/Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo -e "${YELLOW}==> Writing PkgInfo${NC}"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

if [ -d "$RELEASE_DIR/Sparkle.framework" ]; then
    echo -e "${YELLOW}==> Copying Sparkle.framework${NC}"
    cp -R "$RELEASE_DIR/Sparkle.framework" "$APP_BUNDLE/Contents/Frameworks/"

    # SwiftPM-built binaries have rpath @loader_path (= Contents/MacOS) but
    # frameworks live in Contents/Frameworks. Add the standard app-bundle
    # rpath so dyld can resolve Sparkle.
    install_name_tool -add_rpath "@executable_path/../Frameworks" \
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
else
    echo -e "${YELLOW}==> Sparkle.framework not in release dir, skipping${NC}"
fi

echo -e "${YELLOW}==> Compiling asset catalog (icon)${NC}"
# actool compiles Assets.xcassets into Assets.car and emits AppIcon.icns
# Partial Info.plist would contain CFBundleIcons keys, but our Info.plist
# already uses the legacy CFBundleIconFile=AppIcon, so we let actool drop
# AppIcon.icns into Resources/ and rely on that key.
ACTOOL_PARTIAL_PLIST="$(mktemp -t actool-partial.XXXXXX.plist)"
xcrun actool \
    Sources/App/Resources/Assets.xcassets \
    --compile "$APP_BUNDLE/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$ACTOOL_PARTIAL_PLIST" \
    --output-format human-readable-text >/dev/null
rm -f "$ACTOOL_PARTIAL_PLIST"

# actool may emit the icon as either AppIcon.icns or embedded in Assets.car.
# If only Assets.car was produced, build AppIcon.icns from the iconset so
# the legacy CFBundleIconFile=AppIcon entry resolves.
if [ ! -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
    echo -e "${YELLOW}==> Generating AppIcon.icns from iconset${NC}"
    ICONSET_SRC="Sources/App/Resources/Assets.xcassets/AppIcon.appiconset"
    TMP_ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$TMP_ICONSET"
    # iconutil expects icon_<size>x<size>.png and icon_<size>x<size>@2x.png — same naming we already use
    cp "$ICONSET_SRC"/icon_*.png "$TMP_ICONSET/" 2>/dev/null || true
    if ls "$TMP_ICONSET"/icon_*.png >/dev/null 2>&1; then
        iconutil -c icns "$TMP_ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    else
        echo -e "${YELLOW}    (no PNGs found in iconset, app will use default icon)${NC}"
    fi
    rm -rf "$(dirname "$TMP_ICONSET")"
fi

echo -e "${YELLOW}==> Ad-hoc code signing${NC}"
# Ad-hoc signature (-) lets Gatekeeper run the app locally without a
# Developer ID. For distribution use scripts/sign-app.sh instead.
if [ -d "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" ]; then
    codesign --force --deep --sign - "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" >/dev/null
fi
codesign --force --sign - \
    --entitlements Sources/App/entitlements.plist \
    "$APP_BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null
codesign --force --sign - "$APP_BUNDLE" >/dev/null

echo ""
echo -e "${GREEN}SUCCESS${NC}: $APP_BUNDLE"
echo ""
echo "Run it with:"
echo "  open $APP_BUNDLE"
echo ""

if [ "$OPEN_AFTER_BUILD" -eq 1 ]; then
    echo -e "${YELLOW}==> Opening app${NC}"
    open "$APP_BUNDLE"
fi
