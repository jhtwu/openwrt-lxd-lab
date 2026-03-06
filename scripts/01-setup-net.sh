#!/bin/bash
# scripts/01-setup-net.sh: 建立網橋

# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

info "Initializing Network Bridges..."

setup_bridge() {
    local bridge="$1"
    if ip link show "$bridge" > /dev/null 2>&1; then
        warn "Bridge $bridge already exists. Skipping..."
    else
        info "Creating bridge $bridge..."
        sudo ip link add "$bridge" type bridge || error "Failed to create $bridge"
        sudo ip link set "$bridge" up || error "Failed to set $bridge up"
        print_status "Bridge $bridge" "CREATED"
    fi
}

setup_bridge "$BRIDGE_WAN"
setup_bridge "$BRIDGE_LAN"

# 確保 LXD 可以使用網橋
# 若要讓容器互連，LXD 需對網橋有控制權（可選擇性加入 bridge 宣告）
info "Network bridges setup completed."
