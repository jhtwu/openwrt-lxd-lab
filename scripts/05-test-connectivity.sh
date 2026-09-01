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
failures=0
iperf3_tmp_files=()

cleanup_iperf3_files() {
    local file
    for file in "${iperf3_tmp_files[@]}"; do
        rm -f "$file"
    done
}
trap cleanup_iperf3_files EXIT

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

ensure_iperf3() {
    local container="$1"

    if lxc exec "$container" -- sh -c 'command -v iperf3 >/dev/null 2>&1' >/dev/null 2>&1; then
        return 0
    fi

    info "iperf3 is missing in $container; installing it..."

    if [ "$container" = "$CTR_LAN_HOST" ]; then
        # LAN traffic prefers the lab gateway, which intentionally has no
        # Internet uplink. Temporarily use the LXD management route for apk.
        lxc exec "$container" -- sh -c "
            set -e
            ip route del default via '$LAN_IP_ROUTER' dev '$CIF_LAN' 2>/dev/null || true
            restore_route() {
                ip route replace default via '$LAN_IP_ROUTER' dev '$CIF_LAN'
            }
            trap restore_route EXIT
            apk add --no-cache iperf3
        " || error "Failed to install iperf3 in $container"
    else
        lxc exec "$container" -- apk add --no-cache iperf3 \
            || error "Failed to install iperf3 in $container"
    fi
}

bits_to_bps() {
    local value="$1"
    local unit="$2"
    local multiplier

    case "$unit" in
        bits/sec) multiplier=1 ;;
        Kbits/sec) multiplier=1000 ;;
        Mbits/sec) multiplier=1000000 ;;
        Gbits/sec) multiplier=1000000000 ;;
        *) return 1 ;;
    esac

    awk -v value="$value" -v multiplier="$multiplier" \
        'BEGIN { printf "%.0f", value * multiplier }'
}

test_iperf3() {
    local label="$1"
    local reverse="$2"
    local client_output
    local client_status
    local server_status
    local server_log
    local rate_line
    local rate_value
    local rate_unit
    local rate_bps
    local -a client_args=()

    echo -e "\n${BLUE}[$label]${NC}"
    echo -e "  ${YELLOW}${CTR_LAN_HOST}${NC} ${ARROW} ${GREEN}OpenWrt router${NC} ${ARROW} ${YELLOW}${CTR_WAN_HOST}${NC}"

    if [ "$reverse" -eq 1 ]; then
        client_args=(-R)
        echo "  Direction: RX (wan-host -> lan-host)"
    else
        echo "  Direction: TX (lan-host -> wan-host)"
    fi

    server_log=$(mktemp)
    iperf3_tmp_files+=("$server_log")
    timeout "$((IPERF3_DURATION + 10))" \
        lxc exec "$CTR_WAN_HOST" -- iperf3 -s -1 > "$server_log" 2>&1 &
    local server_pid=$!
    sleep 1

    client_output=$(lxc exec "$CTR_LAN_HOST" -- iperf3 -c "$WAN_IP_HOST" \
        "${client_args[@]}" -t "$IPERF3_DURATION" -f m 2>&1)
    client_status=$?
    wait "$server_pid"
    server_status=$?

    echo "$client_output" | awk '/sender$/ {print "  " $0}'

    if [ "$client_status" -ne 0 ] || [ "$server_status" -ne 0 ]; then
        echo -e "  [ \033[0;31m✘ iperf3 execution failed\033[0m ]"
        failures=$((failures + 1))
        return 0
    fi

    rate_line=$(printf '%s\n' "$client_output" | awk '$NF == "sender" {print $(NF-3), $(NF-2); exit}')
    rate_value=$(printf '%s' "$rate_line" | awk '{print $1}')
    rate_unit=$(printf '%s' "$rate_line" | awk '{print $2}')
    rate_bps=$(bits_to_bps "$rate_value" "$rate_unit") || {
        echo -e "  [ \033[0;31m✘ Could not parse throughput\033[0m ]"
        failures=$((failures + 1))
        return 0
    }

    if [ "$rate_bps" -ge "$IPERF3_MIN_BPS" ]; then
        echo -e "  [ ${GREEN}✔ THROUGHPUT OK${NC} ] (${rate_value} ${rate_unit})"
    else
        echo -e "  [ \033[0;31m✘ BELOW THRESHOLD\033[0m ] (${rate_value} ${rate_unit}, minimum ${IPERF3_MIN_BPS} bit/s)"
        failures=$((failures + 1))
    fi
}

# 1. LAN 內部測試
if ! test_ping_visual "$CTR_LAN_HOST" "$LAN_IP_HOST" "$CIF_LAN" \
                    "$CTR_ROUTER" "$LAN_IP_ROUTER" "$CIF_LAN" \
                    "Test 1: Internal LAN Connection"; then
    failures=$((failures + 1))
fi

# 2. WAN 內部測試
if ! test_ping_visual "$CTR_WAN_HOST" "$WAN_IP_HOST" "$CIF_WAN" \
                    "$CTR_ROUTER" "$WAN_IP_ROUTER" "$CIF_WAN" \
                    "Test 2: External WAN Connection"; then
    failures=$((failures + 1))
fi

# 3. 跨區段轉發測試 (End-to-End)
echo -e "\n${BLUE}[Test 3: Cross-Zone Routing (LAN to WAN Host)]${NC}"
echo -e "  ${YELLOW}${CTR_LAN_HOST}${NC} ($LAN_IP_HOST) ${ARROW} ${GREEN}Router${NC} ${ARROW} ${YELLOW}${CTR_WAN_HOST}${NC} ($WAN_IP_HOST)"
echo -n "  Traversing Firewall/NAT "
for _ in {1..3}; do echo -n "."; sleep 0.2; done

if lxc exec "$CTR_LAN_HOST" -- ping -c 2 -W 1 "$WAN_IP_HOST" > /dev/null 2>&1; then
    echo -e " [ ${GREEN}${CHECK} ROUTING OK${NC} ]"
else
    echo -e " [ \033[0;31m✘ FORWARDING BLOCKED\033[0m ]"
    failures=$((failures + 1))
fi

# 4. 路由路徑追蹤
echo -e "\n${BLUE}[Diagnostic: Traceroute Mapping]${NC}"
lxc exec "$CTR_LAN_HOST" -- traceroute -n -m 5 "$WAN_IP_HOST" 2>/dev/null | tail -n +2 | while read -r line; do
    if [ -n "$line" ]; then
        echo -e "  Hop: ${GREEN}$line${NC}"
    fi
done

# 5. iperf3 throughput tests (one run per direction)
ensure_iperf3 "$CTR_WAN_HOST"
ensure_iperf3 "$CTR_LAN_HOST"
test_iperf3 "Test 5: Throughput TX" 0
test_iperf3 "Test 6: Throughput RX" 1

if [ "$failures" -ne 0 ]; then
    error "${failures} connectivity test(s) failed."
fi

info "=========================================================="
info "   ✅ All functional tests finished.                      "
info "=========================================================="
