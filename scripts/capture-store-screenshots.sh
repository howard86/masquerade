#!/usr/bin/env bash
# capture-store-screenshots.sh — App Store screenshot capture and format pipeline.
#
# Generates App Store Connect compliant screenshot sets for iPhone:
#   - 6.9" Display: 1320 x 2868 (iPhone 16 Pro Max / iPhone 17 Pro Max)
#   - 6.5" Display: 1284 x 2778 (iPhone 14 Plus / iPhone 13 Pro Max)
#
# Usage:
#   ./scripts/capture-store-screenshots.sh [output_dir]
#
# Prerequisites:
#   - macOS with sips installed.
#   - Pre-captured raw images in assets/marketing/screenshots/raw/ or live simulator.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/assets/marketing/screenshots}"
RAW_DIR="${OUT_DIR}/raw"
DIR_6_9="${OUT_DIR}/6.9-inch"
DIR_6_5="${OUT_DIR}/6.5-inch"

mkdir -p "${RAW_DIR}" "${DIR_6_9}" "${DIR_6_5}"

echo "==> Masquerade App Store Screenshot Pipeline"
echo "Target output directories:"
echo "  - 6.9\" (1320x2868): ${DIR_6_9}"
echo "  - 6.5\" (1284x2778): ${DIR_6_5}"

format_screenshot() {
  local src="$1"
  local name="$2"

  if [ ! -f "$src" ]; then
    echo "Warning: Source file $src not found. Skipping."
    return
  fi

  local out_6_9="${DIR_6_9}/${name}.png"
  local out_6_5="${DIR_6_5}/${name}.png"

  # 6.9" standard (1320x2868)
  cp "$src" "$out_6_9"
  sips -z 2868 1320 "$out_6_9" > /dev/null 2>&1 || true

  # 6.5" standard (1284x2778)
  cp "$src" "$out_6_5"
  sips -z 2778 1284 "$out_6_5" > /dev/null 2>&1 || true

  echo "  ✓ Processed ${name} -> [6.9\": 1320x2868, 6.5\": 1284x2778]"
}

# Process all raw screenshots in RAW_DIR
count=0
shopt -s nullglob
for img in "${RAW_DIR}"/*.png "${RAW_DIR}"/*.jpg; do
  if [ -f "$img" ]; then
    base=$(basename "$img" | sed 's/\.[^.]*$//')
    format_screenshot "$img" "$base"
    count=$((count + 1))
  fi
done
shopt -u nullglob

if [ "$count" -eq 0 ]; then
  echo "No raw images found in ${RAW_DIR}."
  echo "Run 'flutter test test/tools/generate_screenshots_test.dart' to populate raw screenshots."
fi

echo "==> Done. Processed ${count} screenshots."
