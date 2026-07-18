# Masquerade

> A quiet toolbox for builders.

A Flutter utility-toolbox app — a digital toolbox for the small everyday conversions you keep googling. On-device, offline, untracked. iOS-styled (Cupertino) and built to run on Android, iOS, web, macOS, Linux, and Windows from one codebase. The App Store build ships iPhone-only — iPad has no layout of its own ([ADR 0003](docs/adr/0003-iphone-only-ios-target.md)).

[![CI](https://github.com/howard86/masquerade/actions/workflows/ci.yml/badge.svg)](https://github.com/howard86/masquerade/actions/workflows/ci.yml)

## What's in the toolbox today

Twenty-three tools, each reachable from the Home screen's grid or via search:

- **Log & Stack Inspector** — locally group, search, redact, copy, and share JSON Lines, plain logs, and stack traces.
- **Unicode Inspector** — reveal grapheme clusters, code points, UTF-8 bytes, invisible/bidi controls, line endings, and explicit normalization changes.
- **X.509 Inspector** — inspect local PEM / DER certificates and chains, fingerprints, validity, SANs, and public-key details without remote lookup.
- **HTTP Inspector** — locally inspect, redact, and convert static HTTP request snippets without sending them.
- **Artifact Inspector** — recursively trace nested encodings with bounded, sensitive-safe previews.
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
- **Desktop OS on wide web** — at ≥ 900 px the app becomes a full-bleed macOS-style desktop: menubar, wallpaper, desktop icons, a dock, and a ⌘K Spotlight palette. Tools open as windows (traffic-light chrome, minimize / maximize / edge-snap) with live links that pipe one window's output into the next and saved layouts that persist. History and Settings open as system windows; a menu item drops back to the mobile view.

## Requirements

- Flutter `3.41.8` (CI-pinned).
- Platform toolchains for whichever target you're building (Xcode for iOS/macOS, Android SDK for `apk`, etc.).
- Python 3 + `pip3` for the pre-commit hooks.

## Run

```bash
flutter pub get
flutter run                    # first connected device
flutter run -d chrome          # web
flutter run -d macos           # desktop
```

CI builds and ships the iOS release itself: a green `main` uploads to TestFlight automatically. Run `flutter build <target> --release` locally only when you need to debug a specific platform.

## Releases

`develop` is the default branch. [release-please](.github/workflows/release.yml) opens a Release PR from it (version bump + CHANGELOG) and retargets it to `main`; merging that PR promotes `develop`, tags `vX.Y.Z`, and deploys to TestFlight in one hop. Don't tag by hand.

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

2. Branch from `develop` using `feature/<slug>` and use Conventional Commit prefixes (`feat:`, `fix:`, `docs:`, `chore:`). PRs target `develop`; `main` only receives Release PRs.

3. Cupertino widgets only — `pubspec.yaml` has `uses-material-design: false`. Don't introduce `Material*` widgets without team discussion.

4. Mirror `lib/` structure under `test/` and add tests for new functionality.

## License

Source-available, **not** open-source — see [LICENSE](LICENSE). You may read, fork, and build it locally; you may not redistribute it or publish a derived app. Masquerade is sold as a one-time purchase on the App Store, and that listing is the only authorised distribution of the compiled app. Contributions are welcome under the terms in `LICENSE`.

The bundled IBM Plex fonts are licensed separately under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).
