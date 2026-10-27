#!/usr/bin/env bash
# Exercise no-upscale profile selection and non-destructive output handling.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/masquerade-screenshot-test.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/screenshots/raw" "$TMP_DIR/screenshots/6.9-inch" "$TMP_DIR/screenshots/6.5-inch"
touch "$TMP_DIR/screenshots/raw/sample.png"
printf 'historical 6.9 PNG\n' > "$TMP_DIR/screenshots/6.9-inch/sample.png"
printf 'historical 6.5 PNG\n' > "$TMP_DIR/screenshots/6.5-inch/sample.png"

cat > "$TMP_DIR/bin/sips" <<'MOCK_SIPS'
#!/usr/bin/env bash
set -euo pipefail

args=("$@")
image="${args[${#args[@]}-1]}"

if [[ " ${args[*]} " == *" -g "* ]]; then
  if [[ " ${args[*]} " == *" pixelWidth "* ]]; then
    width=1206
    height=2622
    case "$image" in
      *-cropped.png) width=1206; height=2622 ;;
      *-1206-resized.png) width=1206; height=2622 ;;
      *-1206.jpg) width=1206; height=2622 ;;
    esac
    printf '%s\n' "$image" '  pixelWidth: '"$width" '  pixelHeight: '"$height"
  elif [[ " ${args[*]} " == *" format "* ]]; then
    printf '%s\n' "$image" '  format: jpeg'
  elif [[ " ${args[*]} " == *" hasAlpha "* ]]; then
    printf '%s\n' "$image" '  hasAlpha: no'
  else
    echo "unexpected sips property query: $*" >&2
    exit 2
  fi
  exit 0
fi

output=""
for ((i = 0; i < ${#args[@]}; i++)); do
  if [[ "${args[$i]}" == --out ]]; then
    output="${args[$((i + 1))]}"
    break
  fi
done
if [[ -z "$output" ]]; then
  echo "unexpected sips transform: $*" >&2
  exit 2
fi
mkdir -p "$(dirname "$output")"
touch "$output"
MOCK_SIPS
chmod +x "$TMP_DIR/bin/sips"

PATH="$TMP_DIR/bin:$PATH" "$REPO_ROOT/scripts/capture-store-screenshots.sh" "$TMP_DIR/screenshots"

required="$TMP_DIR/screenshots/6.3-inch/sample.jpg"
if [[ ! -f "$required" ]]; then
  echo "missing required validated JPEG candidate: $required" >&2
  exit 1
fi
for profile in 6.9-inch 6.5-inch; do
  if [[ -e "$TMP_DIR/screenshots/$profile/sample.jpg" ]]; then
    echo "undersized source unexpectedly produced a $profile candidate" >&2
    exit 1
  fi
done
[[ "$(cat "$TMP_DIR/screenshots/6.9-inch/sample.png")" == "historical 6.9 PNG" ]]
[[ "$(cat "$TMP_DIR/screenshots/6.5-inch/sample.png")" == "historical 6.5 PNG" ]]

# A second run collides with an existing required-profile JPEG. It must fail
# without replacing that destination or the historical optional-profile PNGs.
printf 'keep existing candidate\n' > "$required"
if PATH="$TMP_DIR/bin:$PATH" "$REPO_ROOT/scripts/capture-store-screenshots.sh" "$TMP_DIR/screenshots" >"$TMP_DIR/retry.log" 2>&1; then
  echo "pipeline unexpectedly overwrote an existing candidate" >&2
  exit 1
fi
[[ "$(cat "$required")" == "keep existing candidate" ]]
[[ "$(cat "$TMP_DIR/screenshots/6.9-inch/sample.png")" == "historical 6.9 PNG" ]]
[[ "$(cat "$TMP_DIR/screenshots/6.5-inch/sample.png")" == "historical 6.5 PNG" ]]

# A PNG and JPEG with one stem must be rejected before either can create or
# replace a candidate. Keep a destination sentinel to verify it is untouched.
duplicate_root="$TMP_DIR/duplicates"
mkdir -p "$duplicate_root/raw" "$duplicate_root/6.3-inch"
touch "$duplicate_root/raw/sample.png" "$duplicate_root/raw/sample.jpg"
printf 'existing candidate\n' > "$duplicate_root/6.3-inch/sample.jpg"
if PATH="$TMP_DIR/bin:$PATH" "$REPO_ROOT/scripts/capture-store-screenshots.sh" "$duplicate_root" >"$TMP_DIR/duplicate.log" 2>&1; then
  echo "pipeline unexpectedly accepted duplicate raw filename stems" >&2
  exit 1
fi
if ! grep -F "duplicate raw screenshot filename stem 'sample'" "$TMP_DIR/duplicate.log" >/dev/null; then
  echo "duplicate stems were rejected for an unexpected reason:" >&2
  cat "$TMP_DIR/duplicate.log" >&2
  exit 1
fi
[[ "$(cat "$duplicate_root/6.3-inch/sample.jpg")" == "existing candidate" ]]
for profile in 6.9-inch 6.5-inch; do
  if [[ -e "$duplicate_root/$profile/sample.jpg" ]]; then
    echo "duplicate input created a candidate in $profile" >&2
    exit 1
  fi
done

echo "Screenshot pipeline passed profile-size, format/alpha, duplicate-stem, and no-overwrite checks."
