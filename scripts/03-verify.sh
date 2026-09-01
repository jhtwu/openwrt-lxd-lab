#!/bin/bash
# scripts/03-verify.sh: 視覺化架構驗證與精確狀態報告

# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

info "=========================================================="
info "   🔍 OpenWrt Lab: Infrastructure Architecture Report     "
info "=========================================================="

# 輔助函式
get_status_label() {
    if "$@"; then echo -e "${GREEN}[OK]${NC}"; else echo -e "\033[0;31m[FAILED]\033[0m"; fi
}
check_link() { ip link show master "$1" | grep -q "$2"; }
check_ctr() { lxc info "$1" | grep -q "Status: RUNNING"; }
check_router() {
    if [ "$ROUTER_MODE" = "ucosii" ]; then
        local pid
        [ -f "$PROJECT_ROOT/$QEMU_ROUTER_PID_FILE" ] || return 1
        pid=$(cat "$PROJECT_ROOT/$QEMU_ROUTER_PID_FILE")
        case "$pid" in
            ''|*[!0-9]*) return 1 ;;
        esac
        kill -0 "$pid" 2>/dev/null || return 1
        [ "$(basename "$(readlink -f "/proc/$pid/exe" 2>/dev/null)")" = "qemu-system-aarch64" ]
    else
        check_ctr "$CTR_ROUTER"
    fi
}

echo -e "\n${BOLD}1. LOGICAL TOPOLOGY MAPPING${NC}"
echo -e "----------------------------------------------------------"
echo -e "${CYAN}WAN Zone (${BRIDGE_WAN})${NC}"
echo -n "  ┣━ " && printf "%-12s" "$HIF_OWRT_WAN" && echo -n " ◀───▶ " && printf "%-15s" "$CTR_ROUTER" && echo -n " [${CIF_WAN}]  "
get_status_label check_link "$BRIDGE_WAN" "$HIF_OWRT_WAN"
echo -n "  ┗━ " && printf "%-12s" "$HIF_WAN_HOST" && echo -n " ◀───▶ " && printf "%-15s" "$CTR_WAN_HOST" && echo -n " [${CIF_WAN}]  "
get_status_label check_link "$BRIDGE_WAN" "$HIF_WAN_HOST"

echo -e "\n${CYAN}LAN Zone (${BRIDGE_LAN})${NC}"
echo -n "  ┣━ " && printf "%-12s" "$HIF_OWRT_LAN" && echo -n " ◀───▶ " && printf "%-15s" "$CTR_ROUTER" && echo -n " [${CIF_LAN}]  "
get_status_label check_link "$BRIDGE_LAN" "$HIF_OWRT_LAN"
echo -n "  ┗━ " && printf "%-12s" "$HIF_LAN_HOST" && echo -n " ◀───▶ " && printf "%-15s" "$CTR_LAN_HOST" && echo -n " [${CIF_LAN}]  "
get_status_label check_link "$BRIDGE_LAN" "$HIF_LAN_HOST"

echo -e "\n${BOLD}2. LIVE HOST BRIDGING (brctl show)${NC}"
echo -e "----------------------------------------------------------"
printf "${BLUE}%-15s %-20s %-10s %-15s${NC}\n" "bridge name" "bridge id" "STP" "interfaces"
for br in "$BRIDGE_WAN" "$BRIDGE_LAN"; do
    # 抓取第一行數據
    data=$(brctl show "$br" | sed -n '2p')
    br_name=$(echo "$data" | awk '{print $1}')
    br_id=$(echo "$data" | awk '{print $2}')
    br_stp=$(echo "$data" | awk '{print $3}')
    br_if=$(echo "$data" | awk '{print $4}')
    
    printf "${GREEN}%-15s${NC} %-20s %-10s %-15s\n" "$br_name" "$br_id" "$br_stp" "$br_if"
    
    # 抓取後續的介面行 (如果有的話)
    brctl show "$br" | sed -n '3,$p' | while read -r extra_if; do
        if [ -n "$extra_if" ]; then
            printf "%-15s %-20s %-10s ${YELLOW}%-15s${NC}\n" "" "" "" "$extra_if"
        fi
    done
done

echo -e "\n${BOLD}3. LIVE ROUTER/HOST STATUS${NC}"
echo -e "----------------------------------------------------------"
printf "${BLUE}%-18s | %-10s | %-20s${NC}\n" "NAME" "STATE" "IPV4"
echo -e "-------------------+------------+-------------------------"
if [ "$ROUTER_MODE" = "ucosii" ]; then
    if check_router; then
        printf "%-18s | %-10s | %-20s\n" "$CTR_ROUTER" "RUNNING" \
            "$LAN_IP_ROUTER (lan) $WAN_IP_ROUTER (wan)"
    else
        printf "%-18s | %-10s | %-20s\n" "$CTR_ROUTER" "STOPPED" "n/a"
    fi
    for ctr in "$CTR_WAN_HOST" "$CTR_LAN_HOST"; do
        status=$(lxc info "$ctr" | grep "Status:" | awk '{print $2}')
        ips=$(lxc list "$ctr" --format csv -c 4 | tr '\n' ' ' | sed 's/ $//')
        [ -z "$ips" ] && ips="n/a"
        printf "%-18s | %-10s | %-20s\n" "$ctr" "$status" "$ips"
    done
else
    for ctr in "$CTR_ROUTER" "$CTR_WAN_HOST" "$CTR_LAN_HOST"; do
        # 提取狀態與 IP
        status=$(lxc info "$ctr" | grep "Status:" | awk '{print $2}')
        # 提取所有 IP 並合併
        ips=$(lxc list "$ctr" --format csv -c 4 | tr '\n' ' ' | sed 's/ $//')
        [ -z "$ips" ] && ips="n/a"

        printf "%-18s | %-10s | %-20s\n" "$ctr" "$status" "$ips"
    done
fi
echo -e "----------------------------------------------------------"

if ! check_router; then
    error "Router is not running. Infrastructure verification failed."
fi

info "   ✅ Infrastructure verification completed.               "
info "=========================================================="
