## v1.3.0 (2026-05-03)

### Feat

- **bytes**: add Bytes utility tool

### Refactor

- **mq**: align MqEmptyHint API and migrate timestamp screen
- **mq**: extract MqEmptyHint, dedupe across detail screens

## v1.2.0 (2026-05-02)

### Feat

- **timestamp**: expand formats and add keyword picker UI

## v1.1.0 (2026-05-02)

### Feat

- **search**: empty state on no matches + clearance token
- **theme**: add MqLayout.tabBarClearance + MqColors.onTint
- **home**: redesign with hero paste + flat tool grid
- **screens**: add Home, Search, History, Settings + tab scaffold
- **screens**: add utility catalog and 6 detail screens
- **utils**: add number base, JSON, color, and bps parsers
- **widgets**: add Magic Box component primitives
- **state**: add theme, history, and favorites controllers
- **theme**: add Magic Box design tokens (colors, typography, metrics)
- setup pre-commit hooks and GitHub Actions CI/CD
- add encoding cards parsing hex & base64 encoding
- improve UI/UX with animations
- replace with iOS design
- add a timestmp converter app
- init from vscode extensions

### Fix

- **ci**: bump commitizen to 4.13.9 for action 0.27.1 compatibility
- **settings**: show live pubspec version + use clearance token
- **timestamp**: surface ambiguity badge in seconds/ms overlap range
- **lint**: adopt Dart 3 wildcard params and null-aware elements
- resolve GitHub Actions workflow issues

### Refactor

- **detail**: unify output header + empty-state copy
- **catalog**: normalize utility tints to literal hex
- **history**: tighten hand-rolled values via tokens
- **home**: use MqLayout.tabBarClearance for bottom padding
- rename Magic Box codename to Masquerade
- **widgets**: scale iPhone frame to viewport with 2x cap
- **widgets**: replace device_frame with hand-rolled iPhone frame
- **app**: wire Magic Box shell with iPhone frame across all routes
- **timestamp_display_card**: render via MBSurface and MBMonoCell
- **copy_util**: use Magic Box tokens for clipboard toast
- migrate Color.withOpacity to withValues
- clean up widgets and imports
