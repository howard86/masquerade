#!/usr/bin/env bash
# Rasterize assets/brand/*.svg → assets/brand/source/*.png using IBM Plex
# fonts bundled in assets/fonts/. Requires librsvg (rsvg-convert).
#
# Usage: ./scripts/build-brand-pngs.sh
#
# Inputs (committed):
#   assets/brand/monogram-{light,dark}.svg            — square mark with hairline border
#   assets/brand/monogram-{light,dark}-maskable.svg   — square mark with 10% safe-zone inset (no border)
#   assets/brand/splash-{light,dark}.svg              — full splash composition
#
# Outputs (committed; consumed by flutter_launcher_icons + flutter_native_splash):
#   assets/brand/source/monogram-{light,dark}-1024.png
#   assets/brand/source/monogram-{light,dark}-maskable-1024.png
#   assets/brand/source/splash-{light,dark}.png
set -euo pipefail

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert not found. Install librsvg: brew install librsvg" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRAND_DIR="$REPO_ROOT/assets/brand"
OUT_DIR="$BRAND_DIR/source"
FONT_DIR="$REPO_ROOT/assets/fonts"
TMPDIR_BUILD="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BUILD"' EXIT

cat >"$TMPDIR_BUILD/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>$FONT_DIR</dir>
  <cachedir>$TMPDIR_BUILD/cache</cachedir>
</fontconfig>
EOF
mkdir -p "$TMPDIR_BUILD/cache" "$OUT_DIR"

export FONTCONFIG_FILE="$TMPDIR_BUILD/fonts.conf"
fc-cache -f "$FONT_DIR" >/dev/null

# Sanity: confirm Plex faces are visible to fontconfig.
for face in "IBM Plex Serif:style=Italic" "IBM Plex Mono:style=Medium"; do
  if ! fc-match -s "$face" | grep -qi "IBMPlex"; then
    echo "fontconfig cannot resolve $face from $FONT_DIR" >&2
    exit 1
  fi
done

render() {
  local src="$1" dst="$2" width="$3"
  rsvg-convert --width="$width" --keep-aspect-ratio --output="$dst" "$src"
  echo "  $(basename "$dst") ($width px)"
}

render "$BRAND_DIR/monogram-light.svg"          "$OUT_DIR/monogram-light-1024.png"          1024
render "$BRAND_DIR/monogram-dark.svg"           "$OUT_DIR/monogram-dark-1024.png"           1024
render "$BRAND_DIR/monogram-light-maskable.svg" "$OUT_DIR/monogram-light-maskable-1024.png" 1024
render "$BRAND_DIR/monogram-dark-maskable.svg"  "$OUT_DIR/monogram-dark-maskable-1024.png"  1024
render "$BRAND_DIR/splash-light.svg"            "$OUT_DIR/splash-light.png"                 1242
render "$BRAND_DIR/splash-dark.svg"             "$OUT_DIR/splash-dark.png"                  1242

echo "Done. Outputs in $OUT_DIR/"
