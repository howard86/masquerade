# Masquerade

A Flutter utility-toolbox app — a digital toolbox for the small everyday conversions you keep googling. iOS-styled (Cupertino) and built to run on Android, iOS, web, macOS, Linux, and Windows from one codebase.

[![CI](https://github.com/howard86/masquerade/actions/workflows/ci.yml/badge.svg)](https://github.com/howard86/masquerade/actions/workflows/ci.yml)

## What's in the toolbox today

- **Timestamp** — paste a Unix timestamp (seconds or milliseconds) or an ISO 8601 string; read it back in every other format. Tap any row to copy.
- **Base64** — encode/decode with URL-safe variant; auto-detects which way you meant.
- **Number Base** — hex / binary / octal / decimal converter with grouped output.
- **JSON** — pretty-print, minify, or browse as an interactive tree.
- **Color** — HEX / RGB / HSL / OKLCH conversion with WCAG contrast scoring.
- **bps** — basis points ↔ percent ↔ decimal.
- **Live, debounced parsing** — results update as you type with a 200 ms debounce; unrecognized input surfaces an inline error banner instead of silent failure.
- **Light / dark / system theme + searchable history** — theme choice and per-tool history persist via `shared_preferences`.

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
