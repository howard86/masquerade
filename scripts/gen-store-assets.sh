#!/usr/bin/env bash
# Regenerate the brand / store raster assets from the canonical SVG sources.
#
# Deterministic by default (rsvg-convert + ImageMagick + the existing Flutter
# icon/splash generators). The image-gen CLI (agy-image) is used ONLY for
# editorial photography — the App Store feature graphic and screenshot
# backdrops — and only when GEN_PHOTOS=1.
#
# Coherence comes from three things: (1) one SVG source of truth, rasterized
# everywhere; (2) every generative prompt shares the same style SPINE + NEGATIVE
# clause — that shared style spine, not a per-image reference, is what keeps the
# set coherent; and (3) text is NEVER generated — it is composited afterward with
# the bundled Plex fonts, so type stays crisp and identical across every asset.
#
# Usage:
#   ./scripts/gen-store-assets.sh              # deterministic assets only
#   GEN_PHOTOS=1 ./scripts/gen-store-assets.sh # + agy-image editorial photos
#
# Deps: rsvg-convert (brew install librsvg), ImageMagick 7 (brew install
# imagemagick), Flutter. For GEN_PHOTOS: agy-image on PATH (or set AGY_IMAGE).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/assets/brand"
FONTS="$ROOT/assets/fonts"
WEB="$ROOT/web"
STORE="$ROOT/store"                 # committed store assets — NOT build/ (gitignored)
mkdir -p "$STORE"

# --- brand tokens (mirror lib/theme/mq_colors.dart) -------------------------
CREAM="#FAF7F2"; OXBLOOD="#8B2635"
SERIF_IT="$FONTS/IBMPlexSerif-Italic.ttf"   # magick reads the TTF path directly

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }; }
need rsvg-convert; need magick

echo "==> 1/7  canonical SVG -> 1024 PNG sources"
"$ROOT/scripts/build-brand-pngs.sh"

echo "==> 2/7  iOS + web icon/splash fan-out (existing generators)"
if command -v flutter >/dev/null 2>&1; then
  ( cd "$ROOT" && flutter pub get >/dev/null \
      && dart run flutter_launcher_icons \
      && dart run flutter_native_splash:create )
else
  echo "    flutter not found — skipping icon/splash regen (SVGs + sources still updated)" >&2
fi

# Runs AFTER the generators: flutter_launcher_icons copies the plain icon into
# the maskable slots (no safe-zone), so render the real maskable source over it.
echo "==> 3/7  real maskable web icons (fixes the byte-identical duplicates)"
for px in 192 512; do
  rsvg-convert -w "$px" -h "$px" "$SRC/monogram-light-maskable.svg" \
    -o "$WEB/icons/Icon-maskable-$px.png"
done

echo "==> 4/7  favicon that survives 16px (bracket mark)"
rsvg-convert -w 32 -h 32 "$SRC/favicon.svg" -o "$WEB/favicon.png"

echo "==> 5/7  macOS app icons (native floating rounded tile, all sizes)"
# flutter_launcher_icons is not configured for macOS (not a shipping target), so
# the appiconset shipped the stock Flutter logo. Render the brand tile at each size.
MACOS_SET="$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
for px in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$px" -h "$px" "$SRC/macos-icon-light.svg" \
    -o "$MACOS_SET/app_icon_$px.png"
done

echo "==> 6/7  og-banner 1200x630 (typographic — on-brand, no generation needed)"
# Borderless maskable source (no hairline box) so the mark floats cleanly.
magick -size 1200x630 "xc:$CREAM" \
  \( "$SRC/source/monogram-light-maskable-1024.png" -resize 360x360 \) \
    -gravity center -geometry +0-40 -composite \
  -font "$SERIF_IT" -pointsize 72 -fill "$OXBLOOD" \
    -gravity center -annotate +0+150 "Masquerade" \
  "$WEB/og-banner.png"

