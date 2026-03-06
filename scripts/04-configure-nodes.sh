#!/bin/bash
# scripts/04-configure-nodes.sh: 設定 OpenWrt 與 Host 的 IP 位址

# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

info "Configuring OpenWrt ($CTR_ROUTER)..."

# 等待 OpenWrt 初始化完成
sleep 2

lxc exec "$CTR_ROUTER" -- sh -c "
uci set network.wan=interface
uci set network.wan.device='$CIF_WAN'
uci set network.wan.proto='static'
uci set network.wan.ipaddr='$WAN_IP_ROUTER'
uci set network.wan.netmask='255.255.255.0'

uci set network.lan=interface
uci set network.lan.device='$CIF_LAN'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='$LAN_IP_ROUTER'
uci set network.lan.netmask='255.255.255.0'

# 配置防火牆以允許轉發與 NAT
uci set firewall.@zone[0].name='lan'
uci set firewall.@zone[0].network='lan'
uci set firewall.@zone[0].input='ACCEPT'
uci set firewall.@zone[0].output='ACCEPT'
uci set firewall.@zone[0].forward='ACCEPT'

uci set firewall.@zone[1].name='wan'
uci set firewall.@zone[1].network='wan'
uci set firewall.@zone[1].input='ACCEPT'
uci set firewall.@zone[1].output='ACCEPT'
uci set firewall.@zone[1].forward='REJECT'
uci set firewall.@zone[1].masq='1'
uci set firewall.@zone[1].mtu_fix='1'

uci set firewall.@forwarding[0].src='lan'
uci set firewall.@forwarding[0].dest='wan'

uci commit network
uci commit firewall
/etc/init.d/network restart
/etc/init.d/firewall restart
" || error "Failed to configure OpenWrt"

info "Configuring WAN Host ($CTR_WAN_HOST)..."
lxc exec "$CTR_WAN_HOST" -- ip addr add "$WAN_IP_HOST/24" dev "$CIF_WAN"
lxc exec "$CTR_WAN_HOST" -- ip link set "$CIF_WAN" up

info "Configuring LAN Host ($CTR_LAN_HOST)..."
lxc exec "$CTR_LAN_HOST" -- ip addr add "$LAN_IP_HOST/24" dev "$CIF_LAN"
lxc exec "$CTR_LAN_HOST" -- ip link set "$CIF_LAN" up
lxc exec "$CTR_LAN_HOST" -- ip route add default via "$LAN_IP_ROUTER"

print_status "Configuration" "APPLIED"
