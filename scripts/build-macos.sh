#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode"
ROOT_APP_PATH="$ROOT_DIR/Scamp.app"

if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
  echo "Usage: $0 [Debug|Release]"
  exit 1
fi

if [[ -d "$ROOT_DIR/Scamp.xcodeproj" ]]; then
  PROJECT_PATH="$ROOT_DIR/Scamp.xcodeproj"
elif [[ -d "$ROOT_DIR/Scamp/Scamp.xcodeproj" ]]; then
  PROJECT_PATH="$ROOT_DIR/Scamp/Scamp.xcodeproj"
else
  echo "Could not find Scamp.xcodeproj in root or /Scamp"
  exit 1
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Scamp.app"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install Xcode and select it:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "Building Scamp ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme Scamp \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "platform=macOS" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found at: $APP_PATH"
  exit 1
fi

mkdir -p "$ROOT_APP_PATH"
rsync -a --delete "$APP_PATH/" "$ROOT_APP_PATH/"

echo "Built app: $APP_PATH"
echo "Published app: $ROOT_APP_PATH"
