#!/bin/zsh
set -euo pipefail
pkill -x FlashFind 2>/dev/null || true
launchctl bootout "gui/$(id -u)/com.local.FlashFind" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/com.local.QuickQuickSearch" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.local.FlashFind.plist"
rm -f "$HOME/Library/LaunchAgents/com.local.QuickQuickSearch.plist"
rm -rf "$HOME/Applications/FlashFind.app"
rm -rf "$HOME/Applications/QuickQuickSearch.app"
rm -rf "$HOME/Applications/秒搜.app"
rm -rf "$HOME/Library/Application Support/FlashFind"
echo "✓ 已卸载 FlashFind"
