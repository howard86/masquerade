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
BRAND_PREAMBLE="Editorial still-life photograph. Matte cream ($CREAM) paper background. \
A single deep oxblood ($OXBLOOD) object. Soft raking daylight, one long quiet shadow. \
Generous empty negative space in the upper-left third. Restrained, analog, subtle film grain. \
No text, no letters, no logo, no user interface."
ANCHOR="oxblood editorial still-life on warm cream paper, matching the Masquerade brand"
AGY_IMAGE="${AGY_IMAGE:-agy-image}"   # path to agy_image.py, or the installed binary

# imagegen <prompt> <width> <height> <outfile>
imagegen() {
  local prompt="$1" w="$2" h="$3" out="$4"
  "$AGY_IMAGE" --prompt "$BRAND_PREAMBLE $prompt" \
    --width "$w" --height "$h" --out "$out" \
    --ref "$REF_STILL" --subject-anchor "$ANCHOR" --crop --quiet
}

if [[ "${GEN_PHOTOS:-0}" == "1" ]]; then
  need "$AGY_IMAGE"
  echo "==> 6/6  editorial photography (agy-image)"

  # App Store feature backdrop: generate imagery, composite the wordmark crisply.
  imagegen "Wide horizontal composition, the object resting lower-right." \
    1500 1024 "$STORE/feature-bg.png"
  magick "$STORE/feature-bg.png" -resize 1200x630^ -gravity center -extent 1200x630 \
    -font "$SERIF_IT" -pointsize 64 -fill "$OXBLOOD" \
      -gravity west -annotate +100+0 "Masquerade" \
    "$STORE/appstore-feature.png"

  # Screenshot scene backdrop (portrait) — frame real captures over this later.
  imagegen "Vertical composition, the object resting in the lower third." \
    1290 2796 "$STORE/screenshot-bg.png"
else
  echo "==> 6/6  editorial photography — skipped (set GEN_PHOTOS=1 to run agy-image)"
fi

echo "done. Review the diff under web/, store/, ios/, and assets/brand/source/."
