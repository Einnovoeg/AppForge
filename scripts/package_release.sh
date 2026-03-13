#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

function require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool: $1" >&2
        exit 1
    fi
}

require_tool xcodegen
require_tool xcodebuild

MARKETING_VERSION=$(awk '/MARKETING_VERSION:/ { print $2; exit }' "$REPO_ROOT/project.yml")
BUILD_NUMBER=$(awk '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' "$REPO_ROOT/project.yml")

if [[ -z "$MARKETING_VERSION" || -z "$BUILD_NUMBER" ]]; then
    echo "Unable to read release version from project.yml" >&2
    exit 1
fi

DIST_ROOT="$REPO_ROOT/dist"
RELEASE_ROOT="$DIST_ROOT/$MARKETING_VERSION"
DERIVED_DATA_PATH="$RELEASE_ROOT/DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/AppForge.app"
ZIP_PATH="$RELEASE_ROOT/AppForge-$MARKETING_VERSION-macos-arm64.zip"
DMG_STAGING_PATH="$RELEASE_ROOT/dmg"
DMG_PATH="$RELEASE_ROOT/AppForge-$MARKETING_VERSION.dmg"
CHECKSUM_PATH="$RELEASE_ROOT/AppForge-$MARKETING_VERSION-SHA256.txt"

rm -rf "$RELEASE_ROOT"
mkdir -p "$RELEASE_ROOT"

cd "$REPO_ROOT"
xcodegen generate
xcodebuild \
    -project AppForge.xcodeproj \
    -scheme AppForge \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

if [[ ! -d "$APP_PATH" ]]; then
    echo "Release build did not produce $APP_PATH" >&2
    exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

mkdir -p "$DMG_STAGING_PATH"
cp -R "$APP_PATH" "$DMG_STAGING_PATH/AppForge.app"
ln -s /Applications "$DMG_STAGING_PATH/Applications"
hdiutil create \
    -volname "AppForge $MARKETING_VERSION" \
    -srcfolder "$DMG_STAGING_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
rm -rf "$DMG_STAGING_PATH"

shasum -a 256 "$ZIP_PATH" "$DMG_PATH" > "$CHECKSUM_PATH"

echo "Packaged AppForge $MARKETING_VERSION ($BUILD_NUMBER)"
echo "ZIP: $ZIP_PATH"
echo "DMG: $DMG_PATH"
echo "SHA256: $CHECKSUM_PATH"
