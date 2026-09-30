# Launch Metadata — App Store, Web, README, Brand Prompts

Status: locked spec, drafted via /grill-me on 2026-05-11. Refreshed 2026-08-18 for the current app (tool set grew 18 → 28, version now tracks `pubspec.yaml` `1.28.x`); positioning anchors in §1 unchanged.
Scope this round: App Store (iOS), web PWA + meta tags, GitHub social card / README hero, brand asset prompts. Play Store metadata deliberately deferred (see §7).

## 1. Positioning anchors (load-bearing for everything below)

| Anchor | Value |
|---|---|
| Tagline | `A quiet toolbox for builders.` (29 chars) |
| Personas | Backend / platform engineers · Frontend / design engineers · Finance / quant |
| Voice | Editorial restraint — book/journal, not dashboard |
| Differentiator | Native Cupertino · offline · no telemetry · no ads · no accounts |

These four lines drive every string and every prompt below. Change one → re-derive everything downstream.

## 2. App Store metadata

```yaml
name:                "Masquerade: A Quiet Toolbox"         # 27/30
subtitle:            "A quiet toolbox for builders."        # 29/30
primary_category:    Utilities
secondary_category:  Developer Tools
age_rating:          4+
keywords:            "json,jwt,cron,uuid,regex,epoch,hex,cidr,diff,hash,yaml,csv,x509,base64,color,qr,bytes,url,env,unicode,toml"   # 99/100
support_url:         https://github.com/howard86/masquerade/issues
marketing_url:       https://github.com/howard86/masquerade
privacy_policy_url:  https://github.com/howard86/masquerade/blob/main/docs/privacy.md
privacy_label:       Data Not Collected
business_model:      Paid (one-time purchase) — no IAP, no subscription, no ads
eula:                Apple standard Licensed Application EULA (no custom EULA)
copyright:           "© 2026 Howardism"
```

App name on store ≠ home-screen name. `CFBundleDisplayName` stays `Masquerade` so the home-screen label does not truncate.

Both `support_url` and `privacy_policy_url` resolve into the public GitHub repo. The live listing therefore depends on that repo staying public — taking it private 404s the privacy policy, which Apple rejects on the next review. If the repo ever goes private, both URLs must be rehosted first.

### Pricing (one-time purchase)

Masquerade sells for a single up-front price. No in-app purchases, so **Guideline 3.1.1 does not apply** and no StoreKit integration ships.

| Item | Value |
|---|---|
| Model | Paid, one-time purchase |
| Price point | **TBD** — pick the tier in ASC → Pricing and Availability |
| Territories | **TBD** — default is all territories |
| Free trial | Not possible. A trial needs IAP; a one-time-purchase app has no trial mechanism. The alternative is the free web build as the try-before-buy surface. |

The source is published under a source-available license (`LICENSE`, proprietary — see §8), not an open-source one. That is deliberate: a permissive license would let anyone compile and republish the paid binary.

**Schedule 2 is the long pole.** Everything else in §8 takes minutes; the Paid Apps Agreement needs bank-account and tax-form verification and takes days. Start it first — until it is active, no price can be set and the app cannot reach *Ready for Sale* no matter how green the build is.

### Promotional text (164/170, editable post-release without re-review)

> A quiet pocket of 28 developer converters and inspectors — JSON, JWT, cron, regex, timestamps, diffs, colors, logs, and certs. Offline. No ads. Zero tracking.

### Description (lead 250 visible without "more")

