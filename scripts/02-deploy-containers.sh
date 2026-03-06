#!/bin/bash
# scripts/02-deploy-containers.sh: 建立 OpenWrt 與測試主機

# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

info "Initializing Containers Deployment..."

cleanup_container() {
    local name="$1"
    if lxc info "$name" > /dev/null 2>&1; then
        info "Stopping and deleting existing container: $name"
        lxc stop "$name" --force > /dev/null 2>&1
        lxc delete "$name" > /dev/null 2>&1
    fi
}

deploy_openwrt() {
    local name="$1"
    local version="$2"
    local wan_br="$3"
    local lan_br="$4"

    info "Deploying OpenWrt Router: $name (Version: $version)"
    cleanup_container "$name"

    # 建立容器 (暫不啟動以利網卡設定)
    lxc init images:openwrt/"$version" "$name" || error "Failed to init $name"

    # 配置網卡 (wan @ WAN, lan @ LAN)
    info "Configuring Network Interfaces for $name..."
    lxc config device add "$name" "$CIF_WAN" nic nictype=bridged parent="$wan_br" name="$CIF_WAN" host_name="$HIF_OWRT_WAN"
    lxc config device add "$name" "$CIF_LAN" nic nictype=bridged parent="$lan_br" name="$CIF_LAN" host_name="$HIF_OWRT_LAN"

    lxc start "$name" || error "Failed to start $name"
    print_status "Container $name" "RUNNING (wan, lan)"
}

deploy_host() {
    local name="$1"
    local bridge="$2"
    local host_if="$3"
    local internal_if="$4"

    info "Deploying Test Host: $name on $bridge"
    cleanup_container "$name"

    lxc launch "$HOST_IMAGE" "$name" || error "Failed to launch $name"
    lxc config device add "$name" "$internal_if" nic nictype=bridged parent="$bridge" name="$internal_if" host_name="$host_if"

    # 重啟以應用網口配置
    lxc restart "$name"
    print_status "Container $name" "RUNNING ($internal_if)"
}

# 執行部署
deploy_openwrt "$CTR_ROUTER" "$OPENWRT_VERSION" "$BRIDGE_WAN" "$BRIDGE_LAN"
deploy_host "$CTR_WAN_HOST" "$BRIDGE_WAN" "$HIF_WAN_HOST" "$CIF_WAN"
deploy_host "$CTR_LAN_HOST" "$BRIDGE_LAN" "$HIF_LAN_HOST" "$CIF_LAN"

info "Containers deployment completed."
