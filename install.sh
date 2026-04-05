#!/bin/bash
# ============================================
# WHU WiFi 自动登录 - 一键安装脚本
# ============================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="whu-wifi-login.sh"
PLIST_NAME="com.whu.wifi-login.plist"
PLIST_DIR="$HOME/Library/LaunchAgents"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  WHU WiFi 自动登录 - 安装程序${NC}"
echo -e "${CYAN}========================================${NC}\n"

# 1. 复制脚本
echo -e "${GREEN}[1/4]${NC} 安装脚本到 $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
cp "$(dirname "$0")/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# 2. 提示填写账号
echo -e "${GREEN}[2/4]${NC} 配置账号信息..."
read -rp "请输入学号: " student_id
read -rsp "请输入密码: " student_pwd
echo ""

echo -e "选择网络类型:"
echo "  0) 校园网 / CERNET（默认）"
echo "  1) 电信"
echo "  2) 联通"
echo "  3) 移动"
read -rp "请选择 [0-3]: " net_choice

case "$net_choice" in
    1) service="dianxin" ;;
    2) service="liantong" ;;
    3) service="yidong" ;;
    *) service="" ;;
esac

# 写入账号（使用 sed 替换占位符）
sed -i '' "s/^USER_ID=\"\"/USER_ID=\"$student_id\"/" "$INSTALL_DIR/$SCRIPT_NAME"
sed -i '' "s/^PASSWORD=\"\"/PASSWORD=\"$student_pwd\"/" "$INSTALL_DIR/$SCRIPT_NAME"
if [[ -n "$service" ]]; then
    sed -i '' "s/^SERVICE=\"\"/SERVICE=\"$service\"/" "$INSTALL_DIR/$SCRIPT_NAME"
fi

# 3. 安装 launchd 开机自启
echo -e "${GREEN}[3/4]${NC} 配置开机自启动..."

# 先卸载旧的（如果有）
launchctl unload "$PLIST_DIR/$PLIST_NAME" 2>/dev/null || true

cat > "$PLIST_DIR/$PLIST_NAME" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.whu.wifi-login</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${INSTALL_DIR}/${SCRIPT_NAME}</string>
    </array>
    <key>StartInterval</key>
    <integer>30</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.whu-wifi-login.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.whu-wifi-login.log</string>
    <key>WatchPaths</key>
    <array>
        <string>/Library/Preferences/SystemConfiguration/com.apple.network.identification.plist</string>
    </array>
</dict>
</plist>
EOF

launchctl load "$PLIST_DIR/$PLIST_NAME"

# 4. 完成
echo -e "${GREEN}[4/4]${NC} 安装完成！\n"
echo -e "${CYAN}========================================${NC}"
echo -e "  脚本位置:  $INSTALL_DIR/$SCRIPT_NAME"
echo -e "  日志文件:  ~/.whu-wifi-login.log"
echo -e ""
echo -e "  手动登录:  $SCRIPT_NAME"
echo -e "  查看状态:  $SCRIPT_NAME status"
echo -e "  守护模式:  $SCRIPT_NAME daemon"
echo -e ""
echo -e "  停用自启:  launchctl unload ~/Library/LaunchAgents/$PLIST_NAME"
echo -e "  重新启用:  launchctl load  ~/Library/LaunchAgents/$PLIST_NAME"
echo -e "${CYAN}========================================${NC}"
