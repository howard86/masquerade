# Masquerade

> A quiet toolbox for builders.

A Flutter utility-toolbox app — a digital toolbox for the small everyday conversions you keep googling. On-device, offline, untracked. iOS-styled (Cupertino) and built to run on Android, iOS, web, macOS, Linux, and Windows from one codebase. The App Store build ships iPhone-only — iPad has no layout of its own ([ADR 0003](docs/adr/0003-iphone-only-ios-target.md)).

[![CI](https://github.com/howard86/masquerade/actions/workflows/ci.yml/badge.svg)](https://github.com/howard86/masquerade/actions/workflows/ci.yml)

## What's in the toolbox today

Eighteen tools, each reachable from the Home screen's grid or via search:

- **UUID** — generate v4 / v7, validate any UUID, inspect version & variant, parse ULID; v1/v7/ULID timestamps cross-link into Timestamp.
- **IP / CIDR** — parse IPv4 / IPv6 and CIDR blocks; subnet network, broadcast, host range and count, netmask, and scope flags (private / loopback / link-local / multicast / documentation).
- **Number Base** — hex / binary / octal / decimal converter with grouped output.
- **Timestamp** — paste a Unix timestamp (seconds or milliseconds) or an ISO 8601 string; read it back in every other format. Tap any row to copy.
- **Cron** — translate between cron expressions and natural language, in both directions.
- **JSON / YAML / TOML** — pretty-print, minify, browse as an interactive tree, and convert between JSON, YAML, and TOML.
- **JWT** — decode header, payload, and standard claims from a JSON Web Token. Flags expired / not-yet-valid. Decode-only — no signature verification.
- **Base64** — encode/decode with URL-safe variant; auto-detects which way you meant.
- **URL** — percent-encode / decode, and break a URL into editable query parameters.
- **Color** — HEX / RGB / HSL / OKLCH conversion with WCAG contrast scoring.
- **Math** — expression evaluator with constants and functions (`pi`, `sin`, `log`, …).
- **bps · % · decimal** — basis points ↔ percent ↔ decimal.
- **Bytes** — byte array ↔ text (UTF-8).
- **List** — split ↔ join with custom separators.
- **Diff** — compare two texts with line- or word-level granularity.
- **Hash** — MD5 / SHA-1 / SHA-256 / SHA-512 digests with verify mode.
- **QR Code** — scan a code with the camera or generate one from text.
- **Generator** — generate secure passwords (configurable length + character sets), random tokens (hex / base64url / alphanumeric), and UUIDs (v4 / v7).

Plus, across every tool:

- **Live, debounced parsing** — results update as you type with a 200 ms debounce; unrecognized input surfaces an inline error banner instead of silent failure.
- **Light / dark / system theme + searchable history** — theme choice and per-tool history persist via `shared_preferences`.
- **Desktop OS on macOS and wide web** — at ≥ 900 px the native Mac app and web app become a full-bleed macOS-style desktop: menubar, wallpaper, desktop icons, a dock, and a ⌘K Spotlight palette. Tools open as windows (traffic-light chrome, minimize / maximize / edge-snap) with live links that pipe one window's output into the next and saved layouts that persist. History and Settings open as system windows; a menu item drops back to the mobile view.

## Requirements

- Flutter `3.41.8` (CI-pinned).
- Platform toolchains for whichever target you're building (Xcode for iOS/macOS, Android SDK for `apk`, etc.).
- Python 3 + `pip3` for the pre-commit hooks.

## Run

```bash
flutter pub get
flutter run                    # first connected device
flutter run -d chrome          # web
flutter run -d macos           # native desktop OS
```

CI does not produce release builds; run `flutter build <target> --release` locally only when you need to debug a specific platform.

## Test and lint

```bash
flutter test --coverage                          # full suite (matches CI)
flutter test test/utils/timestamp_parser_test.dart
flutter analyze
dart format --output=none --set-exit-if-changed .
```

## Contributing

1. Install pre-commit hooks once per clone:

   ```bash
   pip3 install pre-commit
   ./setup-precommit.sh
   ```

   Hooks enforce `dart format`, `flutter analyze`, and Conventional Commits via `commitizen`.

2. Branch from `main` using `feature/<slug>` and use Conventional Commit prefixes (`feat:`, `fix:`, `docs:`, `chore:`).

3. Cupertino widgets only — `pubspec.yaml` has `uses-material-design: false`. Don't introduce `Material*` widgets without team discussion.

4. Mirror `lib/` structure under `test/` and add tests for new functionality.
