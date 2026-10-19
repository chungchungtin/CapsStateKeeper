#!/usr/bin/env bash
# Public drag-to-install image. Never installs or stops the user's running app.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="1.2.3"
RELEASE="v1.2.3-preview.1"
BUILD="8"
OUT="$ROOT_DIR/dist/releases/$RELEASE"
NAME="e04-$RELEASE-universal"
[[ ! -e "$OUT" ]] || { echo "Release output already exists: $OUT" >&2; exit 2; }
cd "$ROOT_DIR"
swift build -c release --arch arm64 --arch x86_64 --product CapsStateKeeper --scratch-path .build/distribution -debug-info-format none
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --product CapsStateKeeper --scratch-path .build/distribution --show-bin-path)"
STAGE="$(mktemp -d "$ROOT_DIR/.build/e04-release.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/image/CapsStateKeeper.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CapsStateKeeper" "$APP/Contents/MacOS/CapsStateKeeper"
/usr/bin/strip -S "$APP/Contents/MacOS/CapsStateKeeper"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
PLIST="$APP/Contents/Info.plist"
plutil -create xml1 "$PLIST"
for pair in 'CFBundleExecutable:CapsStateKeeper' 'CFBundleIdentifier:com.zhongyongting.CapsStateKeeper' 'CFBundleName:e04' 'CFBundleDisplayName:e04' 'CFBundlePackageType:APPL' 'CFBundleIconFile:AppIcon.icns' 'NSPrincipalClass:NSApplication' 'LSMinimumSystemVersion:14.0'; do
  plutil -insert "${pair%%:*}" -string "${pair#*:}" "$PLIST"
done
plutil -insert CFBundleShortVersionString -string "$VERSION" "$PLIST"
plutil -insert CFBundleVersion -string "$BUILD" "$PLIST"
plutil -insert LSUIElement -bool true "$PLIST"
plutil -insert NSHighResolutionCapable -bool true "$PLIST"
# Public bundles deliberately omit the developer's local project/update metadata.
for lang in en zh_TW; do
  mkdir -p "$APP/Contents/Resources/$lang.lproj"
  printf 'CFBundleName = "e04";\nCFBundleDisplayName = "e04";\n' > "$APP/Contents/Resources/$lang.lproj/InfoPlist.strings"
done
ARCHS="$(/usr/bin/lipo -archs "$APP/Contents/MacOS/CapsStateKeeper")"
[[ " $ARCHS " == *" arm64 "* && " $ARCHS " == *" x86_64 "* ]] || { echo "Missing universal architecture: $ARCHS" >&2; exit 1; }
/usr/bin/strings "$APP/Contents/MacOS/CapsStateKeeper" > "$STAGE/binary-strings.txt"
if /usr/bin/grep -Eq '/Users/|/Volumes/' "$STAGE/binary-strings.txt"; then
  echo "Private project path found in release binary" >&2; exit 1
fi
# This preview is ad-hoc signed; it is not Developer ID signed or notarized.
codesign --force --sign - --options runtime "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p "$OUT"
cp "$ROOT_DIR/docs/INSTALL.txt" "$STAGE/image/安裝說明 Installation.txt"
cp "$ROOT_DIR/LICENSE" "$STAGE/image/LICENSE.txt"
ln -s /Applications "$STAGE/image/Applications"
hdiutil create -volname "e04 $VERSION Preview" -srcfolder "$STAGE/image" -format UDZO -fs HFS+ -ov "$OUT/$NAME.dmg"
hdiutil verify "$OUT/$NAME.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME.zip"
(cd "$OUT" && shasum -a 256 "$NAME.dmg" "$NAME.zip" > SHA256SUMS.txt)
printf 'Created public preview packages in %s\n' "$OUT"
