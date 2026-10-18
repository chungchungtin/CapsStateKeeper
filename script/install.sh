#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CapsStateKeeper"
BUNDLE_ID="com.zhongyongting.CapsStateKeeper"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${CAPS_STATE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LAUNCH_AGENT="$LAUNCH_AGENTS/$BUNDLE_ID.plist"
DOMAIN="gui/$UID"

case "${1:-build}" in
  build)
    "$ROOT_DIR/script/build_and_run.sh" build
    ;;
  --use-built-app)
    test -x "$SOURCE_APP/Contents/MacOS/$APP_NAME"
    ;;
  *)
    echo "usage: $0 [--use-built-app]" >&2
    exit 2
    ;;
esac
EXPECTED_BUILD=""
if [[ "${2:-}" == "--expected-build" && "$#" -eq 3 ]]; then
  EXPECTED_BUILD="$3"
elif [[ "$#" -gt 1 ]]; then
  echo "usage: $0 [--use-built-app [--expected-build ID]]" >&2
  exit 2
fi
source "$SCRIPT_DIR/install-core.sh"
caps_install_update "$SOURCE_APP" "$INSTALLED_APP" "$LAUNCH_AGENT" "$ROOT_DIR/.app-backups" "$DOMAIN" "$EXPECTED_BUILD"
