#!/usr/bin/env bash
# Prepare App Store screenshot candidates from genuine, pre-captured iPhone images.
# This script does not run the app or create screenshots.
#
# The output dimensions below match the supported iPhone screenshot slots in
# Apple's current specification. Confirm the selected UI and slot before upload.
#
# Usage:
#   ./scripts/capture-store-screenshots.sh [screenshot_root]
#
# Prerequisites:
#   - macOS with sips installed.
#   - One portrait screenshot per scene in screenshot_root/raw/.
#   - Images are at least the required 6.3-inch profile resolution.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/assets/marketing/screenshots}"
RAW_DIR="${OUT_DIR}/raw"
DIR_6_9="${OUT_DIR}/6.9-inch"
DIR_6_5="${OUT_DIR}/6.5-inch"
DIR_6_3="${OUT_DIR}/6.3-inch"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/masquerade-screenshots.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! command -v sips >/dev/null 2>&1; then
  echo "Error: sips is required; run this script on macOS." >&2
  exit 1
fi

if [[ ! -d "$RAW_DIR" ]]; then
  echo "Error: missing raw screenshot directory: $RAW_DIR" >&2
  exit 1
fi

shopt -s nullglob
raw_images=("$RAW_DIR"/*.png "$RAW_DIR"/*.jpg "$RAW_DIR"/*.jpeg)
shopt -u nullglob
if (( ${#raw_images[@]} == 0 )); then
  echo "Error: no PNG or JPEG screenshots found in $RAW_DIR" >&2
  exit 1
fi
if (( ${#raw_images[@]} > 10 )); then
  echo "Error: App Store Connect accepts at most 10 screenshots per device size." >&2
  exit 1
fi

# Output names omit the source extension, so matching stems would otherwise
# write to the same temporary candidate and silently drop one screenshot.
for ((current_index = 0; current_index < ${#raw_images[@]}; current_index++)); do
  current_name="$(basename "${raw_images[$current_index]}")"
  current_stem="${current_name%.*}"
  for ((previous_index = 0; previous_index < current_index; previous_index++)); do
    previous_name="$(basename "${raw_images[$previous_index]}")"
    previous_stem="${previous_name%.*}"
    if [[ "$current_stem" == "$previous_stem" ]]; then
      echo "Error: duplicate raw screenshot filename stem '$current_stem': ${raw_images[$previous_index]} and ${raw_images[$current_index]}." >&2
      exit 1
    fi
  done
done

image_dimensions() {
  sips -g pixelWidth -g pixelHeight "$1" |
    awk '/pixelWidth:/ { width = $2 } /pixelHeight:/ { height = $2 } END { if (width && height) print width "x" height }'
}

image_property() {
  sips -g "$2" "$1" | awk -v key="$2" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      separator = index(line, ":")
      if (!separator) next

      property = substr(line, 1, separator - 1)
      if (property != key) next

      value = substr(line, separator + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
    }
  '
}

render_candidate() {
  local src="$1"
  local name="$2"
  local width="$3"
  local height="$4"
  local output="$5"
  local resized="$TMP_DIR/${name}-${width}-resized.png"
  local height_resized="$TMP_DIR/${name}-${width}-height-resized.png"
  local cropped="$TMP_DIR/${name}-${width}-cropped.png"
  local candidate="$TMP_DIR/${name}-${width}.jpg"
  local source_dimensions source_width source_height
  local dimensions actual_width actual_height crop_top format has_alpha

  # Resample one dimension only, then center-crop the other to preserve the
  # screenshot's aspect ratio. Refuse undersized sources rather than upscale.
  source_dimensions="$(image_dimensions "$src")"
  IFS=x read -r source_width source_height <<< "$source_dimensions"
  if [[ -z "$source_width" || -z "$source_height" ]] || (( source_width < width || source_height < height )); then
    echo "Error: $src is too small for ${width}x${height} (got ${source_dimensions:-unreadable})." >&2
    return 1
  fi
  sips --resampleWidth "$width" "$src" --out "$resized" >/dev/null
  dimensions="$(image_dimensions "$resized")"
  IFS=x read -r actual_width actual_height <<< "$dimensions"
  # Some Apple slot ratios are a fraction taller than the source. In that
  # case resize by height, then crop the one-pixel width surplus instead.
  if (( actual_height < height )); then
    sips --resampleHeight "$height" "$src" --out "$height_resized" >/dev/null
    resized="$height_resized"
    dimensions="$(image_dimensions "$resized")"
    IFS=x read -r actual_width actual_height <<< "$dimensions"
  fi
  if (( actual_width < width || actual_height < height )); then
    echo "Error: $src cannot produce ${width}x${height} without upscaling or stretching (got ${dimensions:-unknown})." >&2
    return 1
  fi

  crop_top=$(((actual_height - height) / 2))
  local crop_left=$(((actual_width - width) / 2))
  sips --cropToHeightWidth "$height" "$width" --cropOffset "$crop_top" "$crop_left" "$resized" --out "$cropped" >/dev/null
  sips -s format jpeg -s formatOptions 100 "$cropped" --out "$candidate" >/dev/null

  dimensions="$(image_dimensions "$candidate")"
  format="$(image_property "$candidate" format)"
  has_alpha="$(image_property "$candidate" hasAlpha)"
  if [[ "$dimensions" != "${width}x${height}" ]]; then
    echo "Error: $candidate is ${dimensions:-unreadable}; expected ${width}x${height}." >&2
    return 1
  fi
  if [[ "$format" != "jpeg" && "$format" != "JPEG" ]]; then
    echo "Error: $candidate has unexpected format '${format:-unknown}'." >&2
    return 1
  fi
  if [[ "$has_alpha" != "no" ]]; then
    echo "Error: $candidate still has an alpha channel ('${has_alpha:-unknown}')." >&2
    return 1
  fi
  mv "$candidate" "$output"
}

mkdir -p "$TMP_DIR/6.9-inch" "$TMP_DIR/6.5-inch" "$TMP_DIR/6.3-inch"
profiles=("6.9-inch:1320:2868" "6.5-inch:1284:2778" "6.3-inch:1206:2622")
for src in "${raw_images[@]}"; do
  name="$(basename "$src")"
  name="${name%.*}"
  source_dimensions="$(image_dimensions "$src")"
  IFS=x read -r source_width source_height <<< "$source_dimensions"
  if [[ -z "$source_width" || -z "$source_height" ]] || (( source_width < 1206 || source_height < 2622 )); then
    echo "Error: $src is too small for the required 6.3-inch profile (got ${source_dimensions:-unreadable}; need at least 1206x2622)." >&2
    exit 1
  fi

  for profile in "${profiles[@]}"; do
    IFS=: read -r profile_name width height <<< "$profile"
    output="$TMP_DIR/$profile_name/${name}.jpg"
    if (( source_width < width || source_height < height )); then
      if [[ "$profile_name" == "6.3-inch" ]]; then
        echo "Error: $src is too small for required $profile_name (${source_dimensions:-unreadable}; need at least ${width}x${height})." >&2
        exit 1
      fi
      echo "Skipping optional $profile_name candidate for $src: source is ${source_dimensions}, which is below ${width}x${height}."
      continue
    fi
    render_candidate "$src" "$name" "$width" "$height" "$output"
  done
done

# Check every destination before moving any candidate so an earlier image
# cannot be replaced by a later one with the same name.
for src in "${raw_images[@]}"; do
  name="$(basename "$src")"
  name="${name%.*}"
  for profile in "${profiles[@]}"; do
    IFS=: read -r profile_name _width _height <<< "$profile"
    candidate="$TMP_DIR/$profile_name/${name}.jpg"
    [[ -f "$candidate" ]] || continue
    destination="$OUT_DIR/$profile_name/${name}.jpg"
    if [[ -e "$destination" || -L "$destination" ]]; then
      echo "Error: refusing to overwrite existing screenshot: $destination" >&2
      exit 1
    fi
  done
done

mkdir -p "$DIR_6_9" "$DIR_6_5" "$DIR_6_3"
for src in "${raw_images[@]}"; do
  name="$(basename "$src")"
  name="${name%.*}"
  for profile in "${profiles[@]}"; do
    IFS=: read -r profile_name _width _height <<< "$profile"
    candidate="$TMP_DIR/$profile_name/${name}.jpg"
    [[ -f "$candidate" ]] || continue
    mv "$candidate" "$OUT_DIR/$profile_name/${name}.jpg"
  done
done

echo "Prepared ${#raw_images[@]} JPEG candidates for every profile the sources can support without upscaling."
echo "Raw captures are unchanged. Verify the selected screenshot slot and current Apple specifications before upload."
