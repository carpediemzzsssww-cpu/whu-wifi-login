# WHU WiFi Auto Login

[中文](#中文) | [English](#english)

---

## 中文

武汉大学校园网（WHU-STU / WHU-STU-5G）自动登录脚本，适用于 macOS。

### 解决什么问题？

连接武大校园网时，系统会弹出认证页面要求输入账号密码。如果不小心关掉了弹窗：
- 网络看似已连接，实际无法上网
- 弹窗不会再次出现，只能「忘记网络」重新连接
- 挂着 VPN 时，校园网认证容易超时断开，VPN 一起掉线

本脚本解决以上所有问题：
- **一条命令登录**，不用手动填表单
- **开机自动运行**，每 30 秒检测，掉线自动重连
- **VPN 友好**，绕过 VPN 直接通过 WiFi 接口检测和认证
- **macOS 通知**，重连成功时弹出提醒
- **日志自动清理**，不会无限增长

### 快速开始

#### 一键安装

```bash
git clone https://github.com/carpediemzzsssww-cpu/whu-wifi-login.git
cd whu-wifi-login
chmod +x install.sh
./install.sh
```

安装脚本会引导你输入学号和密码，自动配置开机启动。

#### 手动安装

1. 编辑 `whu-wifi-login.sh`，填写你的账号信息：

```bash
USER_ID="你的学号"
PASSWORD="你的密码"
SERVICE=""          # 留空=校园网, dianxin=电信, liantong=联通, yidong=移动
```

2. 复制脚本并赋予执行权限：

```bash
mkdir -p ~/.local/bin
cp whu-wifi-login.sh ~/.local/bin/
chmod +x ~/.local/bin/whu-wifi-login.sh
```

3. 测试运行：

```bash
~/.local/bin/whu-wifi-login.sh
```

### 使用方式

```bash
# 手动登录一次
whu-wifi-login.sh

# 查看当前网络状态
whu-wifi-login.sh status

# 前台守护模式（终端持续运行，每 30 秒检测）
whu-wifi-login.sh daemon
```

### 开机自启动（launchd）

`install.sh` 会自动配置。如需手动管理：

```bash
# 停用
launchctl unload ~/Library/LaunchAgents/com.whu.wifi-login.plist

# 启用
launchctl load ~/Library/LaunchAgents/com.whu.wifi-login.plist

# 查看日志
cat ~/.whu-wifi-login.log
```

### 卸载

```bash
./uninstall.sh
```

### iPhone 用户

弹窗划掉后，打开 Safari 访问 `http://172.19.1.9` 即可重新打开登录页。

也可以在「快捷指令」App 中创建快捷指令：
1. 添加「打开 URL」操作
2. URL 填 `http://172.19.1.9`
3. 添加到主屏幕，一键打开登录页

### 工作原理

1. 通过 `ipconfig getsummary en0` 检测当前是否连接 WHU-STU / WHU-STU-5G
2. 通过 `curl --interface en0` 绕过 VPN，直接走 WiFi 接口发送 HTTP 204 检测
3. 如果未认证，从门户重定向中提取 `queryString` 认证参数
4. 向锐捷 ePortal（`172.19.1.9:8080`）发送 POST 登录请求
5. 由 macOS launchd 每 30 秒调度，网络变化时也会立即触发

### 技术细节

| 项目 | 信息 |
|------|------|
| 认证系统 | 锐捷 ePortal Web Authentication |
| 认证网关 | `172.19.1.9:8080` |
| 登录接口 | `POST /eportal/InterFace.do?method=login` |
| 兼容性 | macOS 12+（使用 `ipconfig` 替代已废弃的 `airport` 命令）|

### 安全提示

- 密码以明文存储在本地脚本中，请确保文件权限为 `700`（仅自己可读）
- **不要将填写了密码的脚本上传到公开仓库**

---

## English

Auto-login script for Wuhan University campus WiFi (WHU-STU / WHU-STU-5G) on macOS.

### What problem does it solve?

When connecting to WHU campus WiFi, a captive portal pops up asking for credentials. If you accidentally dismiss it:
- The network appears connected but has no internet access
- The portal won't pop up again — you have to "Forget Network" and reconnect
- If you're using a VPN, the campus auth often times out, killing the VPN too

This script fixes all of the above:
- **One-command login** — no manual form filling
- **Auto-start on boot** — checks every 30 seconds, auto-reconnects on drop
- **VPN-friendly** — bypasses VPN by binding to the WiFi interface directly
- **macOS notifications** — alerts you when it auto-reconnects
- **Auto log rotation** — logs don't grow forever

### Quick Start

#### One-click Install

```bash
git clone https://github.com/carpediemzzsssww-cpu/whu-wifi-login.git
cd whu-wifi-login
chmod +x install.sh
./install.sh
```

The installer will prompt for your student ID and password, then set up auto-start.

#### Manual Install

1. Edit `whu-wifi-login.sh` with your credentials:

```bash
USER_ID="your_student_id"
PASSWORD="your_password"
SERVICE=""          # empty=CERNET, dianxin=China Telecom, liantong=Unicom, yidong=Mobile
```

2. Copy and make executable:

```bash
mkdir -p ~/.local/bin
cp whu-wifi-login.sh ~/.local/bin/
chmod +x ~/.local/bin/whu-wifi-login.sh
```

3. Test:

```bash
~/.local/bin/whu-wifi-login.sh
```

### Usage

```bash
# Login once
whu-wifi-login.sh

# Check current status
whu-wifi-login.sh status

# Daemon mode (foreground, checks every 30s)
whu-wifi-login.sh daemon
```

### Auto-start (launchd)

`install.sh` configures this automatically. Manual management:

```bash
# Disable
launchctl unload ~/Library/LaunchAgents/com.whu.wifi-login.plist

# Enable
launchctl load ~/Library/LaunchAgents/com.whu.wifi-login.plist

# View logs
cat ~/.whu-wifi-login.log
```

### Uninstall

```bash
./uninstall.sh
```

### iPhone Users

If the login popup is dismissed, open Safari and visit `http://172.19.1.9` to reopen the login page.

You can also create an iOS Shortcut:
1. Add an "Open URL" action
2. Set URL to `http://172.19.1.9`
3. Add to Home Screen for one-tap access

### How It Works

1. Detects WiFi SSID via `ipconfig getsummary en0`
2. Checks authentication by sending HTTP 204 probe through WiFi interface (`curl --interface en0`), bypassing VPN
3. If unauthenticated, extracts `queryString` from the portal redirect
4. Sends POST login request to Ruijie ePortal (`172.19.1.9:8080`)
5. Scheduled by macOS launchd every 30 seconds, also triggers on network changes

### Technical Details

| Item | Info |
|------|------|
| Auth System | Ruijie ePortal Web Authentication |
| Portal Gateway | `172.19.1.9:8080` |
| Login Endpoint | `POST /eportal/InterFace.do?method=login` |
| Compatibility | macOS 12+ (uses `ipconfig` instead of deprecated `airport` command) |

### Security Notes

- Credentials are stored in plain text in the local script — ensure file permissions are `700` (owner-only)
- **Never push a script containing your real credentials to a public repo**

---

## Acknowledgments / 致谢

Inspired by [WHU_captive_portal_login](https://github.com/duament/WHU_captive_portal_login) and [auto-whu-standard](https://github.com/7Ji/auto-whu-standard).

## License

MIT
