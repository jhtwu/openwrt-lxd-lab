#!/bin/bash
# scripts/setup-lab.sh: 一鍵自動化部署與測試主控腳本

# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

info "=========================================="
info "   OpenWrt LXD Lab: Full Setup Started    "
info "=========================================="

# 定義執行流程
STAGES=(
    "01-setup-net.sh"
    "02-deploy-containers.sh"
    "04-configure-nodes.sh"
    "03-verify.sh"
    "05-test-connectivity.sh"
)

# 依序執行
for script in "${STAGES[@]}"; do
    script_path="$(dirname "$0")/$script"
    info ">>> Executing Stage: $script"
    
    if [ ! -x "$script_path" ]; then
        chmod +x "$script_path"
    fi

    # 執行腳本並檢查結果
    if "$script_path"; then
        print_status "Stage $script" "PASSED"
    else
        error "Stage $script failed. Aborting setup."
    fi
    echo ""
done

info "=========================================="
info "   OpenWrt LXD Lab: Setup Completed!      "
info "   All systems are go.                    "
info "=========================================="
