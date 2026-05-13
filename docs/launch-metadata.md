# Launch Metadata — App Store, Web, README, Brand Prompts

Status: locked spec, drafted via /grill-me on 2026-05-11.
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
name:                "Masquerade: A Quiet Toolbox"        # 27/30
subtitle:            "A quiet toolbox for builders."       # 29/30
primary_category:    Utilities
secondary_category:  Developer Tools
age_rating:          4+
keywords:            "json,base64,cron,hex,binary,encode,decode,timestamp,epoch,bps,color,oklch,wcag,qr,scanner,bytes,utf8"   # 100/100
support_url:         https://github.com/howard86/masquerade/issues
marketing_url:       https://github.com/howard86/masquerade
privacy_policy_url:  https://github.com/howard86/masquerade/blob/main/docs/privacy.md
privacy_label:       Data Not Collected
```

App name on store ≠ home-screen name. `CFBundleDisplayName` stays `Masquerade` so the home-screen label does not truncate.

### Promotional text (170/170, editable post-release without re-review)

> A pocket of conversions for the data you carry — timestamps, JSON, color, base64, cron, basis points, bytes, QR. Offline. No tracking. No noise.

### Description (~360 chars, lead 250 visible without "more")

> Masquerade is a quiet toolbox for builders.
>
> Convert timestamps between epoch and ISO. Reformat JSON. Decode base64. Read cron schedules in plain English. Move between hex, binary, decimal, and bytes. Translate colors across HEX, RGB, HSL, and OKLCH with WCAG contrast. Convert basis points to percent and back. Scan or generate QR.
>
> Everything runs on-device. Nothing is collected, tracked, or sent anywhere. No accounts. No ads. No telemetry.
>
> Built with Cupertino. Typeset in IBM Plex.

### What's New (draft for v1.7.0)

> First public release. Nine tools, one quiet desk.

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

- [ ] `docs/privacy.md` exists and the URL returns 200 — App Store rejects otherwise.
- [ ] `web/favicon.png` (currently the default Flutter favicon, 343 B) regenerated as a 32×32 monogram crop from `assets/brand/source/monogram-light-1024.png`.
- [ ] `web/og-banner.png` (1200×630 center crop of generated banner) committed.
- [ ] `pubspec.yaml` `flutter_launcher_icons.android` left disabled — Android shipping deferred. Re-open with Play Store metadata + adaptive icon source when revisited.
- [ ] App Store name string entered in App Store Connect, not in `Info.plist`. Home-screen `CFBundleDisplayName` stays `Masquerade`.

## 9. Decisions deferred / out of scope

- Play Store listing copy (title, short description, full description, content rating). Banner is composed wide enough to crop a 1024×500 feature graphic if Android revisits.
- Localized App Store metadata (en-US only this round).
- App preview video. Static screenshots only for v1.7.0 submission.
- Wordmark / lockup variants of the monogram (only the bracketed mark is in scope).
