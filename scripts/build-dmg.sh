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

echo "Building and ad-hoc signing $APP_NAME with WidgetKit extension..."
xcodebuild   -project "$ROOT_DIR/OmniRouteWidget.xcodeproj"   -scheme "$APP_NAME"   -configuration Release   -derivedDataPath "$DERIVED_DATA_DIR"   -destination "platform=macOS"   CODE_SIGNING_ALLOWED=YES   CODE_SIGNING_REQUIRED=YES   CODE_SIGN_STYLE=Manual   CODE_SIGN_IDENTITY="-"   DEVELOPMENT_TEAM=""   MARKETING_VERSION="$VERSION"   CURRENT_PROJECT_VERSION="$BUILD_NUMBER"   build

BUILT_APP="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME.app"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
EXTENSION_BUNDLE="$APP_BUNDLE/Contents/PlugIns/OmniRouteDesktopWidget.appex"

test -d "$BUILT_APP"
ditto "$BUILT_APP" "$APP_BUNDLE"
test -d "$EXTENSION_BUNDLE"

echo "Verifying app and extension signatures..."
codesign --verify --deep --strict "$APP_BUNDLE"
codesign --verify --strict "$EXTENSION_BUNDLE"

echo "Verifying WidgetKit extension metadata..."
/usr/bin/plutil -p "$EXTENSION_BUNDLE/Contents/Info.plist"
/usr/bin/plutil -extract NSExtension.NSExtensionPointIdentifier raw   "$EXTENSION_BUNDLE/Contents/Info.plist"   | grep -Fx "com.apple.widgetkit-extension" >/dev/null

echo "Verifying WidgetKit extension entitlements..."
EXTENSION_ENTITLEMENTS="$(codesign -d --entitlements - --xml "$EXTENSION_BUNDLE" 2>&1)"
printf '%s\n' "$EXTENSION_ENTITLEMENTS"
printf '%s\n' "$EXTENSION_ENTITLEMENTS" | grep -F "com.apple.security.app-sandbox" >/dev/null
printf '%s\n' "$EXTENSION_ENTITLEMENTS" | grep -F "com.apple.security.network.client" >/dev/null

echo "Registering containing app with Launch Services..."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
"$LSREGISTER" -f -R -trusted "$APP_BUNDLE"

PLUGIN_MATCHES="$(/usr/bin/pluginkit -m -A -D -vvv 2>&1)"
printf '%s\n' "$PLUGIN_MATCHES"
printf '%s\n' "$PLUGIN_MATCHES" | grep -F "com.overbit.OmniRouteWidget.Widget" >/dev/null

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
echo "Creating $DMG_PATH..."
hdiutil create   -quiet   -volname "$DISPLAY_NAME"   -srcfolder "$STAGING_DIR"   -ov   -format UDZO   "$DMG_PATH"

test -s "$DMG_PATH"
echo "Created $DMG_PATH"
