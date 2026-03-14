#!/bin/bash
# ─── SoulEyes Installer ───
# Builds, installs, and sets up auto-start on macOS
# Run: ./install.sh

set -euo pipefail

BOLD='\033[1m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
DIM='\033[2m'
RESET='\033[0m'

BINARY="/usr/local/bin/SoulEyes"
PLIST_NAME="com.proxysoul.souleyes"
PLIST_SRC="$(cd "$(dirname "$0")" && pwd)/com.proxysoul.souleyes.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
SWIFT_SRC="$(cd "$(dirname "$0")" && pwd)/SoulEyes.swift"

echo ""
echo -e "${PURPLE}${BOLD}  👁  SoulEyes Installer${RESET}"
echo -e "${DIM}  by proxySoul — 20-20-20 eye protection${RESET}"
echo ""

# ── Stop existing instance ──
if launchctl list 2>/dev/null | grep -q "$PLIST_NAME"; then
    echo -e "  ${DIM}Stopping existing SoulEyes...${RESET}"
    launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
    sleep 1
fi

# Kill any stray process
pkill -f "/usr/local/bin/SoulEyes" 2>/dev/null || true
pkill -f "SoulEyes$" 2>/dev/null || true
sleep 0.5

# ── Build ──
echo -e "  ${PURPLE}▸${RESET} Building (optimized)..."
swiftc -O -o /tmp/SoulEyes "$SWIFT_SRC" -framework Cocoa -framework QuartzCore
echo -e "  ${GREEN}✓${RESET} Built — $(du -h /tmp/SoulEyes | awk '{print $1}')"

# ── Install binary ──
echo -e "  ${PURPLE}▸${RESET} Installing to $BINARY..."
sudo cp /tmp/SoulEyes "$BINARY"
sudo chmod 755 "$BINARY"
rm /tmp/SoulEyes
echo -e "  ${GREEN}✓${RESET} Binary installed"

# ── Install LaunchAgent ──
echo -e "  ${PURPLE}▸${RESET} Setting up auto-start..."
mkdir -p "$HOME/Library/LaunchAgents"
cp "$PLIST_SRC" "$PLIST_DST"
echo -e "  ${GREEN}✓${RESET} LaunchAgent installed"

# ── Load and start ──
echo -e "  ${PURPLE}▸${RESET} Starting SoulEyes..."
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
echo -e "  ${GREEN}✓${RESET} Running!"

echo ""
echo -e "  ${GREEN}${BOLD}Done!${RESET} SoulEyes is now:"
echo -e "    • Running in your menu bar ${DIM}(👁 with countdown)${RESET}"
echo -e "    • Auto-starts on login"
echo -e "    • Auto-restarts if crashed"
echo -e "    • Pauses on sleep/lock, resets on wake"
echo ""
echo -e "  ${DIM}To uninstall: ./uninstall.sh${RESET}"
echo ""