> Masquerade is a quiet toolbox for builders.
>
> Twenty-eight converters, formatters, and inspectors crafted for the data you carry every day. Fast, copy-friendly, and typeset with editorial restraint in IBM Plex.
>
> CORE TRANSFORMATIONS
> • JSON, YAML & TOML — Pretty-print, minify, browse interactive trees, and convert between structured formats.
> • Timestamps & Epoch — Convert between Unix seconds/milliseconds and ISO 8601 with relative time breakdowns.
> • JWT Decoder — Inspect header, payload, and standard claims with expiration and validity checks.
> • Number Base & Bytes — Move between Hex, Binary, Octal, Decimal, and UTF-8 byte arrays.
> • Base64 & Text Case — Encode, decode (standard & URL-safe), and convert identifiers across camel, snake, kebab, and pascal cases.
> • CSV / TSV — Bidirectional conversion with JSON and bounded table previews.
> • Color & Contrast — Translate HEX, RGB, HSL, and OKLCH with WCAG 2.1 contrast ratio scoring.
> • Basis Points & Math — Basis points (bps) ↔ % ↔ decimal, plus mathematical expression evaluation.
>
> DEEP INSPECTORS & SECURITY
> • Log & Stack Trace Inspector — Group, search, redact, and parse JSON Lines, raw server logs, and stack traces.
> • Environment & Config — Normalize, compare, and redact .env files, properties, and configuration headers.
> • X.509 Certificates — Inspect local PEM/DER certificates, chains, fingerprints, SANs, and public keys without remote requests.
> • Unicode & Strings — Reveal grapheme clusters, code points, UTF-8 bytes, invisible bidi controls, and line endings.
> • Artifact Inspector — Recursively trace nested encodings with bounded previews.
> • HTTP Inspector — Inspect, format, and redact curl commands and raw HTTP request snippets.
>
> GENERATION & VALIDATION
> • UUID & ULID — Generate v4/v7 UUIDs, validate versions/variants, and parse ULIDs.
> • IP & CIDR — IPv4/IPv6 subnetting, host ranges, broadcast addresses, and network scope flags.
> • Regular Expressions — Test Dart regex patterns with real-time match highlighting and capture group inspection.
> • Text Diff — Side-by-side and unified diffs with line- and word-level granularity.
> • Hashes & Checksums — MD5, SHA-1, SHA-256, and SHA-512 with verification mode.
> • QR Codes — Scan with the camera or generate codes locally.
> • Password & Token Generator — Generate cryptographically secure passwords, base64url tokens, and random strings.
> • Markdown — Safe, inert local preview of markdown headings, tables, and lists.
>
> PRIVACY & CRAFTSMANSHIP
> • 100% On-Device — Every calculation runs locally. Nothing is tracked, logged, or sent to any server.
> • No Accounts & No Ads — Opens instantly to your tools without sign-in walls or telemetry.
> • Native Cupertino — Built with native iOS design principles and fluid dark mode support.

### What's New (draft for first public release, version from `pubspec.yaml`)

> First public release. Twenty-eight tools, one quiet desk.

### App Review Notes (For Apple Reviewers)

> • Offline Operation: Masquerade is a 100% offline developer utility. It requires no network access and communicates with no backend services.
> • No Account Required: The app does not feature user registration, logins, or cloud accounts. All features are immediately accessible on launch.
> • Camera Usage: The camera permission (NSCameraUsageDescription) is used solely for the on-device QR Code scanner tool. To test, open the "QR Code" tool and tap "Scan QR Code".
> • Privacy: The app collects zero data ("Data Not Collected").

## 3. Web PWA — `web/manifest.json`

Refines the existing file with `id`, `scope`, `lang`, `categories`, richer description.

```json
{
    "name": "Masquerade: A Quiet Toolbox",
    "short_name": "Masquerade",
    "id": "/",
    "start_url": ".",
    "scope": "/",
    "display": "standalone",
    "orientation": "portrait-primary",
    "background_color": "#FAF7F2",
    "theme_color": "#8B2635",
    "lang": "en",
    "categories": ["utilities", "productivity", "developer"],
    "description": "A quiet toolbox for builders. Convert timestamps, JSON, base64, hex, color, cron, basis points, bytes and QR — on-device, offline, untracked.",
    "prefer_related_applications": false,
    "icons": [
        { "src": "icons/Icon-192.png",          "sizes": "192x192", "type": "image/png" },
        { "src": "icons/Icon-512.png",          "sizes": "512x512", "type": "image/png" },
        { "src": "icons/Icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
        { "src": "icons/Icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
    ]
}
```

## 4. Web meta tags — `web/index.html`

Insert between the existing `<meta name="description">` and `<meta name="mobile-web-app-capable">`. Replaces the current `<meta name="description">` with the refined string.

```html
<meta name="description" content="A quiet toolbox for builders. Convert timestamps, JSON, base64, hex, color, cron, basis points, bytes and QR — on-device, offline, untracked.">

<meta property="og:type"        content="website">
<meta property="og:title"       content="Masquerade: A Quiet Toolbox">
<meta property="og:description" content="A quiet toolbox for builders. On-device, offline, untracked.">
<meta property="og:image"       content="og-banner.png">
<meta property="og:image:width"  content="1200">
<meta property="og:image:height" content="630">

<meta name="twitter:card"        content="summary_large_image">
<meta name="twitter:title"       content="Masquerade: A Quiet Toolbox">
<meta name="twitter:description" content="A quiet toolbox for builders. On-device, offline, untracked.">
<meta name="twitter:image"       content="og-banner.png">

<meta name="theme-color" content="#8B2635" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#14110D" media="(prefers-color-scheme: dark)">
```

