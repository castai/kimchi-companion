#!/usr/bin/env bash
set -euo pipefail

echo "=== S03 Verification: Usage Data Fetching & Caching ==="
echo ""

# 1. Build
echo "▸ Building..."
swift build 2>&1
echo "✅ Build succeeded"
echo ""

# 2. Run tests
echo "▸ Running tests..."
swift test 2>&1
echo "✅ Tests passed"
echo ""

# 3. Print manual verification checklist
cat <<'EOF'
Manual verification checklist:
────────────────────────────────────────────────────────
[ ] Step 1: Launch app with valid CAST AI API key configured
    → Menu bar shows a real dollar amount (not "$0.00")
    → Debug console shows [UsageStore] fetch start → fetch success

[ ] Step 2: Click menu bar icon to open popover
    → Popover shows today's cost prominently
    → "Refreshing…" indicator appears briefly during fetch
    → Debug console shows [CastAPIClient] GET requests + status 200

[ ] Step 3: Check cache file exists:
    cat ~/Library/Application\ Support/KimchiCompanion/usage-cache.json
    → Valid JSON with usage data, lastUpdated timestamp

[ ] Step 4: Kill network (one of these):
    networksetup -setairportpower en0 off
    — or add to /etc/hosts: 127.0.0.1 api.cast.ai
    → Wait for popover refresh to fail
    → Stale indicator (⚠️ yellow banner) appears
    → Menu bar icon appears dimmed (opacity 0.5)
    → Debug console shows [UsageStore] fetch failure

[ ] Step 5: Quit app and relaunch (still offline)
    → Cached data loads immediately (menu bar shows last-known cost)
    → Stale indicator shows (since data is from disk cache)
    → Debug console shows [UsageStore] cache read

[ ] Step 6: Restore network:
    networksetup -setairportpower en0 on
    — or remove /etc/hosts entry
    → Open popover → data refreshes
    → Stale indicator disappears
    → Debug console shows [UsageStore] fetch success

[ ] Step 7: Verify [UsageStore] and [CastAPIClient] log prefixes
    → No API key values appear in any log output
────────────────────────────────────────────────────────

Launching app now...
EOF

echo ""
.build/debug/KimchiCompanion
