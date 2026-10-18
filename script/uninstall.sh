#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CapsStateKeeper"
BUNDLE_ID="com.zhongyongting.CapsStateKeeper"
INSTALLED_APP="$HOME/Applications/$APP_NAME.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
DOMAIN="gui/$UID"

launchctl bootout "$DOMAIN/$BUNDLE_ID" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -f "$LAUNCH_AGENT"
rm -rf "$INSTALLED_APP"

echo "Removed e04 and its LaunchAgent."
