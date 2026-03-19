#!/usr/bin/env bash
set -euo pipefail

echo "=== S02 Verification: API Key Setup & Keychain ==="
echo ""

# 1. Build
echo "▸ Building..."
swift build 2>&1
echo "✅ Build succeeded"
echo ""

# 2. Print manual verification checklist
cat <<'EOF'
Manual verification checklist:
────────────────────────────────────────────────────────
[ ] Fresh launch → popover shows "Enter your CAST AI API key" setup view
[ ] Paste an invalid key → click "Validate & Save" → error "Invalid API key" shown
[ ] Paste a valid CAST AI API key → click "Validate & Save" → loading indicator → "Connected to CAST AI" shown
[ ] Quit app (click "Quit Kimchi Companion") and relaunch → setup view is skipped, connected placeholder shown
[ ] Run: security delete-generic-password -s "com.kimchicompanion.api-key"
    Then relaunch → setup view shown again
────────────────────────────────────────────────────────

Launching app now...
EOF

echo ""
.build/debug/KimchiCompanion
