# AI 協作指南：打造 OpenWrt LXD 自動化測試環境

這份文件記錄了本專案從構思到完工的開發歷程，並說明了如何透過 AI 協作建立一個專業的網路測試實驗室。

---

## 1. 專案核心目標 (Objective)
建立一個具備三台 LXD 容器的測試環境：
- **OpenWrt Router**: 核心網關，具備語意化命名介面 (`wan`, `lan`)。
- **WAN Host (Alpine)**: 模擬外部網路伺服器。
- **LAN Host (Alpine)**: 模擬內部區域網路客戶端。
- **基礎設施**: 建立宿主機網橋 `br-wan` 與 `br-lan` 實現網路隔離。

---

## 2. 開發哲學與生命週期 (Methodology)
本專案遵循 **Research -> Strategy -> Execution** 流程，並確保所有輸出具備：
- **可重現性 (Reproducibility)**: 透過 `Makefile` 與冪等性腳本，一鍵重建。
- **可驗證性 (Verifiability)**: 具備架構與功能的雙重自動化測試。
- **視覺化 (Visualization)**: 輸出清晰的拓撲圖、架構對照表與連通性動畫。

---

## 3. 實作階段紀錄

### 第一階段：標準化專案結構
建立了目錄結構並將關鍵參數抽離至 `config/env.conf`，確保「配置與邏輯分離」。

### 第二階段：建立宿主機網路
透過 `scripts/01-setup-net.sh` 建立 `br-wan` 與 `br-lan`。解決了網橋必須具備冪等性（Idempotency）的需求。

### 第三階段：語意化命名與部署
解決了 LXD 預設網口命名混亂的問題：
- **Host 視角**: 介面命名為 `v-owrt-wan`, `v-lan-host` 等，讓 `brctl show` 一目瞭然。
- **Container 視角**: 內部命名為 `wan`, `lan`，讓 `lxc list` 輸出極其直觀。

### 第四階段：自動化 UCI 配置
透過 `scripts/04-configure-nodes.sh` 自動化 OpenWrt 的網路、防火牆 Zone 以及 NAT (MASQUERADE) 設定。

### 第五階段：深度視覺化報告
- **`03-verify.sh`**: 輸出物理映射圖，並直接整合 `brctl` 與 `lxc list` 的即時狀態。
- **`05-test-connectivity.sh`**: 提供動態 Ping 測試動畫與 Traceroute 路徑追蹤。

---

## 4. 專案管理入口 (Makefile)
引入 `Makefile` 作為標準化接口：
- `make build`: 基礎設施部署。
- `make config`: 內部網路配置。
- `make test`: 執行視覺化驗證。
- `make clean`: 環境完全清除。

---

## 5. 文件體系
- **`README.md`**: 快速啟動手冊。
- **`AGENTS.md`**: AI 代理程式作業守則。
- **`docs/README.md`**: 詳細網路拓撲與診斷說明。
- **`docs/AI_COLLABORATION_GUIDE.md`**: (本文件) 開發紀錄與協作指南。

---
**文件日期：2026-02-26**
