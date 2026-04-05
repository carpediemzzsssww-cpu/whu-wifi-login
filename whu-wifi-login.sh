#!/bin/bash
# ============================================
# 武汉大学校园网自动登录脚本
# WiFi: WHU-STU / WHU-STU-5G
# 认证系统: 锐捷 ePortal (172.19.1.9:8080)
#
# 用法:
#   ./whu-wifi-login.sh          手动登录一次
#   ./whu-wifi-login.sh daemon    后台守护模式（每30秒检测，掉线自动重连）
#   ./whu-wifi-login.sh status    查看当前网络状态
# ============================================

# ====== 在这里填写你的账号信息 ======
USER_ID=""          # 你的学号
PASSWORD=""         # 你的密码
SERVICE=""      # 网络类型: 留空=校园网(CERNET), dianxin=电信, liantong=联通, yidong=移动
# ===================================

PORTAL="http://172.19.1.9:8080"
LOGIN_URL="$PORTAL/eportal/InterFace.do?method=login"
CHECK_URL="http://connect.rom.miui.com/generate_204"
LOG_FILE="$HOME/.whu-wifi-login.log"
LOG_MAX_LINES=500

# 通用 curl 参数：绕过 VPN 代理 + 绑定 WiFi 接口
CURL_OPTS="--noproxy * --max-time 5"

# 日志自动清理：超过上限只保留最近的记录
if [[ -f "$LOG_FILE" ]] && (( $(wc -l < "$LOG_FILE") > LOG_MAX_LINES )); then
    tail -200 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

