#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-Debug}"

if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
  echo "Usage: $0 [Debug|Release]"
  exit 1
fi

echo "Stopping running Scamp app (if any)..."
osascript -e 'tell application "Scamp" to quit' >/dev/null 2>&1 || true
killall Scamp >/dev/null 2>&1 || true

echo "Cleaning previous app bundles..."
rm -rf "$ROOT_DIR/Scamp.app" "$ROOT_DIR/Sampt.app"

echo "Cleaning derived build output..."
rm -rf "$ROOT_DIR/.build/xcode"

echo "Building fresh app..."
"$ROOT_DIR/scripts/build-macos.sh" "$CONFIGURATION"

echo "Launching app..."
open "$ROOT_DIR/Scamp.app"
