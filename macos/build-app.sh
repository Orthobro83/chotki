#!/bin/bash
# Assembles a signed .app bundle. Xcode is not required — the Command Line
# Tools SDK is enough, but UNUserNotificationCenter needs a real bundle with a
# stable identifier, so a bare `swift build` binary will not do.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-debug}"
# Both slices unless told otherwise. A release anyone downloads has to be
# universal — "it will not open" reads identically whether the cause is the
# architecture or Gatekeeper, so an Intel tester cannot tell you which it is.
# `debug` stays single-arch, because doubling every local build to serve a
# machine nobody here is developing on is a poor trade.
ARCHS=()
SWIFT_OPTS=()
if [ -n "${CHOTKI_SCRATCH_PATH:-}" ]; then
    # A writable scratch directory also keeps SwiftPM's nested build sandbox
    # from trying to update a protected cache in managed workspaces.
    SWIFT_OPTS=(--disable-sandbox --scratch-path "$CHOTKI_SCRATCH_PATH")
fi
LABEL="$CONFIG"
if [ "$CONFIG" = "release" ] && [ "${CHOTKI_SINGLE_ARCH:-}" != "1" ]; then
    ARCHS=(--arch arm64 --arch x86_64)
    LABEL="$CONFIG, universal"
fi
# macOS ships bash 3.2, where "${ARCHS[@]}" on an empty array is an unbound
# variable under `set -u` — so a debug build died on the line meant to leave it
# alone. This is the 3.2-safe expansion: nothing at all when the array is empty.
APP_NAME="Chotki"
BUNDLE_ID="info.chotki.app"
source ./version.env
VERSION="$CHOTKI_VERSION"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "==> building ($LABEL)"
swift build -c "$CONFIG" ${ARCHS[@]+"${ARCHS[@]}"} ${SWIFT_OPTS[@]+"${SWIFT_OPTS[@]}"}
# --show-bin-path must be given the same flags: a universal build lands in
# .build/apple/Products/, not .build/<arch>-apple-macosx/, and reading the
# wrong path silently bundles yesterday's single-arch binary.
BIN="$(swift build -c "$CONFIG" ${ARCHS[@]+"${ARCHS[@]}"} ${SWIFT_OPTS[@]+"${SWIFT_OPTS[@]}"} --show-bin-path)/$APP_NAME"

echo "==> assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
# SwiftPM resource bundles must travel with the executable.
for resource in "$(dirname "$BIN")"/*.bundle; do
    [ -d "$resource" ] && cp -R "$resource" "$APP/Contents/Resources/"
done

# The icon is generated from the app itself, not checked in, so it cannot fall
# out of step with the drawing. Without a real .icns in the bundle, Launchpad
# and Finder show the generic placeholder however the Dock icon is set at
# runtime — setting NSApp.applicationIconImage only affects the running app.
echo "==> generating the icon"
if [ -n "${CHOTKI_ICON_SOURCE:-}" ]; then
    # Reuse a previously exported icon when the source artwork is unchanged
    # and this build host cannot start AppKit for the export step.
    cp "$CHOTKI_ICON_SOURCE" "$APP/Contents/Resources/$APP_NAME.icns"
else
    ICONSET="$(mktemp -d)/$APP_NAME.iconset"
    CHOTKI_EXPORT_ICON="$ICONSET" "$BIN" >/dev/null
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/$APP_NAME.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <!-- CFBundleIconFile names the .icns in Resources. There is deliberately
         no CFBundleIconName beside it: that key is for an icon inside a
         compiled asset catalog, it takes precedence over CFBundleIconFile, and
         this bundle has no Assets.car for it to resolve against. macOS
         followed it, found nothing, and drew a blank white tile in Stage
         Manager — while the Dock looked right, because the app also sets
         NSApp.applicationIconImage at runtime and that only reaches the Dock. -->
    <key>CFBundleIconFile</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$CHOTKI_MARKETING_VERSION</string>
    <key>CFBundleVersion</key><string>$CHOTKI_BUNDLE_VERSION</string>
    <key>ChotkiDevelopmentVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Menu bar app: no Dock icon, no menu bar menus of its own. -->
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 Ryan Macfarlane. All rights reserved.</string>
</dict>
</plist>
PLIST

# Strip extended attributes before signing. macOS adds provenance attributes to
# anything it builds, and `ditto` archives those as AppleDouble `._` files — which
# a command-line `unzip` then materialises, breaking the signature seal and making
# the app look damaged. Finder is unaffected, but the failure is baffling when it
# happens, so remove the cause.
xattr -cr "$APP"

echo "==> signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --verbose=1 "$APP" 2>&1 | sed 's/^/    /'

# Said out loud, because a bundle that is quietly single-arch is exactly the
# failure this is here to prevent and it looks identical from the outside.
echo "==> architectures"
lipo -info "$APP/Contents/MacOS/$APP_NAME" | sed 's/^/    /'

echo "==> packaging"
rm -f "$DIST/$APP_NAME.zip"
ditto -c -k --keepParent --noextattr --norsrc "$APP" "$DIST/$APP_NAME.zip"

# A separate, plainly named review app always starts with fictional data. Its
# own bundle key selects that mode before the live store or services are made;
# a reviewer can double-click it without remembering a shell argument. Keep
# its bundle identifier distinct so Launch Services cannot substitute the
# installed daily-use app.
REVIEW_APP="$DIST/$APP_NAME Review.app"
echo "==> assembling isolated review app"
rm -rf "$REVIEW_APP"
cp -R "$APP" "$REVIEW_APP"
REVIEW_PLIST="$REVIEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME Review" "$REVIEW_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME Review" "$REVIEW_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID.review" "$REVIEW_PLIST"
/usr/libexec/PlistBuddy -c "Add :ChotkiReviewSample bool true" "$REVIEW_PLIST"
xattr -cr "$REVIEW_APP"
codesign --force --sign - --timestamp=none "$REVIEW_APP"
codesign --verify --verbose=1 "$REVIEW_APP" 2>&1 | sed 's/^/    /'
rm -f "$DIST/$APP_NAME Review.zip"
ditto -c -k --keepParent --noextattr --norsrc "$REVIEW_APP" "$DIST/$APP_NAME Review.zip"

echo "==> built $APP, $DIST/$APP_NAME.zip, and the isolated $REVIEW_APP"
