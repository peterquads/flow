#!/bin/sh
set -euo pipefail
APP="Flow"
BUNDLE_ID="com.peterquadrel.flow"
VERSION="0.1.0"
ARCH="arm64"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
STAGE="$BUILD/$APP.app"
BIN_SRC="$ROOT/.build/$ARCH-apple-macosx/release/$APP"
INSTALL_DIR="${FLOW_INSTALL_DIR:-/Applications}"
INSTALL_AGENT="${FLOW_INSTALL_AGENT:-1}"

echo "==> swift build -c release --arch $ARCH (stripped, size-optimized)"
cd "$ROOT"
swift build -c release --arch "$ARCH" \
  -Xswiftc -gnone \
  -Xswiftc -Osize \
  -Xlinker -dead_strip

if [ ! -f "$BIN_SRC" ]; then
  echo "ERROR: expected binary at $BIN_SRC"
  exit 1
fi

echo "==> Assembling bundle at $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS"
mkdir -p "$STAGE/Contents/Resources/Fonts"

cp "$BIN_SRC" "$STAGE/Contents/MacOS/$APP"
chmod +x "$STAGE/Contents/MacOS/$APP"
# Strip any remaining symbols. -u keeps undefined externals, -r preserves
# relocations needed by the dynamic linker.
/usr/bin/strip -u -r "$STAGE/Contents/MacOS/$APP" 2>/dev/null || true

cp "$ROOT/Resources/Fonts/"*.otf "$STAGE/Contents/Resources/Fonts/"

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$STAGE/Contents/Resources/AppIcon.icns"
else
  echo "WARN: AppIcon.icns not found; run scripts/make-icon.sh first."
fi

echo "==> Writing Info.plist"
PL="$STAGE/Contents/Info.plist"
/usr/bin/plutil -create xml1 "$PL"
/usr/bin/plutil -insert CFBundleName               -string "$APP"          "$PL"
/usr/bin/plutil -insert CFBundleDisplayName        -string "$APP"          "$PL"
/usr/bin/plutil -insert CFBundleIdentifier         -string "$BUNDLE_ID"    "$PL"
/usr/bin/plutil -insert CFBundleVersion            -string "$VERSION"      "$PL"
/usr/bin/plutil -insert CFBundleShortVersionString -string "$VERSION"      "$PL"
/usr/bin/plutil -insert CFBundleExecutable         -string "$APP"          "$PL"
/usr/bin/plutil -insert CFBundlePackageType        -string "APPL"          "$PL"
/usr/bin/plutil -insert CFBundleIconFile           -string "AppIcon"       "$PL"
/usr/bin/plutil -insert CFBundleInfoDictionaryVersion -string "6.0"        "$PL"
/usr/bin/plutil -insert LSMinimumSystemVersion     -string "14.0"          "$PL"
/usr/bin/plutil -insert LSUIElement                -bool   true            "$PL"
/usr/bin/plutil -insert NSHighResolutionCapable    -bool   true            "$PL"
/usr/bin/plutil -insert ATSApplicationFontsPath    -string "Fonts"         "$PL"
/usr/bin/plutil -insert NSHumanReadableCopyright   -string "© Peter Quadrel"  "$PL"

echo "==> Ad-hoc codesign"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$STAGE"
/usr/bin/codesign --verify --deep --strict "$STAGE" 2>&1 | tail -3 || true

echo "==> Installing to $INSTALL_DIR/$APP.app"
mkdir -p "$INSTALL_DIR"
# Quit running instance if present (so cp -R doesn't clash with the live binary)
/usr/bin/pkill -x "$APP" 2>/dev/null || true
# Give launchd a moment
sleep 1
rm -rf "$INSTALL_DIR/$APP.app"
cp -R "$STAGE" "$INSTALL_DIR/$APP.app"
# Strip quarantine xattr if any (we copied locally, but be safe)
/usr/bin/xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP.app" 2>/dev/null || true

if [ "$INSTALL_AGENT" = "1" ]; then
  AGENT_DIR="$HOME/Library/LaunchAgents"
  AGENT="$AGENT_DIR/$BUNDLE_ID.plist"
  mkdir -p "$AGENT_DIR"
  /usr/bin/plutil -create xml1 "$AGENT"
  /usr/bin/plutil -insert Label              -string "$BUNDLE_ID"                                      "$AGENT"
  /usr/bin/plutil -insert RunAtLoad          -bool   true                                              "$AGENT"
  /usr/bin/plutil -insert KeepAlive          -bool   false                                             "$AGENT"
  /usr/bin/plutil -insert ProcessType        -string "Interactive"                                     "$AGENT"
  /usr/bin/plutil -insert ProgramArguments   -array                                                    "$AGENT"
  /usr/bin/plutil -insert ProgramArguments.0 -string "$INSTALL_DIR/$APP.app/Contents/MacOS/$APP"       "$AGENT"
  echo "==> Reloading LaunchAgent"
  /bin/launchctl unload "$AGENT" 2>/dev/null || true
  /bin/launchctl load   "$AGENT"
  echo "    LaunchAgent installed at $AGENT"
else
  echo "==> Skipping LaunchAgent install (FLOW_INSTALL_AGENT=0)"
fi

echo ""
echo "✔ Installed $APP to $INSTALL_DIR/$APP.app"
echo "  Open with: open \"$INSTALL_DIR/$APP.app\""
