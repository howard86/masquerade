---
status: superseded
superseded-by: 0004
---

# iOS ships iPhone-only (`TARGETED_DEVICE_FAMILY = 1`)

The iOS target drops iPad. `TARGETED_DEVICE_FAMILY` is `1` (iPhone) across all three build configs in `ios/Runner.xcodeproj/project.pbxproj` — Debug, Release, and Profile. The Flutter project still builds for every other platform; this ADR constrains the App Store binary only.

## Context

Runner shipped the Flutter template default `"1,2"` (iPhone + iPad) — never a deliberate choice, and never designed for. There are exactly two shells (`lib/utils/shell_layout.dart`):

- `desktop` — gated on `isWeb && width >= 900 && viewMode == desktop`. Web-only by construction, per **ADR-0002**.
- `framedMobile` / `bareMobile` — the mobile UI, framed inside the hand-drawn iPhone silhouette (`lib/widgets/iphone_frame.dart`) once the viewport exceeds ~493×1052.

An iPad is native, so it can never reach `desktop`; it is large, so it always lands in `framedMobile`. The shipped result was the mobile UI letterboxed inside a *fake drawn iPhone bezel* on a real 13″ iPad — which reads as a bug, not a design, and violates App Store Guideline 2.4.1 (make full use of the screen).

Enabling iPad in the manifest also forces its own submission cost: App Store Connect requires a 13″ iPad screenshot set for any iPad-enabled binary.

## Considered options

1. **Guard `framedMobile` on `isWeb`** — one-line change; iPad falls to `bareMobile` and renders full-screen. Rejected: it ships a stretched phone UI on a 13″ canvas, which is still Guideline 2.4.1 exposure, and it breaks the framed *web* preview that the guard's absence exists to serve.
2. **Build a real iPad layout** — a third shell, or let iPad reach the desktop OS natively. Correct eventually, but it is a feature, not a submission fix, and ADR-0002's desktop is built around a pointer + menubar metaphor that needs its own design pass for touch.
3. **Drop iPad** (chosen) — declare what the app actually supports. Zero code change, zero UI risk, and it removes the iPad screenshot requirement from the submission.

## Consequences

- iPad users get the iPhone build in compatibility mode — Apple's own scaler, not our fake bezel. This is the honest presentation of a phone app.
- **The missing `isWeb` guard in `framedMobile` is deliberate, not a bug.** It is what lets a wide *browser* window preview the mobile UI inside the silhouette. Do not "fix" it.
- Re-enabling iPad is a design decision, not a manifest edit. It means picking option 2 above and shipping a real layout first — otherwise the bezel bug returns silently.
- No Dart changed, so no test moved. `flutter test` (904 passing) and `flutter analyze` are unaffected; the device family is verifiable only in a built archive (`UIDeviceFamily` in the archived `Info.plist`).
