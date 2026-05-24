## v1.24.0 (2026-05-24)

### Feat

- **desktop**: History & Settings as system windows
- **desktop**: window manager — traffic lights, z-order, min/max/snap, dock
- **desktop**: desktop icon grid + Spotlight palette
- **desktop**: replace sidebar with full-bleed macOS-style shell

## v1.23.0 (2026-05-23)

### Feat

- add Generator tool (password / token / UUID)
- add UUID / ULID parser tool

## v1.22.0 (2026-05-23)

### Feat

- add IP / CIDR parser tool

## v1.21.0 (2026-05-23)

### Feat

- add Hash tool (MD5 / SHA-1 / SHA-256 / SHA-512)

## v1.20.0 (2026-05-22)

### Feat

- add JWT decoder tool

## v1.19.0 (2026-05-22)

### Feat

- Base64 image preview + byte-delta at canvas width (Direction B phase 7)
- bps pinned-baseline delta at canvas width (Direction B phase 7)
- Timestamp UTC/Local toggle + Now/Start-of-day keys at canvas width (Direction B phase 7)
- Number Base interactive bit-grid at canvas width (Direction B phase 7)
- Cron 7-day fire strip at canvas width (Direction B phase 7)
- List inline count + Diff-with action at canvas width (Direction B phase 7)
- Diff dual-pane default at canvas width (Direction B phase 7)
- JSON two-pane layout at canvas width (Direction B phase 7)
- QR big preview + inline ECC/size controls (Direction B phase 7)
- Color session palette strip (Direction B phase 7)
- Bytes hexdump view + Latin-1/UTF-16LE decode (Direction B phase 7)
- Math visible tape unlock + canvas width-gate helper (Direction B phase 7)
- remaining canvas link pairs — Number/Math, Timestamp/Math, List/Diff, Color (Direction B phase 6)
- pipe-drag pipeline — typed in-canvas drags (Direction B phase 4)

## v1.18.0 (2026-05-22)

### Feat

- wire flagship Base64↔JSON live link end-to-end (ADR 0001)
- canonical-hub link engine (ADR 0001) — model + controller API

## v1.17.0 (2026-05-22)

### Feat

- desktop multi-card canvas (Direction B) — canvas MVP (#73)

## v1.16.0 (2026-05-21)

### Feat

- add YAML / TOML conversion to the JSON tool

## v1.15.0 (2026-05-21)

### Feat

- **desktop**: bound the shell into a height-capped, bordered window
- **web**: move the desktop toggle into the iPhone frame
- **desktop**: cap and center the shell on wide displays
- **web**: render desktop view on wide web with a layout toggle
- **web**: add desktop shell, sidebar, and in-pane tool view
- **web**: add view-mode state and shell-layout resolver

## v1.14.0 (2026-05-20)

### Feat

- **diff**: scroll long diff lines horizontally

### Fix

- **detail**: ellipsize long tool names in the nav bar
- **tools**: shorten input placeholders to fit the field
- **a11y**: keep layouts within bounds at large Dynamic Type

## v1.13.0 (2026-05-20)

### Feat

- **diff**: add Diff tool — body, catalog entry, and icon
- **mq**: hide ToolActionBar paste button when no handler is bound
- **diff**: add Myers line/word diff parser

## v1.12.0 (2026-05-20)

### Feat

- **list**: add List tool with split/join UI
- **list**: add split/join list parser

### Fix

- **list**: thread actionBar through List tool after Magic Box merge
- **detect**: defer Math to List for bulleted/numbered input

## v1.11.0 (2026-05-16)

### Feat

- apply Magic Box design handoff (6 items in one PR)

### Fix

- **nav**: give tab bar vertical breathing room
- **nav**: add 10px top padding to tab bar icons

## v1.10.0 (2026-05-15)

### Feat

- add Math expression evaluator tool

## v1.9.0 (2026-05-13)

### Feat

- **brand**: add hammer+quill marketing render
- **web**: regenerate favicon + PWA icons + splash for hammer+quill
- **ios**: regenerate AppIcon + LaunchImage for hammer+quill
- **brand**: redesign monogram to bracketed hammer+quill
- **web**: v1.7.0 launch SEO metadata + PWA manifest

### Refactor

- **brand**: MqMonogram renders SVG asset instead of Text.rich

## v1.8.0 (2026-05-12)

### Feat

- **web**: brand icons, PWA splash, manifest + theme-color meta
- **ios**: regenerate AppIcon + LaunchImage from brand assets
- **splash**: Dart-side splash crossfade + MqMonogram/MqSplashScreen
- **brand**: add SVG mark sources + rasterization pipeline

## v1.7.0 (2026-05-10)

### Feat

- **routing**: shared ToolDetailRoute wrapper
- **home**: ToolGridCard editorial grid tile
- **home**: CompactPasteBar two-stage hero composer
- **input**: MqInput accepts external focus node
- **widgets**: add masthead, rule, reading block, wordmark, monogram
- **widgets**: refresh mq components with editorial tokens
- **widgets**: remap MqIcons to Lucide
- **theme**: density tokens, controller, and MqTokens wiring
- **theme**: editorial palette and Plex typography with WCAG extensions
- **theme**: bundle IBM Plex fonts and flutter_lucide dep

### Fix

- **home**: early-return _onHeroChange when unmounted
- **icons**: map flash + flashFill to distinct Lucide glyphs

### Refactor

- **home**: drop redundant recentIds, single-pass _sortCatalog
- **utils**: extract truncateWithEllipsis helper
- **home**: swap inline-expand grid for push-route card grid
- **widgets**: MqRecentsRow consumes SectionRule
- **theme**: collapse typography style builders
- **state**: use enum.name in DensityController persistence

### Perf

- **theme**: cache Listenable.merge and drop MqDensityScope

## v1.6.0 (2026-05-09)

### Feat

- **cron**: add Cron tool body and register in catalog
- **cron**: add POSIX 5-field and natural-language parsers

## v1.5.0 (2026-05-07)

### Feat

- **home**: auto-expand single match, recents row, grid preview, long-press copy
- **mq**: InlineToolCard header morph + MqRecentsRow
- **tools**: add OpenInFooter for cross-tool output piping
- **home**: rows act as chips; selecting one hides the rest
- **home**: chip toggle + persistent body; remove Search tab
- **input**: heuristic paste detection on MqInput via controller listener
- **search**: inline tool cards replace per-result push navigation
- **home**: inline tool cards replace per-tile push navigation
- **history**: dedupe consecutive same-tool same-input adds
- **ui**: add InlineToolCard, HistoryRecorder, SeedSource scaffolding

### Refactor

- consolidate recorder glue, fix layering, type-safe expanded id
- **catalog**: builder returns body widget; delete *_screen wrappers
- **tools**: extract embeddable bodies, wire HistoryRecorder

## v1.4.0 (2026-05-03)

### Feat

- **qr**: add QR code reader and generator

### Fix

- **qr**: dispose ui.Image after PNG encode to free native memory
- **qr**: share works on web by dropping dart:io File temp-write

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
