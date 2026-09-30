# OmniRoute macOS Widget

A lightweight native macOS menu-bar widget for [OmniRoute](https://github.com/diegosouzapw/OmniRoute).

## What it shows

- API-key spend for today and this week when per-key limits are enabled.
- Provider quota windows for every provider returned by OmniRoute, including remaining percentage and reset time.
- Provider plan names when available.
- Connection/loading/error state and last refresh time.

The widget reads OmniRoute's self-service usage endpoint:

```text
GET /api/usage/om-usage?format=json
Authorization: Bearer <api-key>
```

The selected API key must have **Usage Command** (`allowUsageCommand`) enabled in OmniRoute.

## Configuration

Open **Settings…** from the menu-bar panel and enter:

- **OmniRoute URL** — for example `http://localhost:20128`. An OpenAI-compatible URL ending in `/v1` is accepted and normalized automatically.
- **API key** — stored in macOS Keychain. The key is never stored in UserDefaults.

The server URL is stored in app preferences.

## Run from source

Requirements:

- macOS 14 or later
- Xcode / Swift 6 toolchain

```bash
swift run OmniRouteWidget
```

Run the core tests with:

```bash
swift test
```

## Project structure

- `Sources/OmniRouteCore` — API models and the OmniRoute usage client.
- `Sources/OmniRouteWidget` — SwiftUI menu-bar UI, settings, and Keychain storage.
- `Tests/OmniRouteCoreTests` — URL normalization and usage-contract tests.
