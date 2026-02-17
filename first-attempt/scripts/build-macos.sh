#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Scamp.app"
ROOT_APP_PATH="$ROOT_DIR/Scamp.app"

if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
  echo "Usage: $0 [Debug|Release]"
  exit 1
fi

# Keep project file in sync with project.yml when using the scripted path.
if [[ ! -d "$ROOT_DIR/Scamp.xcodeproj" || "$ROOT_DIR/project.yml" -nt "$ROOT_DIR/Scamp.xcodeproj/project.pbxproj" ]]; then
  xcodegen generate --project "$ROOT_DIR"
fi

xcodebuild \
  -project "$ROOT_DIR/Scamp.xcodeproj" \
  -scheme Scamp \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "platform=macOS" \
  build

mkdir -p "$ROOT_APP_PATH"
rsync -a --delete "$APP_PATH/" "$ROOT_APP_PATH/"

echo "Built app: $APP_PATH"
echo "Published app: $ROOT_APP_PATH"