# --- optional: editorial photography via agy-image --------------------------
# One style SPINE + NEGATIVE clause stays constant across the whole
# batch; only the per-asset SCENE varies. That constancy is what keeps a set
# coherent, and the photographic specificity is what lifts quality out of the
# generic "AI-cream" look. Text is never generated — composited afterward.
SPINE="Editorial still-life photograph, styled like a museum collection catalog or a fine \
letterpress monograph. Ground: matte, uncoated warm cream paper, color #FAF7F2, faint paper \
tooth and a soft deckled edge. Subjects rendered in deep oxblood red #8B2635 and aged, \
unpolished brass, with ink-brown #1B1813 shadow detail. Lighting: a single soft north-facing \
window from the upper-left, gentle raking light, one long quiet shadow, no specular hotspots. \
Camera: 100mm macro, medium-format film rendering with muted Portra-like tones, shallow depth \
of field, fine natural grain, true-to-life texture. Mood: restrained, literary, precise, \
monastic. Strictly limited palette: cream, oxblood, aged brass, ink-brown. Impeccable \
composition with generous, deliberate negative space."
NEGATIVE="Exclude: any text, letters, numbers, logos or watermarks; any screens, phones, \
devices or user interface; gradients, glassmorphism, neon, glossy plastic, HDR, isometric 3D, \
sticker drop-shadows or mockups; people, hands, faces; saturated or off-palette colors. A real \
photograph, not a digital illustration."
# Default to the committed wrapper; override AGY_IMAGE to point elsewhere.
AGY_IMAGE="${AGY_IMAGE:-$ROOT/scripts/agy_image.py}"

# imagegen <scene> <width> <height> <outfile.jpg>  — SPINE + scene + NEGATIVE.
# No --ref: the wrapper's reference block is face-preservation framing meant for
# character portraits, which is wrong for still-lifes. The shared SPINE carries
# coherence; --crop enforces the exact pixel size afterward. agy emits PNG; we
# transcode to JPEG q82 so these multi-megapixel photos clear the 500 KB
# check-added-large-files guard (repo convention: photos are JPEG, marks are SVG/PNG).
imagegen() {
  local scene="$1" w="$2" h="$3" out="$4" tmp="${4%.jpg}.png"
  "$AGY_IMAGE" --prompt "$SPINE  $scene  $NEGATIVE" \
    --width "$w" --height "$h" --out "$tmp" --crop --quiet
  magick "$tmp" -quality 82 -strip "$out" && rm -f "$tmp"
}

if [[ "${GEN_PHOTOS:-0}" == "1" ]]; then
  need "$AGY_IMAGE"
  echo "==> 7/7  editorial photography (agy-image)"

  # Brand hero / realistic logo (square) — the mark letterpressed into paper.
  imagegen "A single sheet of thick cream cotton rag paper, photographed close and \
straight-on. Pressed deep into the paper letterpress-style is the Masquerade mark: two tall, \
upright square brackets [ ] framing a crossed carpenter's hammer and a feather writing quill \
forming an X at their centre, all inked in deep oxblood. The deboss impression catches the \
raking window light along one edge so the mark reads three-dimensional, tactile, hand-pressed. \
The mark is centred with generous, even breathing room on all four sides." \
    2048 2048 "$STORE/brand-hero.jpg"

  # App Store feature graphic — generate the scene, composite the wordmark crisply after.
  # q92 + 4:4:4 sampling keeps the oxblood serif type sharp against cream (no chroma fringing).
  imagegen "Overhead flat-lay on cream paper: aged brass calipers, a slim oxblood fountain pen, \
a folded architect's blueprint in muted oxblood, and two small letterpress type slugs, arranged \
loosely. Objects clustered left; the right third is empty cream paper." \
    2400 1260 "$STORE/feature-bg.jpg"
  magick "$STORE/feature-bg.jpg" \
    -font "$SERIF_IT" -pointsize 132 -fill "$OXBLOOD" \
      -gravity east -annotate +200+0 "Masquerade" \
    -quality 92 -sampling-factor 4:4:4 -strip \
    "$STORE/appstore-feature.jpg"

  # Screenshot scene backdrop (portrait) — frame real captures over this later.
  imagegen "One oxblood fountain pen resting diagonally beside a faint brass ruler, in the lower \
third; the upper two-thirds is empty, softly lit cream paper." \
    1290 2796 "$STORE/screenshot-bg.jpg"

  # Social / OG hero backdrop (landscape).
  imagegen "A brass magnifier loupe on cream paper next to a small oxblood wax seal, right of \
center; the left third is empty cream paper." \
    1200 630 "$STORE/og-hero.jpg"
else
  echo "==> 7/7  editorial photography — skipped (set GEN_PHOTOS=1 to run agy-image)"
fi

echo "done. Review the diff under web/, store/, ios/, macos/, and assets/brand/source/."
