#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/e04-icon.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ROOT_DIR/Resources/AppIcon.png" --out "$STAGE/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$ROOT_DIR/Resources/AppIcon.png" --out "$STAGE/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$STAGE/AppIcon.iconset" -o "$ROOT_DIR/Resources/AppIcon.icns"
