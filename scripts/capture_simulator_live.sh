#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_DIR="$REPO_ROOT/assets/marketing/screenshots/raw"
mkdir -p "$RAW_DIR"

DEVICE="ECB5A394-E735-43DB-B803-8F28502440F7"

echo "==> Booting Simulator $DEVICE..."
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator

echo "==> Starting Masquerade Screenshot Runner on Simulator..."
flutter run -t lib/screenshot_runner.dart -d "$DEVICE" --release &
FLUTTER_PID=$!

cleanup() {
  echo "==> Cleaning up Flutter run process..."
  kill "$FLUTTER_PID" 2>/dev/null || true
  rm -f "$REPO_ROOT/lib/screenshot_runner.dart"
}
trap cleanup EXIT

echo "==> Waiting for app to launch on simulator..."
sleep 18

echo "==> Capturing Screen 1: Home Desk..."
xcrun simctl io booted screenshot "$RAW_DIR/01_home_desk.png"
sleep 4.5

echo "==> Capturing Screen 2: JSON Formatter..."
xcrun simctl io booted screenshot "$RAW_DIR/02_json_formatter.png"
sleep 4.5

echo "==> Capturing Screen 3: Timestamp Epoch..."
xcrun simctl io booted screenshot "$RAW_DIR/03_timestamp_epoch.png"
sleep 4.5

echo "==> Capturing Screen 4: JWT Inspector..."
xcrun simctl io booted screenshot "$RAW_DIR/04_jwt_inspector.png"
sleep 4.5

echo "==> Capturing Screen 5: Color & Contrast..."
xcrun simctl io booted screenshot "$RAW_DIR/05_color_contrast.png"
sleep 4.5

echo "==> Capturing Screen 6: Regex Tester..."
xcrun simctl io booted screenshot "$RAW_DIR/06_regex_tester.png"
sleep 4.5

echo "==> Capturing Screen 7: Settings Screen..."
xcrun simctl io booted screenshot "$RAW_DIR/07_privacy_settings.png"
sleep 2

echo "==> All 7 screenshots captured directly from simulator!"

echo "==> Formatting App Store dimensions (6.9\" and 6.5\")..."
"$REPO_ROOT/scripts/capture-store-screenshots.sh"

echo "==> Done! Real simulator captures ready."
