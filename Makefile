# OpenWrt LXD Test Lab Makefile

.PHONY: all build config test clean verify connectivity help

# 預設任務：執行完整流程
all: build config test

# 建立網路與部署容器
build:
	@mkdir -p logs
	@echo ">>> Building environment and deploying containers..."
	./scripts/01-setup-net.sh
	./scripts/02-deploy-containers.sh

# 配置 IP 與 路由
config:
	@echo ">>> Configuring network settings inside containers..."
	./scripts/04-configure-nodes.sh

# 執行驗證與連通性測試
test: verify connectivity

# 基礎架構驗證 (宿主機橋接與容器狀態)
verify:
	@echo ">>> Running infrastructure verification..."
	./scripts/03-verify.sh

# 功能性測試 (Ping/Routing)
connectivity:
	@echo ">>> Running connectivity functional tests..."
	./scripts/05-test-connectivity.sh

# 徹底清除環境
clean:
	@echo ">>> Cleaning up all containers and bridges..."
	./scripts/cleanup.sh

# 顯示協助資訊
help:
	@echo "Usage:"
	@echo "  make build         - Setup bridges and deploy containers"
	@echo "  make config        - Configure IPs and Firewall inside containers"
	@echo "  make test          - Run all verification and connectivity tests"
	@echo "  make clean         - Remove all containers and bridges"
	@echo "  make all           - Run full setup (build -> config -> test)"
