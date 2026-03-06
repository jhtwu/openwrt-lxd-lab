# AI Agent Guide: OpenWrt LXD Project

本文件為 AI 代理程式提供操作此專案的指令集與邏輯模型。

## 🤖 代理程式任務範疇
- **維護性**: 執行腳本時應確保冪等性。
- **標準化**: 優先使用 `Makefile` 指令 (`make all`, `make clean`, `make test`)。
- **自動化**: 執行 `make all` 可完成從零到一百的部署。
- **追蹤性**: 所有變更必須寫入 `/logs/execution.log`。
- **可重現性**: 任何配置更動必須先反映於 `config/env.conf`。

## 系統狀態模型
| 狀態名稱 | 判定條件 | 恢復動作 |
| :--- | :--- | :--- |
| `NETWORK_READY` | `ip link show br-lan` 存在 | 執行 `01-setup-net.sh` |
| `CONTAINERS_READY` | `lxc list` 包含 3 個指定容器 | 執行 `02-deploy-containers.sh` |
| `IP_CONFIGURED` | `lxc exec lan-host -- ip addr` 包含 192.168.1.10 | 執行 `04-configure-nodes.sh` |

## 預期連通性 (Verification Logic)
- `lan-host` -> `192.168.1.1` (OK)
- `lan-host` -> `10.0.0.2` (需 WAN NAT/Forwarding 開放)
- `wan-host` -> `10.0.0.1` (OK)
- `openwrt` -> `8.8.8.8` (需宿主機 br-wan 具備對外路由)

## 關鍵配置參數 (Source: `config/env.conf`)
- `CTR_ROUTER`: "openwrt-router"
- `HIF_OWRT_WAN`: "v-owrt-wan" (Host-side interface name)
- `HIF_OWRT_LAN`: "v-owrt-lan"

## 故障排除 (AI Debugging)
1. **網卡未連接**: 檢查 `brctl show` 是否包含 `v-owrt-xxx` 介面。
2. **OpenWrt 不通**: 
   - 檢查 `uci show network` 輸出。
   - 確認 `/etc/init.d/network restart` 已執行。
3. **無效權限**: 確認 `run_shell_command` 具備 sudo 或是在合適的權限組下執行。

## 擴展示範
若需新增一個 `dmz-host`，AI 應：
1. 在 `env.conf` 定義 `BRIDGE_DMZ` 與 `HIF_DMZ_HOST`。
2. 更新 `01-setup-net.sh` 建立網橋。
3. 更新 `02-deploy-containers.sh` 建立容器並綁定介面。