# 获取 WiFi 接口名（macOS 通常是 en0）
WIFI_INTERFACE=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2}')
WIFI_INTERFACE=${WIFI_INTERFACE:-en0}

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数：同时输出到终端和日志文件
log_info()  { echo -e "${GREEN}[✓]${NC} $(date '+%H:%M:%S') $1"; echo "[✓] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }
log_error() { echo -e "${RED}[✗]${NC} $(date '+%H:%M:%S') $1"; echo "[✗] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $(date '+%H:%M:%S') $1"; echo "[!] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }
log_debug() { echo "[~] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }

# 检查是否已填写账号
check_credentials() {
    if [[ -z "$USER_ID" || -z "$PASSWORD" ]]; then
        log_error "请先编辑脚本，填写 USER_ID 和 PASSWORD"
        exit 1
    fi
}

# 获取当前 WiFi SSID（兼容新版 macOS）
get_ssid() {
    # 优先用 ipconfig（快速且可靠）
    local ssid
    ssid=$(ipconfig getsummary "$WIFI_INTERFACE" 2>/dev/null | awk -F' : ' '/  SSID /{print $2}')
    if [[ -n "$ssid" ]]; then
        echo "$ssid"
        return
    fi
    # 备选方案
    networksetup -getairportnetwork "$WIFI_INTERFACE" 2>/dev/null | sed 's/Current Wi-Fi Network: //'
}

# 检查是否连接武大 WiFi
is_whu_wifi() {
    local ssid
    ssid=$(get_ssid)
    [[ "$ssid" == "WHU-STU" || "$ssid" == "WHU-STU-5G" ]]
}

# 检查网络是否已认证（绕过 VPN 代理，直接走 WiFi 接口）
is_authenticated() {
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' --interface "$WIFI_INTERFACE" --noproxy '*' --max-time 5 "$CHECK_URL" 2>/dev/null)
    if [[ "$code" == "204" ]]; then
        return 0
    fi
    # 备用检测
    code=$(curl -s -o /dev/null -w '%{http_code}' --interface "$WIFI_INTERFACE" --noproxy '*' --max-time 5 "http://www.msftconnecttest.com/connecttest.txt" 2>/dev/null)
    [[ "$code" == "200" ]]
}

# 等待 WiFi 接口获得有效 IP（DHCP 可能还没完成）
wait_for_ip() {
    local i ip
    for i in 1 2 3 4 5; do
        ip=$(ipconfig getifaddr "$WIFI_INTERFACE" 2>/dev/null)
        if [[ -n "$ip" && "$ip" != "169."* ]]; then
            log_debug "WiFi 接口 IP: $ip"
            return 0
        fi
        sleep 2
    done
    log_warn "等待 IP 分配超时"
    return 1
}

# 获取 WiFi 接口的 DNS 服务器
get_wifi_dns() {
    local dns
    dns=$(ipconfig getsummary "$WIFI_INTERFACE" 2>/dev/null | awk '/ServerAddresses/{found=1; next} found && /[0-9]+\.[0-9]+/{gsub(/[^0-9.]/, "", $0); print; exit}')
    echo "${dns:-172.19.1.9}"
}

# 执行登录
do_login() {
    # 确保 WiFi 接口有有效 IP
    wait_for_ip || return 1

    local redirect_body query_string redirect_url response error_msg
    local wifi_ip dns_server

    wifi_ip=$(ipconfig getifaddr "$WIFI_INTERFACE" 2>/dev/null)
    dns_server=$(get_wifi_dns)
    log_debug "WiFi IP: $wifi_ip, DNS: $dns_server"

    # 方法1: 直接用 WiFi 接口的 IP 构造 queryString（最可靠，不依赖重定向）
    if [[ -n "$wifi_ip" ]]; then
        query_string="wlanuserip=${wifi_ip}&wlanacname=&wlanacip="
        query_string=$(echo "$query_string" | sed 's/&/%2526/g; s/=/%253D/g')
        log_debug "使用本机 IP 构造 queryString"
    fi

    # 方法2: 如果方法1失败再尝试通过重定向获取
    if [[ -z "$query_string" ]]; then
        redirect_body=$(curl -s --interface "$WIFI_INTERFACE" --noproxy '*' --max-time 5 \
            "http://baidu.com" 2>/dev/null)
        query_string=$(echo "$redirect_body" | grep -oE "wlanuserip=[^'\"]*" | head -1 | sed 's/&/%2526/g; s/=/%253D/g')
    fi

    if [[ -z "$query_string" ]]; then
        redirect_url=$(curl -s -o /dev/null -w '%{redirect_url}' --interface "$WIFI_INTERFACE" --noproxy '*' --max-time 5 \
            "http://baidu.com" 2>/dev/null)
        query_string=$(echo "$redirect_url" | grep -oE '\?.*' | sed 's/^?//' | sed 's/&/%2526/g; s/=/%253D/g')
    fi

    if [[ -z "$query_string" ]]; then
        log_error "无法获取认证参数 (WiFi IP: ${wifi_ip:-无})"
        return 1
    fi

    response=$(curl -s -X POST "$LOGIN_URL" \
        --interface "$WIFI_INTERFACE" --noproxy '*' \
        -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
        --data-urlencode "userId=$USER_ID" \
        --data-urlencode "password=$PASSWORD" \
        --data-urlencode "service=$SERVICE" \
        --data-urlencode "queryString=$query_string" \
        --data-urlencode "operatorPwd=" \
        --data-urlencode "operatorUserId=" \
        --data-urlencode "validcode=" \
        --data-urlencode "passwordEncrypt=false" \
        --max-time 10 2>/dev/null)

    if echo "$response" | grep -q '"result":"success"'; then
        log_info "登录成功！"
        return 0
    elif echo "$response" | grep -q '设备未注册'; then
        # 设备未注册 = IP 可能还没在网关注册，等几秒再试
        log_warn "设备未注册，等待网关同步..."
        sleep 3
        # 刷新 IP 后重试
        wifi_ip=$(ipconfig getifaddr "$WIFI_INTERFACE" 2>/dev/null)
        query_string="wlanuserip=${wifi_ip}&wlanacname=&wlanacip="
        query_string=$(echo "$query_string" | sed 's/&/%2526/g; s/=/%253D/g')
        response=$(curl -s -X POST "$LOGIN_URL" \
            --interface "$WIFI_INTERFACE" \
            -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
            -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
            --data-urlencode "userId=$USER_ID" \
            --data-urlencode "password=$PASSWORD" \
            --data-urlencode "service=$SERVICE" \
            --data-urlencode "queryString=$query_string" \
            --data-urlencode "operatorPwd=" \
            --data-urlencode "operatorUserId=" \
            --data-urlencode "validcode=" \
            --data-urlencode "passwordEncrypt=false" \
            --max-time 10 2>/dev/null)
        if echo "$response" | grep -q '"result":"success"'; then
            log_info "登录成功！(重试)"
            return 0
        fi
        error_msg=$(echo "$response" | grep -oE '"message":"[^"]*"' | sed 's/"message":"//;s/"//')
        log_error "登录失败(重试): ${error_msg:-$response}"
        return 1
    else
        error_msg=$(echo "$response" | grep -oE '"message":"[^"]*"' | sed 's/"message":"//;s/"//')
        log_error "登录失败: ${error_msg:-$response}"
        return 1
    fi
}

# ====== 单次登录模式 ======
run_once() {
    check_credentials

    local ssid
    ssid=$(get_ssid)
    if ! is_whu_wifi; then
        # 如果刚唤醒，WiFi 可能还没连上，等一下
        sleep 2
        ssid=$(get_ssid)
        if ! is_whu_wifi; then
            log_error "当前WiFi: ${ssid:-未连接}，不是武大校园网"
            exit 1
        fi
    fi
    log_info "已连接 WiFi: $ssid"

    if is_authenticated; then
        log_info "网络已认证，无需重复登录"
        exit 0
    fi

    log_warn "网络未认证，正在登录..."
    do_login
}

# ====== 守护进程模式 ======
run_daemon() {
    check_credentials

    local check_interval=30   # 每 30 秒检测一次
    local fail_count=0

    echo -e "${CYAN}[守护模式]${NC} 每 ${check_interval}s 检测校园网状态，掉线自动重连"
    echo -e "${CYAN}[守护模式]${NC} 日志文件: $LOG_FILE"
    echo -e "${CYAN}[守护模式]${NC} 按 Ctrl+C 停止\n"
    log_info "守护模式启动"

    while true; do
        if ! is_whu_wifi; then
            log_debug "未连接武大WiFi，跳过检测"
            fail_count=0
            sleep "$check_interval"
            continue
        fi

        if is_authenticated; then
            log_debug "网络正常"
            fail_count=0
        else
            fail_count=$((fail_count + 1))
            log_warn "检测到掉线（第 ${fail_count} 次），正在重新认证..."
            if do_login; then
                fail_count=0
                # macOS 通知
                osascript -e 'display notification "校园网掉线已自动重连" with title "WHU WiFi"' 2>/dev/null
            else
                if [[ $fail_count -ge 5 ]]; then
                    log_error "连续失败 ${fail_count} 次，等待 60 秒后重试"
                    sleep 60
                    continue
                fi
            fi
        fi

        sleep "$check_interval"
    done
}

# ====== 状态查看 ======
run_status() {
    local ssid
    ssid=$(get_ssid)
    echo -e "${CYAN}WiFi 接口:${NC}  $WIFI_INTERFACE"
    echo -e "${CYAN}当前 SSID:${NC}  ${ssid:-未连接}"

    if is_whu_wifi; then
        if is_authenticated; then
            echo -e "${CYAN}认证状态:${NC}  ${GREEN}已认证${NC}"
        else
            echo -e "${CYAN}认证状态:${NC}  ${RED}未认证${NC}"
        fi
    else
        echo -e "${CYAN}认证状态:${NC}  ${YELLOW}非武大网络${NC}"
    fi

    if [[ -f "$LOG_FILE" ]]; then
        echo -e "\n${CYAN}最近日志:${NC}"
        tail -5 "$LOG_FILE"
    fi
}

# ====== 主入口 ======
case "${1:-}" in
    daemon)  run_daemon ;;
    status)  run_status ;;
    *)       run_once ;;
esac
