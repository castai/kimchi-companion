#!/usr/bin/env bash
set -euo pipefail

echo "═══════════════════════════════════════════════════════"
echo "  S06: Distribution — Verification"
echo "═══════════════════════════════════════════════════════"
echo ""

PASS=0
FAIL=0
APP_BUNDLE="build/Kimchi Companion.app"
DMG_PATH="build/KimchiCompanion.dmg"

check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✅ PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $label"
        FAIL=$((FAIL + 1))
    fi
}

check_output() {
    local label="$1"
    local expected="$2"
    shift 2
    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | grep -q "$expected"; then
        echo "  ✅ PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $label (got: $output)"
        FAIL=$((FAIL + 1))
    fi
}

# ── Build if needed ───────────────────────────────────────────────
if [ ! -f "$DMG_PATH" ]; then
    echo "→ DMG not found, running package-app.sh..."
    bash scripts/package-app.sh
    echo ""
fi

# ── Bundle structure ──────────────────────────────────────────────
echo "Bundle Structure:"
check "Contents/Info.plist exists" test -f "$APP_BUNDLE/Contents/Info.plist"
check "Contents/MacOS/KimchiCompanion exists" test -f "$APP_BUNDLE/Contents/MacOS/KimchiCompanion"
check "Contents/PkgInfo exists" test -f "$APP_BUNDLE/Contents/PkgInfo"
echo ""

# ── Info.plist keys ───────────────────────────────────────────────
echo "Info.plist Keys:"

plist_val() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null
}

check_plist() {
    local label="$1"
    local key="$2"
    local expected="$3"
    local actual
    actual=$(plist_val "$key")
    if [ "$actual" = "$expected" ]; then
        echo "  ✅ PASS: $label ($actual)"
        PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $label (expected: $expected, got: $actual)"
        FAIL=$((FAIL + 1))
    fi
}

check_plist "LSUIElement is true" "LSUIElement" "true"
check_plist "CFBundleIdentifier" "CFBundleIdentifier" "com.castai.kimchi-companion"
check_plist "CFBundleExecutable" "CFBundleExecutable" "KimchiCompanion"
check_plist "LSMinimumSystemVersion" "LSMinimumSystemVersion" "14.0"
echo ""

# ── Universal binary ─────────────────────────────────────────────
echo "Universal Binary:"
ARCHS=$(lipo -archs "$APP_BUNDLE/Contents/MacOS/KimchiCompanion" 2>&1)
check_output "arm64 architecture present" "arm64" echo "$ARCHS"
check_output "x86_64 architecture present" "x86_64" echo "$ARCHS"
echo "  Architectures: $ARCHS"
echo ""

# ── Code signing ──────────────────────────────────────────────────
echo "Code Signing:"
check "codesign --verify passes" codesign --verify --verbose "$APP_BUNDLE"
echo ""

# ── DMG ───────────────────────────────────────────────────────────
echo "DMG:"
check "DMG file exists" test -f "$DMG_PATH"
check "SHA256 file exists" test -f "$DMG_PATH.sha256"

# Mount and verify contents
echo "  Mounting DMG..."
MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -noverify 2>&1 | grep "/Volumes" | awk -F'\t' '{print $NF}')
if [ -n "$MOUNT_POINT" ]; then
    check "App exists inside DMG" test -d "$MOUNT_POINT/Kimchi Companion.app"
    echo "  Detaching DMG..."
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || hdiutil detach "$MOUNT_POINT" -force -quiet 2>/dev/null || true
else
    echo "  ❌ FAIL: Could not mount DMG"
    FAIL=$((FAIL + 1))
fi
echo ""

# ── Homebrew cask formula (T02 — skip if not present) ─────────────
if [ -f "homebrew/kimchi-companion.rb" ]; then
    echo "Homebrew Cask Formula:"
    check "Ruby syntax valid" ruby -c "homebrew/kimchi-companion.rb"
    echo ""
fi

# ── GitHub Actions workflow (T02 — skip if not present) ───────────
if [ -f ".github/workflows/release.yml" ]; then
    echo "GitHub Actions Workflow:"
    check "YAML syntax valid" python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"
    echo ""
fi

# ── Summary ───────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    echo "  All $TOTAL checks passed ✅"
else
    echo "  $PASS/$TOTAL passed, $FAIL failed ❌"
fi
echo "═══════════════════════════════════════════════════════"

exit "$FAIL"
