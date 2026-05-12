# Editorial Design System — Plan

Status: locked spec, not yet implemented. Drafted via /grill-me on 2026-05-10.
Goal: visual identity refresh across all screens. Token-driven system stays; tokens, components, and screens all change.

## Narrative

"Masquerade" = mask, transformation. Tools transform data formats (timestamp ↔ ISO, base64 ↔ text, etc.). Brand voice: editorial restraint — book/journal, not dashboard. Color carries identity through warm paper + ink; type carries voice through serif display + sans body.

## Identity axes (all four refresh)

1. Color story — cool greys + cyan → warm cream + oxblood (light) / espresso + lamplight gold (dark).
2. Typography — SF-only → IBM Plex Serif (display) + Plex Sans (body) + Plex Mono (code).
3. Surface depth — drop shadows for non-modals; hairline rules + flat surfaces.
4. Motion — bouncy/spring → asymmetric reading-pace, no overshoot.

## Color tokens

### Light
| token | hex | role |
|---|---|---|
| bg | `#FAF7F2` | warm cream paper |
| surface | `#FFFDF8` | card paper |
| surface2 | `#F5F1E8` | inset/recessed |
| surface3 | `#F1ECE2` | mono code bg |
| border | `#1B1813 @ 12%` | hairline rule |
| borderStrong | `#1B1813 @ 24%` | emphasis rule |
| ink-pri (textPri) | `#1B1813` | body ink |
| ink-2 (textSec) | `#5C544A` | secondary |
| ink-3 (textTer) | `#9A8F82` | tertiary |
| accent | `#8B2635` | oxblood |
| accentInk | `#5E1923` | deeper oxblood |
| accentBg | `#8B2635 @ 10%` | tinted pill bg |
| onTint | `#FFFDF8` | foreground on accent fill |

### Dark (lamplight)
| token | hex | role |
|---|---|---|
| bg | `#14110D` | espresso |
| surface | `#1C1814` | card |
| surface2 | `#241F19` | inset |
| surface3 | `#2B241B` | mono bg |
| border | `#F2EBDC @ 14%` | hairline |
| borderStrong | `#F2EBDC @ 28%` | emphasis |
| ink-pri | `#F2EBDC` | cream text |
| ink-2 | `#A89B86` | secondary |
| ink-3 | `#6E6354` | tertiary |
| accent | `#E0B872` | lamplight gold |
| accentInk | `#F0D9A6` | brighter gold |
| accentBg | `#E0B872 @ 14%` | tinted bg |
| onTint | `#14110D` | foreground on accent fill |

### Status (muted, both modes)
| token | light | dark | role |
|---|---|---|---|
| success | `#2D5F3F` forest | `#7CB893` | confirm/parse-ok |
| warning | `#B07A1F` amber | `#E0B872`* | caution |
| danger | `#6E1F1F` rust | `#E08A8A` | destructive (≠ accent oxblood) |
| info | `#2D4A7A` ink-blue | `#8FB3E8` | informational |

*dark warning may visually overlap accent — disambiguate by glyph + label, not just color.
All status colors render only on tinted-bg pills, never raw text on paper.

### Mono syntax → status references
- `monoText → ink-pri`
- `monoComment → ink-2` (italic)
- `monoString → success`
- `monoNumber → warning`
- `monoKey → info`
- `monoPunc → ink-2`
- `monoBg → surface3`

### WCAG verification
- light ink-pri / bg ≈ 15.7:1 (AAA)
- light ink-2 / bg ≈ 6.3:1 (AA)
- light accent / bg ≈ 6.0:1 (AA, large+normal)
- dark ink-pri / bg ≈ 14.9:1 (AAA)
- dark ink-2 / bg ≈ 7.1:1 (AAA)
- dark accent / bg ≈ 10.2:1 (AAA)

## Typography — IBM Plex bundled

Drop SF references. Bundle Plex Serif + Plex Sans + Plex Mono via `pubspec.yaml` assets (latin subset, woff2 + ttf for Flutter).

### Style additions
- New `display`: 48 / 56 lh / weight 600 / Plex Serif / tr -0.5 — masthead + tool hero only.

