# OpenWrt LXD Test Lab

這是一個自動化的 LXD 實驗室環境。

## 🚀 快速啟動 (Makefile)

使用標準 `make` 指令管理實驗室生命週期：

```bash
# 一鍵部署與測試 (從零到一百)
sudo make all

# 分步執行
sudo make build   # 建立基礎設施與容器
sudo make config  # 設定網路參數
sudo make test    # 執行所有測試
sudo make clean   # 清除環境
```

---
*🛡️ 已透過 SSH 密鑰自動化驗證部署。*

- `/config`: 環境變數與關鍵參數 (`env.conf`)。
- `/docs`: 詳細的架構說明文件與拓撲圖。
- `/scripts`: 具備冪等性 (Idempotent) 的自動化執行腳本。
- `/logs`: 記錄所有部署與執行歷史。

## 🌐 網路拓撲簡圖

```text
[wan-host: 10.0.0.2] --(br-wan)-- [openwrt: 10.0.0.1 | 192.168.1.1] --(br-lan)-- [lan-host: 192.168.1.10]
```

## 🛠 技術規格

- **Hypervisor**: LXD (Containers)
- **Router OS**: OpenWrt 24.10
- **Test Hosts**: Alpine Linux
- **Bridge Support**: 標準 Linux Bridge (`br-wan`, `br-lan`)

---
更多技術細節請參考 `docs/README.md` 或 `AGENTS.md`。
