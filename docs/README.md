# OpenWrt LXD Test System

這個專案建立一個基於 LXD 的在地化路由器測試環境。

## 網路拓撲

- **br-wan**: 模擬外部網路。
  - `openwrt-router` (eth0, host: `v-owrt-wan`)
  - `wan-host` (eth0, host: `v-wan-host`)
- **br-lan**: 模擬內部區域網路。
  - `openwrt-router` (eth1, host: `v-owrt-lan`)
  - `lan-host` (eth0, host: `v-lan-host`)

## 🔍 診斷與對照 (Visibility)

本專案採用語意化命名，您可以透過以下兩種視角確認網路狀態：

### A. 宿主機視角 (Host View)
使用 `brctl show` 或 `ip link` 觀察實體橋接情況。
- **指令**: `brctl show`
- **對照關係**:
  - `br-wan` 應包含介面: `v-owrt-wan`, `v-wan-host`
  - `br-lan` 應包含介面: `v-owrt-lan`, `v-lan-host`

### B. 容器視角 (Container View)
使用 `lxc list` 觀察容器內部的網路標籤。
- **指令**: `lxc list -c n,s,4`
- **對照關係**:
  - `openwrt-router`: 顯示 `wan` (10.0.0.1) 與 `lan` (192.168.1.1)
  - `lan-host`: 顯示 `lan` (192.168.1.10)
  - `wan-host`: 顯示 `wan` (10.0.0.2)

---

## 網路拓撲 (Network Topology)

```text
       [ WAN Side (br-wan) ]                [ LAN Side (br-lan) ]
      -----------------------              -----------------------
          |             |                      |             |
    +----------+   +--------------+      +--------------+   +----------+
    | wan-host |   | openwrt      |      | openwrt      |   | lan-host |
    | (Alpine) |   | (Router)     |      | (Router)     |   | (Alpine) |
    +----------+   +--------------+      +--------------+   +----------+
    | eth0     |   | eth0 (WAN)   |      | eth1 (LAN)   |   | eth0     |
    | 10.0.0.2 |   | 10.0.0.1     |      | 192.168.1.1  |   | 192.168.1.10
    +----------+   +--------------+      +--------------+   +----------+
          |             |                      |             |
     (v-wan-host)  (v-owrt-wan)           (v-owrt-lan)  (v-lan-host)
          |             |                      |             |
      ====[ br-wan Bridge ]====          ====[ br-lan Bridge ]====
```

### 介面與 IP 配置表

| 節點名稱 | 內部介面 | 宿主機介面 (veth) | 所屬網橋 | IP 位址 | 角色 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **openwrt-router** | `eth0` | `v-owrt-wan` | `br-wan` | `10.0.0.1` | WAN Gateway |
| **openwrt-router** | `eth1` | `v-owrt-lan` | `br-lan` | `192.168.1.1` | LAN Gateway |
| **wan-host** | `eth0` | `v-wan-host` | `br-wan` | `10.0.0.2` | External Server |
| **lan-host** | `eth0` | `v-lan-host` | `br-lan` | `192.168.1.10`| Internal Client |

## 🚀 操作指南 (Workflow)

建議優先使用根目錄的 `Makefile` 進行管理，這能確保腳本執行的順序正確。

- `make all`: 執行完整流程（建立 ➜ 配置 ➜ 測試）。
- `make build`: 建立 `br-wan`/`br-lan` 網橋並部署容器。
- `make config`: 設定 OpenWrt 與 Host 的 IP、防火牆與路由。
- `make test`: 執行驗證與連通性測試。
- `make clean`: 清除所有實驗環境。

## AI 與自動化
本專案專為 AI 協作設計。若您是 AI 代理程式，請優先閱讀根目錄下的 `AGENTS.md` 以瞭解作業邏輯。

詳細的開發歷程與協作心得請參考 [AI 協作指南](./AI_COLLABORATION_GUIDE.md)。
