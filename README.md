# OmniRoute macOS Widget

A native macOS WidgetKit desktop widget for [OmniRoute](https://github.com/diegosouzapw/OmniRoute), with a small companion app for connection settings.

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

## Configure the widget

1. Open **OmniRoute Widget.app**.
2. Enter the OmniRoute server URL and API key.
3. Click **Save & Test**.
4. Open the macOS widget gallery.
5. Add **OmniRoute** to the desktop or Notification Center.

The URL and API key are shared with the WidgetKit extension using the app-group/keychain entitlements. The API key is stored in Keychain.

An OpenAI-compatible OmniRoute URL ending in `/v1` is accepted and normalized to the server root.

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

The current build uses ad-hoc signing. Developer ID signing and Apple notarization are not configured.

## Project structure

- `Sources/OmniRouteCore` — OmniRoute API models, client, and shared configuration/Keychain access.
- `Sources/OmniRouteWidget` — companion macOS settings app.
- `Sources/OmniRouteDesktopWidget` — WidgetKit extension and compact desktop UI.
- `Tests/OmniRouteCoreTests` — URL normalization and usage-contract tests.
- `project.yml` — XcodeGen project definition.
- `scripts/build-dmg.sh` — builds the app, embeds/signs the WidgetKit extension, and creates the DMG.

## CI and releases

Pull-request CI:

- runs `swift test`
- generates the Xcode project
- builds the app with the WidgetKit extension
- verifies that `OmniRouteDesktopWidget.appex` is embedded
- creates and uploads the DMG artifact

Pushes to the repository's default branch create a GitHub Release and attach the DMG.
