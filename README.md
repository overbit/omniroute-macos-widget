# OmniRoute macOS Widget

A native macOS WidgetKit desktop widget for [OmniRoute](https://github.com/diegosouzapw/OmniRoute), with a small companion app that explains installation and configuration.

## What the widget shows

The UI is intentionally compact and glanceable:

- provider count and last refresh time
- up to two quota windows per provider
- thin remaining-quota bars
- color-coded remaining percentage
  - green: 50% or more left
  - orange: 20–49% left
  - red: below 20% left
- relative quota reset timing
- provider plan when OmniRoute returns one
- weekly API-key spend when per-key limits are enabled
- connection/error state
- manual widget refresh action

Widget sizes:

- **Small** — one provider and its highest-priority quota window
- **Medium** — up to three providers
- **Large** — up to seven providers

OmniRoute currently exposes `connectionId`, `provider`, `plan`, and quota windows through the self-service usage contract. It does not expose connection/account display labels there, so the widget uses the provider name as the primary label and plan as secondary text.

## OmniRoute API

The widget reads:

```text
GET /api/usage/om-usage?format=json
Authorization: Bearer <api-key>
```

The API key must have **Usage Command** (`allowUsageCommand`) enabled in OmniRoute.

## Install and configure

1. Copy **OmniRouteWidget.app** from the DMG to **Applications**.
2. Launch the app once.
3. Open the macOS widget gallery and add **OmniRoute**.
4. Right-click the placed widget and choose **Edit Widget**.
5. Enter the OmniRoute server URL and API key.

Configuration is stored by macOS as part of that widget instance. The WidgetKit extension connects directly to OmniRoute, so the distributable build does not require App Group or shared-Keychain entitlements.

An OpenAI-compatible OmniRoute URL ending in `/v1` is accepted and normalized to the server root.

### If OmniRoute does not appear in the widget gallery

Make sure the app is installed in `/Applications` and has been launched at least once. To inspect registration from Terminal:

```bash
pluginkit -m -A -D -vvv -p com.apple.widgetkit-extension | grep -i OmniRoute
```

The packaged extension bundle identifier is:

```text
com.overbit.OmniRouteWidget.Widget
```

## Refresh behavior

WidgetKit controls the final refresh schedule. The provider requests a new timeline approximately every 15 minutes, and the widget also exposes a manual refresh action.

## Build from source

Requirements:

- macOS 14 or later
- Xcode / Swift 6 toolchain
- XcodeGen

Install XcodeGen:

```bash
brew install xcodegen
```

Run the core tests:

```bash
swift test
```

Generate the Xcode project:

```bash
xcodegen generate
open OmniRouteWidget.xcodeproj
```

Build the distributable app and DMG:

```bash
./scripts/build-dmg.sh
```

The DMG is created at:

```text
dist/OmniRouteWidget.dmg
```

Pull-request CI produces an ad-hoc-signed **development** DMG for build validation. For normal end-user distribution, the release workflow requires a Developer ID Application certificate and notarizes the DMG with Apple so the embedded WidgetKit extension can be discovered reliably by macOS.

## Project structure

- `Sources/OmniRouteCore` — OmniRoute API models and client.
- `Sources/OmniRouteWidget` — companion macOS installation/configuration guide.
- `Sources/OmniRouteDesktopWidget` — WidgetKit extension, configuration intent, and compact desktop UI.
- `Tests/OmniRouteCoreTests` — URL normalization and usage-contract tests.
- `project.yml` — XcodeGen project definition.
- `scripts/build-dmg.sh` — builds the app, embeds/signs the WidgetKit extension, verifies registration metadata, and creates the DMG.

## CI and releases

Pull-request CI:

- runs `swift test`
- generates the Xcode project
- builds the app with the WidgetKit extension
- verifies that `OmniRouteDesktopWidget.appex` is embedded
- checks WidgetKit extension registration with `pluginkit`
- creates and uploads the DMG artifact

Pushes to the repository's default branch create a Developer-ID-signed, notarized GitHub Release and attach the DMG.

Configure these repository Actions secrets before merging to the default branch:

- `DEVELOPER_ID_APPLICATION_P12_BASE64` — base64-encoded Developer ID Application certificate plus private key in PKCS#12 format.
- `DEVELOPER_ID_APPLICATION_PASSWORD` — password for that PKCS#12 file.
- `APPLE_ID` — Apple ID used with the notary service.
- `APPLE_APP_SPECIFIC_PASSWORD` — app-specific password for that Apple ID.
- `APPLE_TEAM_ID` — Apple Developer Team ID.

The release workflow fails rather than publishing an ad-hoc DMG when those credentials are absent, because an ad-hoc build is only intended for CI/development validation and isn't a reliable direct-distribution format for a macOS app extension.
