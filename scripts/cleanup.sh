#!/bin/bash
# scripts/cleanup.sh: 完全清除實驗室環境 (容器與網橋)

# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

info "=========================================="
info "   Cleaning up OpenWrt LXD Lab...         "
info "=========================================="

# 1. 刪除容器
cleanup_container() {
    local name="$1"
    if lxc info "$name" > /dev/null 2>&1; then
        info "Stopping and deleting container: $name"
        lxc stop "$name" --force > /dev/null 2>&1
        lxc delete "$name" > /dev/null 2>&1
        print_status "Container $name" "REMOVED"
    else
        warn "Container $name not found. Skipping..."
    fi
}

cleanup_container "$CTR_ROUTER"
cleanup_container "$CTR_WAN_HOST"
cleanup_container "$CTR_LAN_HOST"

# 2. 刪除網橋 (需要 sudo)
cleanup_bridge() {
    local bridge="$1"
    if ip link show "$bridge" > /dev/null 2>&1; then
        info "Removing bridge: $bridge"
        sudo ip link set "$bridge" down
        sudo ip link delete "$bridge" type bridge
        print_status "Bridge $bridge" "REMOVED"
    else
        warn "Bridge $bridge not found. Skipping..."
    fi
}

cleanup_bridge "$BRIDGE_WAN"
cleanup_bridge "$BRIDGE_LAN"

info "=========================================="
info "   Cleanup completed. System is clean.    "
info "=========================================="
