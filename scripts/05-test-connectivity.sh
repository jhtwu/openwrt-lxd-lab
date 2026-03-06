#!/bin/bash
# scripts/05-test-connectivity.sh: 視覺化連通性測試

# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

# 定義顏色與符號
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
ARROW="---▶"
CHECK="✔"

info "=========================================================="
info "   🚀 OpenWrt Lab: Visual Connectivity Test Start         "
info "=========================================================="

test_ping_visual() {
    local src_name="$1"
    local src_ip="$2"
    local src_if="$3"
    local target_name="$4"
    local target_ip="$5"
    local target_if="$6"
    local label="$7"

    echo -e "\n${BLUE}[$label]${NC}"
    echo -e "  ${YELLOW}${src_name}${NC} ($src_ip) [$src_if] ${ARROW} ${YELLOW}${target_name}${NC} ($target_ip) [$target_if]"
    
    # 動態模擬點點點 (模擬傳輸感)
    echo -n "  Sending ICMP Packets "
    for _ in {1..3}; do echo -n "."; sleep 0.2; done
    
    if lxc exec "$src_name" -- ping -c 2 -W 1 "$target_ip" > /dev/null 2>&1; then
        echo -e " [ ${GREEN}${CHECK} SUCCESS${NC} ]"
        return 0
    else
        echo -e " [ \033[0;31m✘ FAILED\033[0m ]"
        return 1
    fi
}

# 1. LAN 內部測試
test_ping_visual "$CTR_LAN_HOST" "$LAN_IP_HOST" "$CIF_LAN" \
                 "$CTR_ROUTER" "$LAN_IP_ROUTER" "$CIF_LAN" \
                 "Test 1: Internal LAN Connection"

# 2. WAN 內部測試
test_ping_visual "$CTR_WAN_HOST" "$WAN_IP_HOST" "$CIF_WAN" \
                 "$CTR_ROUTER" "$WAN_IP_ROUTER" "$CIF_WAN" \
                 "Test 2: External WAN Connection"

# 3. 跨區段轉發測試 (End-to-End)
echo -e "\n${BLUE}[Test 3: Cross-Zone Routing (LAN to WAN Host)]${NC}"
echo -e "  ${YELLOW}${CTR_LAN_HOST}${NC} ($LAN_IP_HOST) ${ARROW} ${GREEN}Router${NC} ${ARROW} ${YELLOW}${CTR_WAN_HOST}${NC} ($WAN_IP_HOST)"
echo -n "  Traversing Firewall/NAT "
for _ in {1..3}; do echo -n "."; sleep 0.2; done

if lxc exec "$CTR_LAN_HOST" -- ping -c 2 -W 1 "$WAN_IP_HOST" > /dev/null 2>&1; then
    echo -e " [ ${GREEN}${CHECK} ROUTING OK${NC} ]"
else
    echo -e " [ \033[0;31m✘ FORWARDING BLOCKED\033[0m ]"
fi

# 4. 路由路徑追蹤
echo -e "\n${BLUE}[Diagnostic: Traceroute Mapping]${NC}"
lxc exec "$CTR_LAN_HOST" -- traceroute -n -m 5 "$WAN_IP_HOST" 2>/dev/null | tail -n +2 | while read -r line; do
    hop=$(echo "$line" | awk '{print $1}')
    ip=$(echo "$line" | awk '{print $2}')
    time=$(echo "$line" | awk '{print $4}')
    echo -e "  Hop $hop: ${GREEN}$ip${NC} ($time ms)"
done

info "=========================================================="
info "   ✅ All functional tests finished.                      "
info "=========================================================="
