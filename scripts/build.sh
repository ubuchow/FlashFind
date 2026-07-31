#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "→ 编译 FlashFind (release)…"
swift build -c release
BIN="$ROOT/.build/release/FlashFind"
APP_DIR="$ROOT/dist/FlashFind.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN" "$MACOS_DIR/FlashFind"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"
chmod +x "$MACOS_DIR/FlashFind"

# App 图标（纯代码生成，体积很小）
echo "→ 生成 AppIcon…"
ICONSET="$ROOT/.build/AppIcon.iconset"
ICNS="$RES_DIR/AppIcon.icns"
swift "$ROOT/scripts/generate_app_icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$ICNS" 2>/dev/null || {
  # iconutil 失败时至少放一张 512 png
  cp "$ICONSET/icon_512x512.png" "$RES_DIR/AppIcon.png" 2>/dev/null || true
}
# 写入 Info 图标名
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_DIR/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
fi
echo "→ 已构建: $APP_DIR"
du -sh "$APP_DIR" "$MACOS_DIR/FlashFind"
ls -lh "$ICNS" 2>/dev/null || true
