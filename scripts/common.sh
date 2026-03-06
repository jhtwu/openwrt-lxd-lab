#!/bin/bash
# scripts/common.sh: 通用函數與日誌記錄

# shellcheck disable=SC1091
CONFIG_FILE="$(dirname "$0")/../config/env.conf"
if [ -f "$CONFIG_FILE" ]; then
# shellcheck disable=SC1091
    source "$CONFIG_FILE"
else
    echo "ERROR: Config file not found at $CONFIG_FILE"
    exit 1
fi

LOG_FILE="$(dirname "$0")/../logs/execution.log"

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
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
