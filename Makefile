# Makefile - Infra 基础设施管理工具
# 作者：idadawn

.PHONY: help up down restart logs ps health backup-mysql backup-redis restore-mysql k8s-apply k8s-delete k8s-status clean

# 配置变量
PROJECT_NAME ?= infra
ENV_FILE ?= .env
COMPOSE_FILE := compose/docker-compose.yml
BACKUP_PATH := ./backup
LOG_PATH := ./logs

# 颜色定义
COLOR_RESET := \033[0m
COLOR_INFO := \033[36m
COLOR_SUCCESS := \033[32m
COLOR_WARNING := \033[33m
COLOR_ERROR := \033[31m

# 默认目标
default: help

##@ 帮助信息

help: ## 显示帮助信息
	@echo "$(COLOR_INFO)基础设施管理工具 - Makefile 命令参考$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_SUCCESS)用法:$(COLOR_RESET) make [target]"
	@echo ""
	@echo "$(COLOR_INFO)可用命令:$(COLOR_RESET)"
	@awk 'BEGIN {FS = ":.*##"; printf "  %-20s %s\n", "目标", "说明"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(COLOR_SUCCESS)%-20s$(COLOR_RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(COLOR_WARNING)%s$(COLOR_RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ 环境检查

check-env: ## 检查环境变量文件
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(COLOR_ERROR)错误: 找不到 $(ENV_FILE) 文件$(COLOR_RESET)"; \
		echo "$(COLOR_WARNING)请先复制 .env.example 到 .env 并配置环境变量$(COLOR_RESET)"; \
		echo "命令: cp .env.example .env"; \
		exit 1; \
	fi
	@echo "$(COLOR_SUCCESS)✓ 环境变量文件检查通过$(COLOR_RESET)"

check-docker: ## 检查 Docker 是否安装
	@docker --version > /dev/null 2>&1 || { echo "$(COLOR_ERROR)错误: Docker 未安装$(COLOR_RESET)"; exit 1; }
	@docker-compose --version > /dev/null 2>&1 || docker compose version > /dev/null 2>&1 || { echo "$(COLOR_ERROR)错误: Docker Compose 未安装$(COLOR_RESET)"; exit 1; }
	@echo "$(COLOR_SUCCESS)✓ Docker 环境检查通过$(COLOR_RESET)"

##@ 服务管理

up: check-env check-docker ## 启动所有基础设施服务
	@echo "$(COLOR_INFO)正在启动服务...$(COLOR_RESET)"
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d
	@echo "$(COLOR_SUCCESS)✓ 服务启动成功$(COLOR_RESET)"
	@$(MAKE) --silent ps

down: check-docker ## 停止并移除所有服务
	@echo "$(COLOR_INFO)正在停止服务...$(COLOR_RESET)"
	docker-compose -f $(COMPOSE_FILE) down
	@echo "$(COLOR_SUCCESS)✓ 服务已停止$(COLOR_RESET)"

restart: check-docker ## 重启所有服务
	@echo "$(COLOR_INFO)正在重启服务...$(COLOR_RESET)"
	docker-compose -f $(COMPOSE_FILE) restart
	@echo "$(COLOR_SUCCESS)✓ 服务重启成功$(COLOR_RESET)"

ps: check-docker ## 查看服务状态
	@echo "$(COLOR_INFO)服务状态:$(COLOR_RESET)"
	@docker-compose -f $(COMPOSE_FILE) ps

logs: check-docker ## 查看所有服务日志
	docker-compose -f $(COMPOSE_FILE) logs -f

logs-mysql: check-docker ## 查看 MySQL 日志
	docker-compose -f $(COMPOSE_FILE) logs -f mysql

logs-redis: check-docker ## 查看 Redis 日志
	docker-compose -f $(COMPOSE_FILE) logs -f redis

##@ 健康检查

health: check-docker ## 检查所有服务健康状态
	@echo "$(COLOR_INFO)正在检查服务健康状态...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_INFO)MySQL 状态:$(COLOR_RESET)"
	@if docker exec $$(docker ps -q -f name=$(PROJECT_NAME)-mysql) mysqladmin ping -h localhost -uroot -p$$(grep MYSQL_ROOT_PASSWORD $(ENV_FILE) | cut -d '=' -f2) > /dev/null 2>&1; then \
		echo "  $(COLOR_SUCCESS)✓ MySQL 运行正常$(COLOR_RESET)"; \
	else \
		echo "  $(COLOR_ERROR)✗ MySQL 异常$(COLOR_RESET)"; \
	fi
	@echo ""
	@echo "$(COLOR_INFO)Redis 状态:$(COLOR_RESET)"
	@if docker exec $$(docker ps -q -f name=$(PROJECT_NAME)-redis) redis-cli -a $$(grep REDIS_PASSWORD $(ENV_FILE) | cut -d '=' -f2) ping > /dev/null 2>&1; then \
		echo "  $(COLOR_SUCCESS)✓ Redis 运行正常$(COLOR_RESET)"; \
	else \
		echo "  $(COLOR_ERROR)✗ Redis 异常$(COLOR_RESET)"; \
	fi

##@ 备份与恢复

backup-mysql: check-docker ## 备份 MySQL 数据库
	@echo "$(COLOR_INFO)正在备份 MySQL 数据库...$(COLOR_RESET)"
	@mkdir -p $(BACKUP_PATH)
	@docker exec $$(docker ps -q -f name=$(PROJECT_NAME)-mysql) mysqldump \
		-uroot \
		-p$$(grep MYSQL_ROOT_PASSWORD $(ENV_FILE) | cut -d '=' -f2) \
		--all-databases \
		--single-transaction \
		--quick \
		--lock-tables=false \
		> $(BACKUP_PATH)/mysql_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(COLOR_SUCCESS)✓ MySQL 备份完成: $(BACKUP_PATH)/mysql_*.sql$(COLOR_RESET)"

backup-redis: check-docker ## 备份 Redis 数据
	@echo "$(COLOR_INFO)正在备份 Redis 数据...$(COLOR_RESET)"
	@mkdir -p $(BACKUP_PATH)
	@docker exec $$(docker ps -q -f name=$(PROJECT_NAME)-redis) redis-cli \
		-a $$(grep REDIS_PASSWORD $(ENV_FILE) | cut -d '=' -f2) \
		--rdb $(BACKUP_PATH)/redis_$$(date +%Y%m%d_%H%M%S).rdb \
		BGSAVE
	@echo "$(COLOR_SUCCESS)✓ Redis 备份完成$(COLOR_RESET)"

backup: backup-mysql backup-redis ## 备份所有数据

restore-mysql: ## 恢复 MySQL 数据库（用法: make restore-mysql FILE=backup.sql）
	@if [ -z "$(FILE)" ]; then \
		echo "$(COLOR_ERROR)错误: 请指定备份文件$(COLOR_RESET)"; \
		echo "用法: make restore-mysql FILE=backup/mysql_20240101_120000.sql"; \
		exit 1; \
	fi
	@echo "$(COLOR_INFO)正在恢复 MySQL 数据库...$(COLOR_RESET)"
	@docker exec -i $$(docker ps -q -f name=$(PROJECT_NAME)-mysql) mysql \
		-uroot \
		-p$$(grep MYSQL_ROOT_PASSWORD $(ENV_FILE) | cut -d '=' -f2) < $(FILE)
	@echo "$(COLOR_SUCCESS)✓ MySQL 数据库恢复完成$(COLOR_RESET)"

##@ Kubernetes 管理

k8s-apply: ## 应用 Kubernetes 配置
	@echo "$(COLOR_INFO)正在应用 Kubernetes 配置...$(COLOR_RESET)"
	kubectl apply -k k8s/base/
	@echo "$(COLOR_SUCCESS)✓ Kubernetes 配置已应用$(COLOR_RESET)"

k8s-delete: ## 删除 Kubernetes 资源
	@echo "$(COLOR_INFO)正在删除 Kubernetes 资源...$(COLOR_RESET)"
	kubectl delete -k k8s/base/
	@echo "$(COLOR_SUCCESS)✓ Kubernetes 资源已删除$(COLOR_RESET)"

k8s-status: ## 查看 Kubernetes 资源状态
	@echo "$(COLOR_INFO)Kubernetes 资源状态:$(COLOR_RESET)"
	@kubectl get all -l app=$(PROJECT_NAME)

k8s-logs: ## 查看 Kubernetes Pod 日志
	@echo "$(COLOR_INFO)获取 Pod 列表...$(COLOR_RESET)"
	@kubectl get pods -l app=$(PROJECT_NAME)
	@echo "$(COLOR_INFO)请使用 'kubectl logs <pod-name>' 查看具体日志$(COLOR_RESET)"

##@ 清理与维护

clean: check-docker ## 清理停止的容器和未使用的镜像
	@echo "$(COLOR_INFO)正在清理未使用的资源...$(COLOR_RESET)"
	docker container prune -f
	docker image prune -f
	@echo "$(COLOR_SUCCESS)✓ 清理完成$(COLOR_RESET)"

clean-all: check-docker ## 清理所有容器、镜像和卷（危险操作！）
	@echo "$(COLOR_WARNING)警告: 此操作将删除所有容器、镜像和数据卷$(COLOR_RESET)"
	@read -p "确认继续? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose -f $(COMPOSE_FILE) down -v; \
		docker system prune -a --volumes -f; \
		echo "$(COLOR_SUCCESS)✓ 清理完成$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_WARNING)已取消$(COLOR_RESET)"; \
	fi

init: check-env ## 初始化项目（创建必要的目录和文件）
	@echo "$(COLOR_INFO)正在初始化项目...$(COLOR_RESET)"
	@mkdir -p $(BACKUP_PATH) $(LOG_PATH)
	@touch $(LOG_PATH)/.gitkeep
	@echo "$(COLOR_SUCCESS)✓ 项目初始化完成$(COLOR_RESET)"

##@ 开发工具

fmt: ## 格式化配置文件
	@echo "$(COLOR_INFO)正在格式化 YAML 文件...$(COLOR_RESET)"
	@which prettier > /dev/null 2>&1 && prettier --write "*.yml" "*.yaml" || echo "  $(COLOR_WARNING)Prettier 未安装，跳过格式化$(COLOR_RESET)"

validate: check-docker ## 验证 Docker Compose 配置
	@echo "$(COLOR_INFO)正在验证 Docker Compose 配置...$(COLOR_RESET)"
	@docker-compose -f $(COMPOSE_FILE) config
	@echo "$(COLOR_SUCCESS)✓ 配置验证通过$(COLOR_RESET)"

##@ 信息查询

info: ## 显示项目信息
	@echo "$(COLOR_INFO)项目信息:$(COLOR_RESET)"
	@echo "  项目名称: $(PROJECT_NAME)"
	@echo "  环境文件: $(ENV_FILE)"
	@echo "  Compose 文件: $(COMPOSE_FILE)"
	@echo "  备份路径: $(BACKUP_PATH)"
	@echo "  日志路径: $(LOG_PATH)"
	@echo ""
	@$(MAKE) --silent ps

version: ## 显示版本信息
	@echo "$(COLOR_INFO)基础设施管理工具 v1.0.0$(COLOR_RESET)"
	@echo "作者: idadawn"
	@echo "GitHub: https://github.com/idadawn/infra"
