#!/bin/bash
# ============================================
# WHU WiFi 自动登录 - 卸载脚本
# ============================================

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="whu-wifi-login.sh"
PLIST_NAME="com.whu.wifi-login.plist"
PLIST_DIR="$HOME/Library/LaunchAgents"

echo "正在卸载 WHU WiFi 自动登录..."

# 停用 launchd
launchctl unload "$PLIST_DIR/$PLIST_NAME" 2>/dev/null
rm -f "$PLIST_DIR/$PLIST_NAME"
echo "[✓] 已移除开机自启"

# 删除脚本
rm -f "$INSTALL_DIR/$SCRIPT_NAME"
echo "[✓] 已删除脚本"

# 删除日志
rm -f "$HOME/.whu-wifi-login.log"
echo "[✓] 已清理日志"

echo ""
echo "卸载完成！"
