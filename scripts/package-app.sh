#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
APP_VERSION="${APP_VERSION:-1.0.0}"
APP_NAME="Kimchi Companion"
BUNDLE_NAME="KimchiCompanion"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$BUNDLE_NAME.dmg"

# Code signing: real Developer ID or ad-hoc (-)
CODESIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-${CODESIGN_IDENTITY:--}}"

echo "═══════════════════════════════════════════════════════"
echo "  Packaging $APP_NAME v$APP_VERSION"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── Clean ──────────────────────────────────────────────────────────
echo "→ Cleaning $BUILD_DIR/"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── Build arm64 ────────────────────────────────────────────────────
echo "→ Building arm64..."
swift build --triple arm64-apple-macosx14.0 -c release 2>&1
echo "  ✓ arm64 build complete"

# ── Build x86_64 ───────────────────────────────────────────────────
echo "→ Building x86_64..."
swift build --triple x86_64-apple-macosx14.0 -c release 2>&1
echo "  ✓ x86_64 build complete"

# ── Universal binary ──────────────────────────────────────────────
ARM64_BIN=".build/arm64-apple-macosx/release/$BUNDLE_NAME"
X86_BIN=".build/x86_64-apple-macosx/release/$BUNDLE_NAME"

echo "→ Creating universal binary..."
lipo -create "$ARM64_BIN" "$X86_BIN" -output "$BUILD_DIR/$BUNDLE_NAME"
echo "  ✓ Universal binary: $(lipo -archs "$BUILD_DIR/$BUNDLE_NAME")"

# ── Assemble .app bundle ──────────────────────────────────────────
echo "→ Assembling $APP_NAME.app..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"

# Copy and patch Info.plist
cp SupportFiles/Info.plist "$APP_BUNDLE/Contents/Info.plist"
sed -i '' "s|<string>1.0.0</string><!-- CFBundleVersion -->|<string>$APP_VERSION</string>|g" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
# Replace version strings (both CFBundleVersion and CFBundleShortVersionString use 1.0.0)
if [ "$APP_VERSION" != "1.0.0" ]; then
    # Use plutil for reliable plist editing
    plutil -replace CFBundleVersion -string "$APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
    plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
fi

# PkgInfo
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# Binary
cp "$BUILD_DIR/$BUNDLE_NAME" "$APP_BUNDLE/Contents/MacOS/$BUNDLE_NAME"

echo "  ✓ Bundle assembled"

# ── Code sign ─────────────────────────────────────────────────────
echo "→ Code signing (identity: ${CODESIGN_IDENTITY})..."
if [ "$CODESIGN_IDENTITY" != "-" ]; then
    codesign --force --options runtime --sign "$CODESIGN_IDENTITY" --timestamp "$APP_BUNDLE"
else
    codesign --force --sign - "$APP_BUNDLE"
fi
echo "  ✓ Code signed"

# ── Create DMG ────────────────────────────────────────────────────
echo "→ Creating DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
echo "  ✓ DMG created"

# ── SHA256 ────────────────────────────────────────────────────────
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "$SHA256  $BUNDLE_NAME.dmg" > "$DMG_PATH.sha256"

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Packaging complete"
echo "═══════════════════════════════════════════════════════"
echo "  App:    $APP_BUNDLE"
echo "  DMG:    $DMG_PATH"
echo "  SHA256: $SHA256"
echo "  Archs:  $(lipo -archs "$APP_BUNDLE/Contents/MacOS/$BUNDLE_NAME")"
echo "  Size:   $(du -h "$DMG_PATH" | awk '{print $1}')"
echo "═══════════════════════════════════════════════════════"
