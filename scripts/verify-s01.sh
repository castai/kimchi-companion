#!/usr/bin/env bash
set -euo pipefail

echo "=== Kimchi Companion — S01 Verification ==="
echo ""
echo "Building..."
swift build 2>&1
echo ""
echo "✓ Build succeeded"
echo ""
echo "Launching app... Press Ctrl+C to quit."
echo ""
echo "Verify the following:"
echo "  [ ] SF Symbol (dollarsign.circle) + \$0.00 text visible in menu bar"
echo "  [ ] Click the menu bar icon → popover window opens"
echo "  [ ] No Dock icon or Cmd+Tab entry for the app"
echo "  [ ] Click 'Toggle Cost' → menu bar text changes to \$12.34"
echo "  [ ] Click 'Toggle Cost' again → text reverts to \$0.00"
echo "  [ ] Click 'Quit Kimchi Companion' → app terminates"
echo ""

.build/debug/KimchiCompanion