## 5. Logo prompt (DALL-E 3 / GPT Image)

Marketing still life of the production hammer+quill monogram. The first generation landed at `assets/marketing/logo-still-1254.jpg` (1254×1254, JPEG q80 — re-encoded from the original PNG to clear the 500 KB pre-commit limit; baked shadow + paper texture). The clean SVG sources for the icon pipeline are authored separately and live in `assets/brand/monogram-{light,dark,light-maskable,dark-maskable}.svg` — DO NOT use this prompt's output as the production icon source (shadow + paper texture conflict with iOS HIG). Use only for marketing surfaces (README hero, OG card, App Store screenshot frames, social posts). Output size: 1024×1024.

```
A square, photorealistic editorial still life on a warm cream paper surface
(#FAF7F2) with subtle paper grain. Centered, debossed and inked in deep
oxblood (#8B2635), is a brand monogram: a pair of upright square brackets
framing a crossed hammer and quill — the hammer behind, oriented from
upper-left to lower-right; the quill in front, oriented from upper-right to
lower-left, its feathered plume rising past the top inside edge of the
right bracket. The mark sits flush with the paper, slightly recessed, with
a faint inner debossed shadow on its lower edge. Soft north-window light
falls from the upper left, casting a long, gentle shadow across the right
side of the frame. Restrained, literary, monastic composition. No
additional text anywhere in the image. No logos other than the bracketed
hammer + quill mark. Shallow depth of field, 50mm lens look, museum-catalog
photography.
```

Iteration notes:
- If the hammer/quill arrangement reverses or the brackets render as parentheses, append: *"the mark reads exactly: open square bracket, crossed hammer behind quill, close square bracket — three elements only, no other glyphs"*.
- DALL-E weakness: deboss + small object detail. Expect 3–5 generations before landing.
- For App Store screenshot frames, prefer this prompt over re-cropping the banner — square aspect carries the mark better than wide.

## 6. Banner prompt (DALL-E 3 / GPT Image)

Native size 1792×1024 (DALL-E landscape). Crop targets:

| Surface | Aspect | Crop strategy |
|---|---|---|
| GitHub social preview card | 1280×640 (2:1) | Center crop |
| Web OG / Twitter card | 1200×630 (1.91:1) | Center crop |
| README hero | full-width (3:1 typical) | Crop top/bottom rows |
| Play feature graphic *(future)* | 1024×500 (~2:1) | Center crop, keep critical content out of outer 200px |

```
A wide, photorealistic editorial flat-lay shot from directly above. The
surface is a sheet of warm cream paper (#FAF7F2) with subtle grain, filling
the frame edge to edge. Slightly left of center, debossed and inked in deep
oxblood (#8B2635), is a brand monogram: a pair of upright square brackets
framing a crossed hammer and quill — hammer behind, quill in front, their
shafts crossing at roughly the bracket midline; the quill's plume rises
past the upper inside edge of the right bracket. Around the mark, a quiet
still life of a working desk: a vintage brass fountain pen, a thin brass
ruler, and four or five narrow strips of cream paper bearing short
typewritten ink fragments — for example "{ }", "0xFF", "42 bps", "*/5 *",
"#8B2635" — scattered naturally, some overlapping, none in the right third
of the frame. The right third of the frame is intentionally clean, empty
paper, reserved as negative space. Soft north-window light from the upper
left, gentle long shadows. Subtle paper grain. Restrained, literary,
monastic composition, museum-catalog photography. No headlines, no body
copy, no product names anywhere in the image except the small typographic
fragments noted on the paper strips and the bracketed hammer + quill mark.
```

Iteration notes:
- DALL-E will fight on the typographic fragments. If they render as gibberish, drop the strips on the second pass and lean on the tag + pen + ruler.
- The `clean right third` instruction is load-bearing for the post-overlay step. If the generator ignores it, request again with: *"the right 33% of the canvas must be uninterrupted cream paper, no objects, no marks"*.
- After landing, overlay tagline `A quiet toolbox for builders.` in IBM Plex Serif Italic 600, ~64pt at 1792 width, color `#1B1813`, baseline at vertical center of the right third.

