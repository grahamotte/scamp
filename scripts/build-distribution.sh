#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode-dist"
DIST_DIR="$ROOT_DIR/dist"
ROOT_APP_PATH="$DIST_DIR/Scamp.app"
ZIP_PATH="$DIST_DIR/Scamp-macOS-unsigned.zip"

if [[ -d "$ROOT_DIR/Scamp.xcodeproj" ]]; then
  PROJECT_PATH="$ROOT_DIR/Scamp.xcodeproj"
elif [[ -d "$ROOT_DIR/Scamp/Scamp.xcodeproj" ]]; then
  PROJECT_PATH="$ROOT_DIR/Scamp/Scamp.xcodeproj"
else
  echo "Could not find Scamp.xcodeproj in root or /Scamp"
  exit 1
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/Scamp.app"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install Xcode and select it:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "Building unsigned Scamp (Release)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme Scamp \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found at: $APP_PATH"
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$ROOT_APP_PATH"
rsync -a "$APP_PATH/" "$ROOT_APP_PATH/"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_APP_PATH" "$ZIP_PATH"

echo "Unsigned app: $ROOT_APP_PATH"
echo "Distributable zip: $ZIP_PATH"
echo "Expected behavior: macOS will warn that the app cannot be verified."
