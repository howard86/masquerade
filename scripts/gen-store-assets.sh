#!/usr/bin/env bash
# Regenerate the brand / store raster assets from the canonical SVG sources.
#
# Deterministic by default (rsvg-convert + ImageMagick + the existing Flutter
# icon/splash generators). The image-gen CLI (agy-image) is used ONLY for
# editorial photography — the App Store feature graphic and screenshot
# backdrops — and only when GEN_PHOTOS=1.
#
# Coherence comes from three things: (1) one SVG source of truth, rasterized
# everywhere; (2) every generative prompt shares BRAND_PREAMBLE + is anchored to
# the existing marketing still-life via agy-image --ref/--subject-anchor; and
# (3) text is NEVER generated — it is composited afterward with the bundled Plex
# fonts, so type stays crisp and identical across every asset.
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
REF_STILL="$ROOT/assets/marketing/logo-still-1254.jpg"  # coherence reference

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }; }
need rsvg-convert; need magick

echo "==> 1/6  canonical SVG -> 1024 PNG sources"
"$ROOT/scripts/build-brand-pngs.sh"

echo "==> 2/6  iOS + web icon/splash fan-out (existing generators)"
if command -v flutter >/dev/null 2>&1; then
  ( cd "$ROOT" && flutter pub get >/dev/null \
      && dart run flutter_launcher_icons \
      && dart run flutter_native_splash:create )
else
  echo "    flutter not found — skipping icon/splash regen (SVGs + sources still updated)" >&2
fi

# Runs AFTER the generators: flutter_launcher_icons copies the plain icon into
# the maskable slots (no safe-zone), so render the real maskable source over it.
echo "==> 3/6  real maskable web icons (fixes the byte-identical duplicates)"
for px in 192 512; do
  rsvg-convert -w "$px" -h "$px" "$SRC/monogram-light-maskable.svg" \
    -o "$WEB/icons/Icon-maskable-$px.png"
done

echo "==> 4/6  favicon that survives 16px (bracket mark)"
rsvg-convert -w 32 -h 32 "$SRC/favicon.svg" -o "$WEB/favicon.png"

echo "==> 5/6  og-banner 1200x630 (typographic — on-brand, no generation needed)"
# Borderless maskable source (no hairline box) so the mark floats cleanly.
magick -size 1200x630 "xc:$CREAM" \
  \( "$SRC/source/monogram-light-maskable-1024.png" -resize 360x360 \) \
    -gravity center -geometry +0-40 -composite \
  -font "$SERIF_IT" -pointsize 72 -fill "$OXBLOOD" \
    -gravity center -annotate +0+150 "Masquerade" \
  "$WEB/og-banner.png"

# --- optional: editorial photography via agy-image --------------------------
# One style SPINE + ANCHOR + NEGATIVE clause stay constant across the whole
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
ANCHOR="Masquerade editorial still-life: oxblood and brass instruments on warm cream paper, \
north-window light, museum-catalog photography"
AGY_IMAGE="${AGY_IMAGE:-agy-image}"   # path to agy_image.py, or the installed binary

# imagegen <scene> <width> <height> <outfile>  — SPINE + scene + NEGATIVE
imagegen() {
  local scene="$1" w="$2" h="$3" out="$4"
  "$AGY_IMAGE" --prompt "$SPINE  $scene  $NEGATIVE" \
    --width "$w" --height "$h" --out "$out" \
    --ref "$REF_STILL" --subject-anchor "$ANCHOR" --crop --quiet
}

if [[ "${GEN_PHOTOS:-0}" == "1" ]]; then
  need "$AGY_IMAGE"
  echo "==> 6/6  editorial photography (agy-image)"

  # Brand hero / press (square) — the mark debossed into paper.
  imagegen "A single sheet of thick cream cotton paper, close up; pressed into it \
letterpress-style, two upright square brackets framing a crossed hammer and feather quill, \
inked oxblood, the impression catching raking light along one edge. Centered, breathing room \
on all sides." \
    2048 2048 "$STORE/brand-hero.png"

  # App Store feature graphic — generate the scene, composite the wordmark crisply after.
  imagegen "Overhead flat-lay on cream paper: aged brass calipers, a slim oxblood fountain pen, \
a folded architect's blueprint in muted oxblood, and two small letterpress type slugs, arranged \
loosely. Objects clustered left; the right third is empty cream paper." \
    2400 1260 "$STORE/feature-bg.png"
  magick "$STORE/feature-bg.png" \
    -font "$SERIF_IT" -pointsize 132 -fill "$OXBLOOD" \
      -gravity east -annotate +200+0 "Masquerade" \
    "$STORE/appstore-feature.png"

  # Screenshot scene backdrop (portrait) — frame real captures over this later.
  imagegen "One oxblood fountain pen resting diagonally beside a faint brass ruler, in the lower \
third; the upper two-thirds is empty, softly lit cream paper." \
    1290 2796 "$STORE/screenshot-bg.png"

  # Social / OG hero backdrop (landscape).
  imagegen "A brass magnifier loupe on cream paper next to a small oxblood wax seal, right of \
center; the left third is empty cream paper." \
    1200 630 "$STORE/og-hero.png"
else
  echo "==> 6/6  editorial photography — skipped (set GEN_PHOTOS=1 to run agy-image)"
fi

echo "done. Review the diff under web/, store/, ios/, and assets/brand/source/."