### Family flips
- `display` → Plex Serif
- `largeTitle` → Plex Serif (was SF Pro)
- `title1`/`title2`/`title3`/`headline`/`body`/`callout`/`subhead`/`footnote`/`caption1`/`caption2`/`sectionLabel` → Plex Sans
- `monoXl`/`monoLg`/`monoMd`/`monoSm` → Plex Mono, retain `FontFeature.tabularFigures()`

iOS gives up native SF rendering — accepted tradeoff for cross-platform identity (Netlify web target rendered identical to native).

## Surface depth

- Drop `MqColors.shadow` and `shadowLg` from non-modal use.
- Cards: `surface` fill + 0.5px hairline `border` token.
- Sections: full-width `SectionRule` (hairline horizontal divider with optional centered label).
- Shadow tokens retained but applied only to floating modals + toasts.

## Motion

| token | curve | duration |
|---|---|---|
| reveal | `cubic-bezier(.2,.6,.2,1)` | 220–320ms |
| dismiss | `cubic-bezier(.4,0,.6,1)` | 180–240ms |
| stagger | linear | 60ms cascade between hero text lines |

Drop `springCurve` (overshoot) entirely. Existing `MqMotion.fast/normal/slow/spring` repurposed: `fast=180`, `normal=240`, `slow=320`. Remove `spring=420`.

## Density

New `DensityController` ChangeNotifier persisted via `shared_preferences` (mirrors `theme_controller.dart` pattern).

| mode | screen padding | card padding | min target |
|---|---|---|---|
| comfortable (default) | lg (16) → xl (24) on body, xl on headers | md (12) → lg (16) | 44 |
| compact | md (12) | sm (8) → md (12) | 36 |

Type scale unchanged across modes — editorial voice constant.
Toggle exposed in Settings → Density (segmented).

## Chrome

Cupertino primitives retained for shape + gestures. Tokens overridden:
- `CupertinoThemeData.barBackgroundColor` → `surface`
- `navTitleTextStyle` → Plex Sans headline
- `navLargeTitleTextStyle` → Plex Serif `largeTitle`
- `CupertinoTabBar.backgroundColor` → `surface @ 85%` (translucency retained)
- `CupertinoTabBar.activeColor` → `accent`
- `CupertinoTabBar` top border → hairline `border` token

## Components

In-place evolution under `lib/widgets/mq/` — no `mq2` namespace.

### Refreshed
| component | change |
|---|---|
| `MqSurface` | hairline border + no shadow; shadow path retained for `floating: true` only |
| `MqButton` | primary = filled accent (oxblood/gold) + onTint label; secondary = hairline outline + ink-pri label; destructive = filled `danger` + onTint |
| `MqInput` | underline-only editorial style: no rounded fill; resting = `border`, focused = `accent` thickened to 1.5px; error = `danger` |
| `MqChip` | hairline outline pill; selected = `accentBg` fill + `accent` text |
| `MqMonoCell` | `surface3` bg, syntax via mono→status references |
| `MqSegmented` | hairline outline track + filled accent thumb |
| `MqStatus` | tinted-bg pill using new status tokens |
| `MqEmptyHint` | typographic only — Plex Serif italic line + footnote, no illustration |
| `MqIcons` | mappings switch from `CupertinoIcons.*` to Lucide |
| `InlineToolCard` | header uses Plex Serif + smaller display weight; expand/collapse rebuilt on new motion curves |
| `MqRecentsRow` | hairline divider above + ink-pri item labels + ink-2 timestamps |
| `MqUtilityTile` | flat fill with hairline + accent on press |
| `MqSearchBar` | underline-only treatment matching MqInput |
| `MqSectionHeader` | uppercase `sectionLabel` + ink-2 + optional trailing rule |

### New
| component | role |
|---|---|
| `PageMasthead` | display tier title + Plex Sans tagline + optional rule below; used by Home + tool hero screens |
| `SectionRule` | full-width hairline + optional centered label slot (uppercase sectionLabel style) |
| `ReadingBlock` | paragraph-rhythm container (24px between paragraphs, 40px before headings) |
| `MqWordmark` | "Masquerade" Plex Serif italic, accent ink, sized via display tier |
| `MqMonogram` | Square brackets framing a crossed hammer + quill, oxblood on cream (light) / oxblood on espresso (dark). Renders by loading `assets/brand/monogram-{light,dark}.svg` via `flutter_svg` — SVG is the only source. |

