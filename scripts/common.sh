#!/bin/bash
# scripts/common.sh: 通用函數與全局日誌記錄

# shellcheck disable=SC1091
CONFIG_FILE="$(dirname "$0")/../config/env.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Config file not found at $CONFIG_FILE"
    exit 1
fi

LOG_FILE="$(dirname "$0")/../logs/execution.log"

# 確保日誌目錄存在
mkdir -p "$(dirname "$LOG_FILE")"

# --- 全局輸出重新導向 ---
# 這會將此腳本之後的所有 stdout 和 stderr 同時寫入日誌檔與終端機
# 使用 append 模式 (-a) 以免多個腳本執行時互相覆蓋
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # 這裡不再需要 tee，因為全局 exec 已經處理了
    echo "[$timestamp] [$level] $message"
}

info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
error() { log "ERROR" "$1"; exit 1; }

# 格式化輸出
print_status() {
    local item="$1"
    local status="$2"
    printf "%-30s [%b%s%b]\n" "$item" "\033[32m" "$status" "\033[0m"
}
