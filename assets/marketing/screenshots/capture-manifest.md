# iPhone App Store screenshot capture

Captured 2026-10-27 from the released v1.29.0 source. The PNG masters and 6.3-inch JPEG candidates are genuine simulator captures; they are not browser renderings or composed app screens.

## Source and simulator

- Source tag: `v1.29.0`
- Source commit: `04241d32dbe074ec0aae119b754173e91e38670b`
- App version / bundle ID: `1.29.0` / `dev.howardism.Masquerade`
- Simulator: iPhone 17 Pro, iOS 26.4, Xcode 27.0
- Simulator UDID: `FD11B806-3298-4035-A1CB-0F24F5B179D4`
- App Store slot: 6.3-inch Dynamic Island, portrait 1206×2622
- Capture time: 2026-10-27, approximately 06:45–06:46 UTC
- Method: a temporary `integration_test` harness launched the release source and navigated the actual app; `xcrun simctl io screenshot --mask=black` captured the stable full-device frames at named screen markers. `simctl status_bar override` set the native status bar to 9:41 with charged battery and signal indicators. No UI or status bar pixels were fabricated or pasted in.

## Build provenance

The app source and UI came from the v1.29.0 commit above. The Simulator build was a local capture build, not a byte-identical copy of the published release binary. Xcode 27 rejected the source's iOS 13 target and older Pods targets, so the isolated capture worktree temporarily raised Runner and every Pods target to iOS 15. The Flutter 3.41.8 simulator packaging path also required an arm64-only simulator architecture setting.

The temporary capture harness added Flutter's `integration_test` SDK dependency and resolved a task-local lockfile. That resolution changed some test/tool transitive packages and `vector_math` relative to the source lockfile. The harness selected the app's Light appearance, supplied only synthetic examples, enabled the native system overlays, and did not change app source screens or permission behavior. These build and harness adjustments were confined to the capture worktree; they are not changes to the PR app source.

## Screens

| File stem | Scene | Synthetic content |
| --- | --- | --- |
| `01_home_desk` | Workbench | Completed deployment event JSON and JSON tool suggestion |
| `02_json_formatter` | JSON formatter | Pretty-printed deployment event |
| `03_timestamp_epoch` | Timestamp | UTC ISO 8601 input with UTC, local, Unix, and ISO outputs |
| `04_jwt_inspector` | JWT inspector | Synthetic reader token; visible decode-only/signature-not-verified disclaimer |
| `05_color_contrast` | Color | `#2B59C3` conversions and WCAG contrast results |
| `06_regex_tester` | Regex | API route pattern with two matching sample lines |
| `07_privacy_settings` | Settings | On-device privacy, retention, and app version 1.29.0 |

## Files and validation

- `raw/*.png`: native 1206×2622 PNG masters, no alpha channel.
- `6.3-inch/*.jpg`: quality-100 JPEG candidates, 1206×2622, no alpha channel.
- The helper skipped optional 6.9-inch and 6.5-inch outputs because these masters do not contain enough pixels for those slots. It did not upscale or stretch the captures.
- `historical/v1.28.0/{raw,6.9-inch,6.5-inch}/`: the previous screenshots, kept unchanged with their original paths under a versioned archive.
- `scripts/test-capture-store-screenshots.sh`: passed profile-size, format/alpha, and no-overwrite checks.
- `scripts/capture-store-screenshots.sh`: prepared all seven required 6.3-inch JPEGs and skipped undersized optional profiles.
- `sips` inspection confirmed all 14 delivered PNG/JPEG files have the expected format, 1206×2622 dimensions, and `hasAlpha: no`.

The owner must still select the matching 6.3-inch App Store Connect slot and complete App Store metadata, privacy, age-rating, export-compliance, pricing, and review decisions. These captures alone do not establish App Store readiness.