### Icons
- Library: Lucide (OFL, ~1500 line glyphs, 1.5px stroke).
- Adoption path: `MqIcons` constants point to Lucide-rendered widgets via `flutter_lucide` package OR static SVG sprite extracted into `assets/icons/`. Decision deferred to PR1 implementation (impacts pubspec).

## Information architecture

3-tab scaffold unchanged: Home / History / Settings.

### Home (rebuild)
1. `PageMasthead` — wordmark + tagline ("utility toolbox").
2. `SectionRule` (no label).
3. Featured tool card (display tier title + smart-detect preview if clipboard content matches; else rotating tool of the week).
4. `SectionRule` label "Recent".
5. `MqRecentsRow` (existing).
6. `SectionRule` label "All tools".
7. Inline index of all `UtilityCatalog.all`, sectioned by category (Time / Encoding / Numbers / Visual / Finance / Schedule). Each entry = `InlineToolCard` (existing inline expansion preserved).

### History
- Replace ad-hoc dividers with `SectionRule` between days.
- ReadingBlock paragraph rhythm.
- Mono cells use refreshed tokens.

### Settings
- Replace bordered groups with hairline + `SectionRule` sections.
- Add Density segmented control (comfortable / compact).
- Theme toggle restyled via new MqSegmented.
- About section uses `ReadingBlock` + Plex Serif italic for app name.

### qr_scanner_route
- Chrome (close button + nav) restyled to new tokens.
- Camera viewport unchanged.

## Featured tool selection

Algorithm:
1. Read clipboard. Run `UtilityCatalog.detectAll(clipboardText)`.
2. If any tool matches → featured = first match (existing detect priority).
3. Else → featured = `UtilityCatalog.all[(weekOfYear) % all.length]`.

No personalization, no usage tracking. Preserves zero-keystroke "paste anything" superpower already encoded in detect infra.

## Brand mark

Status: replaced 2026-05-11. Earlier spec was a typographic `[ M. ]` mark; the production mark is now a bracketed hammer+quill emblem. Implementation cascade tracked in `docs/launch-metadata.md` §"Update plan".

- **Wordmark.** "Masquerade" Plex Serif italic, display tier, accent color. Used on splash + Settings → About header.
- **Monogram.** Square brackets framing a crossed hammer + quill, oxblood `#8B2635`. Brackets retain the developer cue carried over from the earlier mark; the hammer + quill pair encodes "build" + "write" — the two postures the toolbox supports. Square frame with hairline `borderStrong` outline.
- **Variants.** Two light/dark pairs:
  - `assets/brand/monogram-{light,dark}.svg` — square mark with the hairline frame. Used as the iOS AppIcon + web favicon source.
  - `assets/brand/monogram-{light,dark}-maskable.svg` — same mark with a 10% safe-zone inset and no frame, for PWA maskable icon slots that crop to a circle.
  - `assets/brand/splash-{light,dark}.svg` — splash composition: framed monogram above the wordmark on a flat brand-bg fill.
