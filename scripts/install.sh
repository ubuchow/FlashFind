#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"

DEST_DIR="$HOME/Applications"
APP_SRC="$ROOT/dist/FlashFind.app"
APP_DST="$DEST_DIR/FlashFind.app"
# 清理旧名
rm -rf "$DEST_DIR/秒搜.app" "$DEST_DIR/QuickQuickSearch.app"
pkill -x FlashFind 2>/dev/null || true

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/com.local.FlashFind.plist"
# 旧 launch agent
launchctl bootout "gui/$(id -u)/com.local.FlashFind" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/com.local.QuickQuickSearch" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.local.FlashFind.plist"
rm -f "$HOME/Library/LaunchAgents/com.local.QuickQuickSearch.plist"

mkdir -p "$DEST_DIR" "$LAUNCH_AGENTS"
sleep 0.2
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"
xattr -cr "$APP_DST" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DST" 2>/dev/null || true

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.local.FlashFind</string>
	<key>ProgramArguments</key>
	<array>
		<string>${APP_DST}/Contents/MacOS/FlashFind</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<false/>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.local.FlashFind" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null || true

sleep 0.3
if ! pgrep -x FlashFind >/dev/null 2>&1; then
  "${APP_DST}/Contents/MacOS/FlashFind" &
fi

echo ""
echo "✓ 已安装: $APP_DST"
echo "✓ 登录自启"
echo ""
echo "FlashFind"
echo "  • 菜单栏精致放大镜图标"
echo "  • ⌃⌥Space 唤起（带弹出动画）"
echo "  • 界面字体：宋体-简 粗体"
echo ""
