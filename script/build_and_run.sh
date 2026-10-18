#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  build|--build|run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify) ;;
  *) printf 'usage: %s [build|run|--debug|--logs|--telemetry|--verify]\n' "$0" >&2; exit 2 ;;
esac
APP_NAME="CapsStateKeeper"
BUNDLE_ID="com.zhongyongting.CapsStateKeeper"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
LAUNCH_AGENT_SERVICE="gui/$UID/$BUNDLE_ID"

cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/ModuleCache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$ROOT_DIR/.build/ModuleCache}"
swift_build() {
  if [[ "${CAPS_STATE_BUILD_WITHOUT_NESTED_SANDBOX:-0}" == "1" ]]; then
    swift build --disable-sandbox "$@"
  else
    swift build "$@"
  fi
}

# Keep the installed app running if a new build fails.
swift_build --product "$APP_NAME"
swift_build --product CapsStateUpdater
BUILD_BINARY="$(swift_build --show-bin-path)/$APP_NAME"
UPDATER_BINARY="$(swift_build --show-bin-path)/CapsStateUpdater"
BUILD_ID="$(/usr/bin/shasum -a 256 "$BUILD_BINARY" "$UPDATER_BINARY" "$ROOT_DIR/script/install.sh" "$ROOT_DIR/script/install-core.sh" "$ROOT_DIR/script/build_and_run.sh" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$DIST_DIR" "$ROOT_DIR/.app-backups"
PACKAGE_STAGE="$(mktemp -d "$DIST_DIR/.package-XXXXXX")"
make_bundle() {
  local bundle="$1" executable="$2" identifier="$3" display_name="$4" binary="$5"
  local plist="$bundle/Contents/Info.plist"
  mkdir -p "$bundle/Contents/MacOS"
  cp "$binary" "$bundle/Contents/MacOS/$executable"
  chmod +x "$bundle/Contents/MacOS/$executable"
  /usr/bin/plutil -create xml1 "$plist"
  /usr/bin/plutil -insert CFBundleExecutable -string "$executable" "$plist"
  /usr/bin/plutil -insert CFBundleIdentifier -string "$identifier" "$plist"
  /usr/bin/plutil -insert CFBundleName -string "$display_name" "$plist"
  /usr/bin/plutil -insert CFBundlePackageType -string APPL "$plist"
  /usr/bin/plutil -insert CFBundleShortVersionString -string 1.2.2 "$plist"
  /usr/bin/plutil -insert CFBundleVersion -string 6 "$plist"
  /usr/bin/plutil -insert LSMinimumSystemVersion -string "$MIN_SYSTEM_VERSION" "$plist"
  /usr/bin/plutil -insert LSUIElement -bool true "$plist"
  /usr/bin/plutil -insert NSPrincipalClass -string NSApplication "$plist"
  /usr/bin/plutil -insert CapsStateKeeperProjectDirectory -string "$ROOT_DIR" "$plist"
  /usr/bin/plutil -insert CapsStateKeeperBuildID -string "$BUILD_ID" "$plist"
  /usr/bin/plutil -insert CapsStateKeeperBuiltAt -string "$BUILT_AT" "$plist"
}
make_bundle "$PACKAGE_STAGE/$APP_NAME.app" "$APP_NAME" "$BUNDLE_ID" "$APP_NAME" "$BUILD_BINARY"
UPDATER_NAME="更新 CapsStateKeeper.app"
make_bundle "$PACKAGE_STAGE/$UPDATER_NAME" CapsStateUpdater "$BUNDLE_ID.Updater" "更新 CapsStateKeeper" "$UPDATER_BINARY"
mkdir -p "$PACKAGE_STAGE/$UPDATER_NAME/Contents/Resources"
cp "$ROOT_DIR/script/install.sh" "$ROOT_DIR/script/install-core.sh" "$PACKAGE_STAGE/$UPDATER_NAME/Contents/Resources/"

# A stable certificate can be supplied later; never manufacture trust or weaken
# macOS authorization requirements to avoid reauthorization after local builds.
SIGNING_IDENTITY="${CAPS_STATE_SIGNING_IDENTITY:--}"
for bundle in "$PACKAGE_STAGE/$APP_NAME.app" "$PACKAGE_STAGE/$UPDATER_NAME"; do
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" "$bundle"
  /usr/bin/codesign --verify --deep --strict "$bundle"
done
# Publish only complete, verified packages. Preserve previous built artifacts.
BUILD_BACKUP="$(mktemp -d "$ROOT_DIR/.app-backups/build-$(date +%Y%m%d-%H%M%S).XXXXXX")"
for name in "$UPDATER_NAME" "$APP_NAME.app"; do
  if [[ -e "$DIST_DIR/$name" ]]; then mv "$DIST_DIR/$name" "$BUILD_BACKUP/$name"; fi
  if ! mv "$PACKAGE_STAGE/$name" "$DIST_DIR/$name"; then
    if [[ -e "$BUILD_BACKUP/$name" ]]; then mv "$BUILD_BACKUP/$name" "$DIST_DIR/$name"; fi
    exit 1
  fi
done
rmdir "$PACKAGE_STAGE"

if [[ "$MODE" != "build" && "$MODE" != "--build" ]]; then
  # Do not stop a running app until both packages have built and verified.
  if launchctl print "$LAUNCH_AGENT_SERVICE" >/dev/null 2>&1; then
    launchctl bootout "$LAUNCH_AGENT_SERVICE"
  fi
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  for _ in {1..20}; do
    pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
    sleep 0.05
  done
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build|--build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -f "^$APP_BINARY$" >/dev/null
    ;;
  *)
    echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
