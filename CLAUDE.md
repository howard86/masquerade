# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Masquerade is a Flutter utility-toolbox app. Current shipped tools (single-screen `MyHomePage` in `lib/home_page.dart`): timestamp parsing (Unix s/ms, ISO 8601) and encoding detection/conversion (Base64, Hex). Design is iOS-first using `CupertinoApp`.

## Stack

- Flutter `3.35.5` (pinned in `.github/workflows/ci.yml`).
- UI: Cupertino widgets only (`uses-material-design: false` in `pubspec.yaml`). Do not introduce `Material*` widgets, `Scaffold`, or `MaterialApp`.
- `device_frame` is used by `lib/widgets/iphone_frame.dart` for the in-app preview wrapper.
- `build_runner`, `json_serializable`, `json_annotation`, `mockito` are dev deps but **not currently used** — no codegen step is wired up. Do not add `*.g.dart` imports without also wiring the generator.

## Layout

```
lib/
  main.dart            entry point
  app.dart             CupertinoApp root
  home_page.dart       sole screen
  utils/               pure parsers (timestamp_parser.dart, encoding_parser.dart, copy_util.dart)
  widgets/             reusable Cupertino widgets
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

Hooks (in `.pre-commit-config.yaml`): `dart format --output=none --set-exit-if-changed`, `flutter analyze`, `commitizen` (commit-msg stage). `detect-secrets` is intentionally disabled. Don't bypass; fix the underlying issue.

## Conventions

- **Conventional Commits** (`commitizen` runs at commit-msg stage). Prefixes seen in history: `feat:`, `fix:`, `docs:`, `chore:`. Dependabot uses `deps(deps):` — that prefix is grandfathered, don't copy it for hand-written commits. Branches: `feature/<slug>`.
- **Cupertino-only widgets.** If a Material-only API is needed, raise it before adding the dependency.
- **Tests required for new functionality.** Mirror `lib/` structure under `test/` using `flutter_test`.

## Gotchas

- Worktrees live at `.worktrees/<branch-name>` (gitignored). Run `git worktree list` before assuming working-tree state.
- The `PostToolUse` hook in `.claude/settings.json` runs `dart format` on edited `*.dart` files. If a format error surfaces in the transcript, fix the syntax — don't silence it.
