#!/bin/bash
# ─── SoulEyes Uninstaller ───

set -euo pipefail

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
RESET='\033[0m'

PLIST_NAME="com.proxysoul.souleyes"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
BINARY="/usr/local/bin/SoulEyes"

echo ""
echo -e "  ${RED}${BOLD}👁  SoulEyes Uninstaller${RESET}"
echo ""

# Stop
if launchctl list 2>/dev/null | grep -q "$PLIST_NAME"; then
    echo -e "  ${DIM}Stopping...${RESET}"
    launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
fi
pkill -f "/usr/local/bin/SoulEyes" 2>/dev/null || true

# Remove files
[ -f "$PLIST_DST" ] && rm "$PLIST_DST" && echo -e "  ${GREEN}✓${RESET} Removed LaunchAgent"
[ -f "$BINARY" ] && sudo rm "$BINARY" && echo -e "  ${GREEN}✓${RESET} Removed binary"

echo ""
echo -e "  ${GREEN}${BOLD}SoulEyes uninstalled.${RESET} 👋"
echo ""