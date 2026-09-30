#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$ROOT_DIR/.build/xcode}"
APP_NAME="OmniRouteWidget"
DISPLAY_NAME="OmniRoute Widget"
VERSION="${VERSION:-0.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

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

test -d "$BUILT_APP"
ditto "$BUILT_APP" "$APP_BUNDLE"

EXTENSION_BUNDLE="$APP_BUNDLE/Contents/PlugIns/OmniRouteDesktopWidget.appex"
test -d "$EXTENSION_BUNDLE"

echo "Ad-hoc signing widget extension and app..."
codesign   --force   --sign -   --timestamp=none   --entitlements "$ROOT_DIR/Config/OmniRouteDesktopWidget.entitlements"   "$EXTENSION_BUNDLE"

codesign   --force   --deep   --sign -   --timestamp=none   --entitlements "$ROOT_DIR/Config/OmniRouteWidget.entitlements"   "$APP_BUNDLE"

codesign --verify --deep --strict "$APP_BUNDLE"

echo "Verifying WidgetKit extension registration metadata..."
WIDGET_BUNDLE_ID="com.overbit.OmniRouteWidget.Widget"
/usr/bin/plutil -p "$EXTENSION_BUNDLE/Contents/Info.plist"
/usr/bin/codesign -d --entitlements :- "$EXTENSION_BUNDLE" 2>&1
/usr/bin/pluginkit -a -v "$EXTENSION_BUNDLE"
PLUGIN_MATCHES="$(/usr/bin/pluginkit -m -A -D -vvv -p com.apple.widgetkit-extension 2>&1)"
printf '%s\n' "$PLUGIN_MATCHES"
printf '%s\n' "$PLUGIN_MATCHES" | grep -F "$EXTENSION_BUNDLE" >/dev/null

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
echo "Creating $DMG_PATH..."
hdiutil create   -quiet   -volname "$DISPLAY_NAME"   -srcfolder "$STAGING_DIR"   -ov   -format UDZO   "$DMG_PATH"

test -s "$DMG_PATH"
echo "Created $DMG_PATH"
