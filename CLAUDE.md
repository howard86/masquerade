# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Masquerade is a Flutter utility-toolbox app. iOS-first (`CupertinoApp`). Tab scaffold (`lib/screens/root_tab_scaffold.dart`) with home / history / search / settings. Tools live as dedicated screens under `lib/screens/detail/` and are registered in `lib/utility_catalog.dart`:

- Timestamp (Unix s/ms, ISO 8601)
- Base64 (encode/decode, URL-safe)
- Number Base (hex/binary/octal/decimal)
- JSON (pretty/minify/tree)
- Color (HEX/RGB/HSL/OKLCH, WCAG contrast)
- bps (basis points ↔ % ↔ decimal)

Add new tools by registering in `UtilityCatalog` plus a detail screen. Search and home tabs read the catalog directly — there is no manual wiring elsewhere.

## Stack

- Flutter `3.41.8` (pinned in `.github/workflows/ci.yml`).
- UI: Cupertino widgets only (`uses-material-design: false` in `pubspec.yaml`). Do not introduce `Material*` widgets, `Scaffold`, or `MaterialApp`.
- Runtime deps: `cupertino_icons`, `intl`, `package_info_plus`, `shared_preferences`. No third-party UI packages — `lib/widgets/iphone_frame.dart` is hand-rolled.
- Dev deps are minimal: `flutter_test` + `flutter_lints` only. No codegen, no mock framework. If you reach for `build_runner`/`mockito`/`json_serializable`, add the dep AND wire the generator/CI step in the same change.

## Layout

```
lib/
  main.dart            entry point
  app.dart             CupertinoApp root + global controllers
  utility_catalog.dart catalog of every shipped tool + detection predicates
  screens/
    root_tab_scaffold.dart     4-tab Cupertino tab bar
    home_screen.dart, search_screen.dart, history_screen.dart, settings_screen.dart
    detail/<tool>_screen.dart  one screen per tool
  state/               ChangeNotifier controllers (theme_controller, history_controller); persisted via shared_preferences
  theme/               MqColors / MqTypography / MqMetrics / MqTheme InheritedWidget
  utils/               pure parsers (static `parse()`) + copy_util
  widgets/
    mq/                design-system widgets (MqButton, MqInput, MqSurface, ...) — prefer these over raw Cupertino
    iphone_frame.dart  hand-rolled preview wrapper
test/                  mirrors lib/ structure
```

Parsers follow a static `parse()` returning a result struct (see `TimestampParser`). Match this when adding new parsers.

## Commands (CI gates)

```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test --coverage              # what CI runs (.github/workflows/ci.yml)
flutter test test/path/to/file_test.dart
```

CI does NOT currently filter by tag; `flutter test` picks up everything in `test/`. There are no integration tests, but the pre-commit `[manual]` hook in `.pre-commit-config.yaml` does pass `--exclude-tags=integration` if you ever add some.

CI does not produce release artifacts — it only runs format, analyze, tests, and Trivy. `flutter build <target>` is local-only.

## Pre-commit (required, Python-based)

`flutter pub get` does not install pre-commit. New clones run:

```bash
pip3 install pre-commit
./setup-precommit.sh
```

Hooks (in `.pre-commit-config.yaml`):

- Always: `dart format --set-exit-if-changed`, `flutter analyze`, plus `pre-commit-hooks` basics (trailing-whitespace, end-of-file-fixer, check-yaml/json/toml/xml, mixed-line-ending=lf, large-file/merge-conflict checks).
- `commit-msg` stage: `commitizen` v4.13.9 (Conventional Commits).
- `[manual]` stage only: `flutter test --exclude-tags=integration`, `flutter build apk --debug`. Run via `pre-commit run --hook-stage manual`.
- `detect-secrets` is intentionally disabled. Don't bypass any of the above; fix the underlying issue.

## Conventions

- **Conventional Commits** (`commitizen` runs at commit-msg stage). Prefixes seen in history: `feat:`, `fix:`, `docs:`, `chore:`. Dependabot uses `deps(deps):` — that prefix is grandfathered, don't copy it for hand-written commits. Branches: `feature/<slug>`.
- **Cupertino-only widgets.** If a Material-only API is needed, raise it before adding the dependency.
- **Tests required for new functionality.** Mirror `lib/` structure under `test/` using `flutter_test`.

## Gotchas

- Worktrees live at `.worktrees/<branch-name>` (gitignored). Run `git worktree list` before assuming working-tree state.
- The `PostToolUse` hook in `.claude/settings.json` runs `dart format` on edited `*.dart` files. If a format error surfaces in the transcript, fix the syntax — don't silence it.
- Prefer `widgets/mq/*` (`MqButton`, `MqInput`, `MqSurface`, `MqMonoCell`, ...) over raw Cupertino primitives — they carry theme + spacing tokens. Read colors via `MqTheme.of(context)`, not hardcoded `CupertinoColors`.
- Tool registration is centralized: adding a tool means editing `lib/utility_catalog.dart` AND adding a detail screen under `lib/screens/detail/`. Search and home tabs auto-pick it up.
