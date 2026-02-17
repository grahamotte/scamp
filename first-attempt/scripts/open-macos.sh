#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-Debug}"
APP_PATH="$ROOT_DIR/Scamp.app"
FALLBACK_APP_PATH="$ROOT_DIR/.build/xcode/Build/Products/$CONFIGURATION/Scamp.app"

if [[ ! -d "$APP_PATH" ]]; then
  if [[ -d "$FALLBACK_APP_PATH" ]]; then
    APP_PATH="$FALLBACK_APP_PATH"
  else
    echo "App not found at $APP_PATH or $FALLBACK_APP_PATH"
    echo "Run: ./scripts/build-macos.sh $CONFIGURATION"
    exit 1
  fi
fi

open "$APP_PATH"
