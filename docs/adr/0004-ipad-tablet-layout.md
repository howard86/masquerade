---
status: accepted
supersedes: 0003
---

# iPad gets a real split-view tablet layout (Dart-only; App Store enablement deferred)

Masquerade now has a fourth shell — `MqShellLayout.tablet` — and a native, touch-first split-view `TabletShell` (sidebar nav + detail pane, the HIG idiom used by Settings / Files / Mail). This closes the gap that **ADR-0003** named: a native large screen (an iPad) can never reach the web-only `desktop` shell and, being large, always fell to `framedMobile` — the phone UI letterboxed inside a *fake drawn iPhone bezel* on a real 13″ iPad. That reads as a bug and is exactly the Guideline 2.4.1 exposure ADR-0003 avoided by dropping iPad from the binary.

This pass is **Dart-only**. It ships the layout, resolver, tests, and this ADR. It does **not** flip the iOS manifest — `TARGETED_DEVICE_FAMILY` stays `1` (iPhone-only) — so nothing reaches iPad until the layout is verified on real hardware in a later release PR.

## Context

The shell classifier (`lib/utils/shell_layout.dart`) resolved to three presentations: `bareMobile`, `framedMobile` (mobile UI inside the hand-drawn iPhone silhouette), and `desktop` (web-only macOS shell, per ADR-0002). PRODUCT.md's platform is **adaptive** and its "native on every surface" principle names closing this gap as real design work, not a manifest flag.

## Decision

- **Resolver.** Add `MqShellLayout.tablet` and, after the web-desktop check, a native + tablet-sized branch:
  `if (!isWeb && width >= tabletBreakpoint && height >= tabletBreakpoint) return tablet;` (`tabletBreakpoint = 600` logical px). Gating on **both** dimensions separates a real tablet (iPad shortest side ≥744 logical) from a phone in landscape (shortest side ≤440) and from an iPad Split-View slim window (width ~320–507) — those fall through to the existing phone presentation. The `framedMobile` / `bareMobile` fallbacks are unchanged, so **web and phones are untouched**.
- **`!isWeb` gate is deliberate.** A wide *browser* window previewing the mobile UI inside the silhouette (ADR-0003's intentionally-missing `isWeb` guard on `framedMobile`) is preserved — `tablet` never triggers on web, so the preview path is intact.
- **Shared tool host.** The tool body + session + pinned action-bar wiring was extracted from `ToolDetailRoute` into `lib/widgets/tool_host.dart` (`ToolHost`), so the phone route and the tablet detail pane render the identical pipeline. `ToolDetailRoute` is unchanged behaviorally.
- **`TabletShell`.** A two-pane `Row`: a hairline-bordered sidebar (search + the catalog grouped by `UtilityCategory` + Library / Activity / Settings destinations, selected row in the One-Voice accent) beside a detail pane that hosts the current selection — `ToolHost` (constrained to a readable width and centered), the existing `LibraryScreen` / `HistoryScreen` / `SettingsScreen`, or a first-run browse grid. Orientation is handled by size classes (a slightly narrower sidebar in portrait), not device checks; safe areas are respected throughout.

## Consequences

- An iPad-native experience exists in code and is fully testable (resolver unit tests + a `TabletShell` widget test at an iPad surface size).
- **App Store enablement remains a deferred release step**, not part of this change: flipping `TARGETED_DEVICE_FAMILY` to `1,2` in `ios/Runner.xcodeproj/project.pbxproj` and adding the required 13″ iPad screenshot set to App Store Connect (`docs/launch-metadata.md`). Until then, iPad users still get the iPhone build in Apple's compatibility mode — no fake bezel ships.
- ADR-0003's core reasoning still holds until that follow-up lands; it is marked superseded-by-0004 because the "re-enabling iPad means shipping a real layout first" condition it set is now met in Dart.