- **Pipeline.** SVGs are the source of truth. `scripts/build-brand-pngs.sh` rasterizes them to PNGs in `assets/brand/source/` via `rsvg-convert` (requires `brew install librsvg`); the fontconfig temp dir is preserved for the wordmark / splash compositions that still call out IBM Plex faces. The hammer + quill monogram itself is pure shape, no embedded type. Those PNGs feed the launcher and splash plugins:
  - `dart run flutter_launcher_icons` — regenerates `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` (light + dark transparent) + `web/favicon.png` + `web/icons/*`.
  - `dart run flutter_native_splash:create` — regenerates `ios/Runner/Assets.xcassets/LaunchImage.imageset/*`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`, and `web/splash/img/*` (with light/dark `prefers-color-scheme` srcset injected into `web/index.html`).
- **Scope.** iOS + web only (per CLAUDE.md). macOS / Android / Windows / Linux Flutter scaffolds keep stock assets until those platforms ship.
- **Splash motion.** `MqSplashScreen` is a Dart-side composition (`MqMonogram` over `MqWordmark`) that renders over the held native splash; once the engine paints it, `FlutterNativeSplash.remove()` dismisses the native overlay and an `AnimatedSwitcher` crossfades into `RootTabScaffold` after a 350 ms hold + 250 ms fade. Tests bypass this with `MyApp(skipSplash: true)`.

## Tests

Existing tests survive token swap (behavior + WCAG, no goldens, no hex literals in tests).

### Add
- `test/theme/mq_colors_test.dart` — extend with: accent on bg ≥ 4.5 (light + dark), each status token on its tinted bg ≥ 4.5, mono-syntax pairs (string/number/key on monoBg) ≥ 4.5.
- `test/state/density_controller_test.dart` — toggle changes mode, persists to shared_preferences, notifies listeners.
- `test/widgets/mq/page_masthead_test.dart` — renders display tier, optional tagline + rule.
- `test/widgets/mq/section_rule_test.dart` — renders hairline, optional label.

### Skip
- Golden image tests — explicitly out. Maintenance cost outweighs identity-lock value.

## Rollout

### PR1 — `feature/editorial-system` (single change)
1. `pubspec.yaml` — bundle Plex Serif/Sans/Mono assets (latin subset).
2. `pubspec.yaml` — add Lucide icon dependency or vendor SVG sprite.
3. `lib/theme/mq_colors.dart` — rewrite light + dark factories with new tokens; mono fields become references; add WCAG-aware accent + status palette.
4. `lib/theme/mq_typography.dart` — add `display` style; flip families; rename family constants.
5. `lib/theme/mq_metrics.dart` — adjust `MqMotion` (drop spring, adjust durations + curves).
6. `lib/theme/mq_theme.dart` — Cupertino theme builder absorbs new family + colors.
7. `lib/widgets/mq/*.dart` — refresh existing components per table above.
8. `lib/widgets/mq/page_masthead.dart`, `section_rule.dart`, `reading_block.dart`, `mq_wordmark.dart`, `mq_monogram.dart` — new components.
9. `lib/widgets/mq/mq_icons.dart` — re-map all references to Lucide.
10. `lib/state/density_controller.dart` — new ChangeNotifier + persistence.
11. `lib/app.dart` — provide DensityController.
12. `test/theme/mq_colors_test.dart` — extend WCAG.
13. `test/state/density_controller_test.dart`, `test/widgets/mq/page_masthead_test.dart`, `test/widgets/mq/section_rule_test.dart` — new.
14. `flutter analyze` + `dart format` + `flutter test --coverage` clean.

### PR2 — Home rebuild
- `lib/screens/home_screen.dart` — masthead + featured + recents + index using new components.
- `lib/screens/root_tab_scaffold.dart` — chrome tokens.

### PR3 — History + Settings
- `lib/screens/history_screen.dart`, `lib/screens/settings_screen.dart` — SectionRule, ReadingBlock, density toggle wiring.

### PR4..N — Tool bodies
- Each `lib/widgets/tool_bodies/<tool>_body.dart` audited: drop ad-hoc colors/spacing, use refreshed components, ensure mono cells use new syntax tokens.

### PR(last) — Brand mark
- `assets/brand/monogram.svg` — design.
- iOS + macOS AppIcon regenerated.
- `web/favicon.png` + `web/icons/Icon-*.png` regenerated.
- `web/index.html` + `web/manifest.json` color-meta updated to cream `#FAF7F2`.

## Open implementation questions (resolve in PR1)

- Lucide adoption: `flutter_lucide` package vs vendored SVG sprite under `assets/icons/`. Package = ergonomic; sprite = no third-party dep, matches CLAUDE.md "no third-party UI packages" stance. **Default: vendor SVG sprite.**
- Density token application: keep existing `MqSpacing` constants; introduce `context.density` accessor returning `EdgeInsets`/double helpers. Components query helper, not raw constants.
- Plex font subsetting strategy: pre-subset offline (smaller bundle) vs let Flutter handle at build (simpler). **Default: offline subset to latin, ~250KB total.**

## Out of scope

- Reordering tabs, adding Browse tab.
- Per-tool density override.
- Feature-flag dual themes.
- Golden image testing.
- New tools / removing tools.
- Material widgets.