## 7. README hero (post-overlay layout)

```
┌──────────────────────────────────────────────────────────────────┐
│  [generated banner image, 2:1 crop]                              │
│                                                                  │
│   [ ⚒✒ ]                          A quiet toolbox                │
│     mark                          for builders.                  │
│                                                                  │
│                                   ─────                          │
│                                   Masquerade · iOS · web         │
└──────────────────────────────────────────────────────────────────┘
```

```markdown
# Masquerade

> A quiet toolbox for builders.

Convert timestamps, JSON, base64, hex, color, cron, basis points, bytes,
and QR — on-device, offline, untracked. Cupertino. IBM Plex.

[App Store badge] [Web app link]
```

## 8. Open issues / pre-submission checklist

Statuses verified 2026-07-16; licensing + paid-app rows added 2026-07-17.

Repo state:

- [x] `LICENSE` — proprietary source-available (2026-07-17). The repo is public and had no license at all, which defaults to all-rights-reserved: adequate for the paid model by accident, but it left README's Contributing section soliciting PRs with no stated terms. Permissive licensing was rejected — it would let anyone compile and republish the paid binary. Confirm the copyright holder name matches the ASC → App Information → Copyright field exactly.
- [x] IBM Plex OFL-1.1 notice bundled (`assets/fonts/OFL.txt`, listed under `flutter.assets` 2026-07-17). The fonts shipped in the IPA with no license text anywhere in the repo — an OFL violation, which requires the notice to travel with the font in every copy. Apple does not check this; the Paid Apps Agreement still makes you warrant you hold the rights. `flutter_lucide` and the pub packages carry their own `LICENSE` files and are collected automatically by Flutter's `LicenseRegistry`.
- [x] `docs/privacy.md` exists. Confirm the URL returns 200 for reviewers (repo must be public) — App Store rejects otherwise.
- [x] `web/favicon.png` regenerated as the monogram (no longer the 343 B Flutter default).
- [x] Web manifest + OG/Twitter meta tags applied per §3/§4.
- [x] iOS app icons generated (`flutter_launcher_icons`, light + dark).
- [x] `NSCameraUsageDescription` set in `Info.plist` (QR scanner).
- [x] Bundle ID `dev.howardism.Masquerade` (fixed 2026-07-16 — Runner shipped the template's `com.example.howardism` until then; App Store rejects `com.example`); home-screen `CFBundleDisplayName` stays `Masquerade`.
- [x] `pubspec.yaml` `flutter_launcher_icons.android` left disabled — Android shipping deferred. Re-open with Play Store metadata + adaptive icon source when revisited.
- [x] ~~Blocker: stray Xcode-generated "Masquerade" SwiftUI target + broken `Debug.xcconfig` include~~ — resolved 2026-07-16: template target removed, `Debug.xcconfig` and `project.pbxproj` restored, bundle-ID fix re-applied surgically.
- [x] Release archive verified 2026-07-16: `flutter build ipa --release` exports an App Store IPA signed `Apple Distribution` (team `9KRJ83FMAF`) with an App Store provisioning profile (`get-task-allow` false); Flutter app-settings validation green (1.25.2 build 3, Masquerade, `dev.howardism.Masquerade`).
- [x] iPhone-only: `TARGETED_DEVICE_FAMILY = 1` in all three build configs (2026-07-16). iPad was the Flutter template default and was never designed for — see `docs/adr/0003`. Keeps the 13″ iPad screenshot set off the submission.
- [ ] `web/og-banner.png` (1200×630 center crop of generated banner) committed.
- [x] **Privacy policy reachable inside the app.** Satisfies Guideline 5.1.1(i) via `SettingsScreen` → `PrivacyPolicyScreen` reading `docs/privacy.md` on-device without remote calls.
- [x] **Acknowledgements screen.** Satisfies open-source and font licensing via `SettingsScreen` → `AcknowledgementsScreen` rendering licenses registered with Flutter's `LicenseRegistry` (including bundled `assets/fonts/OFL.txt`).

Privacy manifests: no app-level `PrivacyInfo.xcprivacy` is needed — the Dart app code uses no required-reason APIs directly; the Flutter engine and plugin pods (`shared_preferences` etc.) ship their own manifests, and the app collects nothing (`Data Not Collected`).

Submission (App Store Connect):

- [ ] **Paid Apps Agreement (Schedule 2) active** — ASC → Business. Requires a bank account and tax forms (W-9 / W-8BEN as applicable). **Start this first:** it is the only item here measured in days rather than minutes, and until it is active no price can be set and the app cannot go *Ready for Sale*.
- [ ] Price point + territory availability set (ASC → Pricing and Availability). See §2.
- [ ] Create the app record; enter §2 name/subtitle/keywords/categories/URLs/copyright there (not in `Info.plist`).
- [ ] Privacy label: Data Not Collected.
- [ ] Screenshots — 6.9″ (1320×2868 / 1290×2796) and 6.5″ (1284×2778 / 1242×2688) iPhone sets. No iPad set required (`TARGETED_DEVICE_FAMILY = 1`). Run `scripts/capture-store-screenshots.sh` to capture and crop.
- [ ] Copyright field (ASC → App Information) — required (`© 2026 Howardism`), blocks "Add for Review" with no obvious pointer to it.
- [ ] App Privacy section completed (Data Not Collected) — Admin-only, also blocks "Add for Review".
- [x] Export compliance: `ITSAppUsesNonExemptEncryption = false` set in `Info.plist` (2026-07-17). The app only hashes (`crypto` — MD5/SHA), which is exempt. Pre-empting this in the plist is now load-bearing rather than cosmetic: with TestFlight uploads automated on every green `main`, a missing key parks each build in *Missing Compliance* until someone answers the questionnaire by hand, which defeats the point of the pipeline.
- [ ] Upload the verified IPA (`build/ios/ipa/masquerade.ipa`) via Transporter, or `xcrun altool --upload-app --type ios -f build/ios/ipa/masquerade.ipa --apiKey … --apiIssuer …` — no ASC API key is stored on this machine.
- [ ] TestFlight pass on a physical device (camera/QR path needs real hardware).
- [ ] Submit for review with the §2 description + promotional text, What's New line, and reviewer notes.

### Gotchas (learned the hard way, 2026-07-16 submission)

Every one of these cost a round-trip. Read before the next release.

- **`flutter build ipa` exits 0 when the export fails.** It only means the `.xcarchive` built. The export step logs `No signing certificate 'iOS Distribution' found` and gives up — this machine's keychain has only an Apple *Development* identity. Never infer success from the exit code; confirm `build/ios/ipa/*.ipa` exists and its mtime is *this* build. Export the archive from Xcode (Organizer → Distribute) when the CLI can't sign.
- **A stale IPA is the real hazard of that.** When export fails, the *previous* IPA sits at the canonical path looking valid, and Transporter will happily upload it. That is how a build-1, iPad-enabled binary nearly shipped after the iPhone-only fix. Delete or rename the old IPA *before* rebuilding, not after.
- **Xcode's "Manage Version and Build Number" silently bumps `CFBundleVersion` on export.** The uploaded build was 3 while `pubspec.yaml` said 1. ASC then rejects the next upload with *"build must be higher than previously uploaded version '3'"*. After any Xcode-driven export, read the built `Info.plist` and sync `pubspec.yaml` to whatever actually shipped.
- **Verify the device family in the archive, not the diff.** `TARGETED_DEVICE_FAMILY` lives in three separate configs in `project.pbxproj` (Debug/Release/Profile) and it is easy to change one. Ground truth is `UIDeviceFamily` in `Runner.xcarchive/Products/Applications/Runner.app/Info.plist` — `Array { 1 }` means iPhone-only landed.
- **Simulator screenshots are not App Store dimensions.** The iPhone 17 Pro Max simulator captures 1320×2868; ASC's 6.5″ slot accepts 1284×2778. Resample width, then center-crop height (`sips -z` then `sips -c`). Check the accepted list per slot before capturing a whole set.
- **"Add for Review" blockers are metadata, not binary.** Copyright and App Privacy are both required and neither is surfaced on the build page. Fill them before uploading, or the green build sits unsubmittable.

## 9. Decisions deferred / out of scope

- Play Store listing copy (title, short description, full description, content rating). Banner is composed wide enough to crop a 1024×500 feature graphic if Android revisits.
- Localized App Store metadata (en-US only this round).
- App preview video. Static screenshots only for v1.7.0 submission.
- Wordmark / lockup variants of the monogram (only the bracketed mark is in scope).
