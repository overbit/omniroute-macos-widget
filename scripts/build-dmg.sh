#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$ROOT_DIR/.build/xcode}"
APP_NAME="OmniRouteWidget"
DISPLAY_NAME="OmniRoute Widget"
VERSION="${VERSION:-0.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required (brew install xcodegen)" >&2
  exit 1
fi

rm -rf "$DIST_DIR" "$DERIVED_DATA_DIR"
mkdir -p "$DIST_DIR"

echo "Generating Xcode project..."
(
  cd "$ROOT_DIR"
  xcodegen generate
)

echo "Building $APP_NAME with WidgetKit extension..."
xcodebuild   -project "$ROOT_DIR/OmniRouteWidget.xcodeproj"   -scheme "$APP_NAME"   -configuration Release   -derivedDataPath "$DERIVED_DATA_DIR"   -destination "platform=macOS"   CODE_SIGNING_ALLOWED=NO   CODE_SIGNING_REQUIRED=NO   MARKETING_VERSION="$VERSION"   CURRENT_PROJECT_VERSION="$BUILD_NUMBER"   build

BUILT_APP="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME.app"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
EXTENSION_BUNDLE="$APP_BUNDLE/Contents/PlugIns/OmniRouteDesktopWidget.appex"

test -d "$BUILT_APP"
ditto "$BUILT_APP" "$APP_BUNDLE"
test -d "$EXTENSION_BUNDLE"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing WidgetKit extension with Developer ID..."
  codesign     --force     --sign "$SIGNING_IDENTITY"     --options runtime     --timestamp     --entitlements "$ROOT_DIR/Config/OmniRouteDesktopWidget.entitlements"     "$EXTENSION_BUNDLE"

  echo "Signing containing app with Developer ID..."
  codesign     --force     --sign "$SIGNING_IDENTITY"     --options runtime     --timestamp     "$APP_BUNDLE"
else
  echo "Ad-hoc signing CI build..."
  codesign     --force     --sign -     --timestamp=none     "$EXTENSION_BUNDLE"
  codesign     --force     --sign -     --timestamp=none     "$APP_BUNDLE"
fi

echo "Verifying app and extension signatures..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
codesign --verify --strict --verbose=2 "$EXTENSION_BUNDLE"

echo "Verifying WidgetKit extension metadata..."
/usr/bin/plutil -extract CFBundleIdentifier raw   "$EXTENSION_BUNDLE/Contents/Info.plist"   | grep -Fx "com.overbit.OmniRouteWidget.Widget" >/dev/null
/usr/bin/plutil -extract NSExtension.NSExtensionPointIdentifier raw   "$EXTENSION_BUNDLE/Contents/Info.plist"   | grep -Fx "com.apple.widgetkit-extension" >/dev/null

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Verifying distribution entitlements..."
  EXTENSION_ENTITLEMENTS="$(codesign -d --entitlements - "$EXTENSION_BUNDLE" 2>&1)"
  printf '%s\n' "$EXTENSION_ENTITLEMENTS"
  printf '%s\n' "$EXTENSION_ENTITLEMENTS" | grep -F "com.apple.security.app-sandbox" >/dev/null
  printf '%s\n' "$EXTENSION_ENTITLEMENTS" | grep -F "com.apple.security.network.client" >/dev/null
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
echo "Creating $DMG_PATH..."
hdiutil create   -quiet   -volname "$DISPLAY_NAME"   -srcfolder "$STAGING_DIR"   -ov   -format UDZO   "$DMG_PATH"

test -s "$DMG_PATH"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing DMG with Developer ID..."
  codesign     --force     --sign "$SIGNING_IDENTITY"     --timestamp     "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

echo "Created $DMG_PATH"
