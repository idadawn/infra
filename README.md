# Infra - 基础设施统一管理

[![License: MIT](https://img.shield.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Author](https://img.shield.io/badge/Author-idadawn-blue.svg)](https://github.com/idadawn)

> 从单机 Docker Compose 到 Kubernetes 集群的基础设施统一管理方案

## 📖 概述

本项目提供了一套完整的基础设施管理方案，支持从开发环境到生产环境的平滑演进。

- ✅ **单机部署**：基于 Docker Compose，适合开发/测试环境
- ✅ **集群部署**：基于 Kubernetes，适合生产环境
- ✅ **自动化运维**：Makefile 封装常用操作
- ✅ **版本控制**：Git 集中管理配置
- ✅ **多环境支持**：Dev/Test/Prod 环境隔离

## 🏗️ 目录结构

```
infra/
├── README.md                   # 项目说明
├── Makefile                    # 统一操作入口
├── .env.example                # 环境变量模板
├── .gitignore                  # Git 忽略配置
│
├── compose/                    # Docker Compose 配置
│   ├── docker-compose.yml      # 核心组件编排
│   ├── mysql/                  # MySQL 配置与初始化
│   └── redis/                  # Redis 配置
│
├── k8s/                        # Kubernetes 配置
│   ├── base/                   # 基础资源定义
│   └── overlays/               # 多环境配置覆盖
│
├── scripts/                    # 运维脚本
│   ├── backup-mysql.sh         # MySQL 备份
│   └── health-check.sh         # 健康检查
│
├── backup/                     # 备份文件存储
└── logs/                       # 日志文件存储
```

## 🚀 快速开始

### 1. 环境准备

确保已安装以下工具：

```bash
# Docker & Docker Compose
docker --version
docker-compose --version

# 或 Kubernetes（集群部署时需要）
kubectl version
```

### 2. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，设置密码等配置
vim .env
```

### 3. 启动服务

**方式一：使用 Makefile（推荐）**

```bash
# 查看所有可用命令
make help

# 启动所有服务
make up

# 查看服务状态
make ps

# 查看日志
make logs

# 停止服务
make down
```

**方式二：直接使用 Docker Compose**

```bash
docker-compose -f compose/docker-compose.yml --env-file .env up -d
```

### 4. 验证服务

```bash
# 健康检查
make health

# 或手动检查
docker-compose -f compose/docker-compose.yml ps
```

## 📦 可用服务

当前支持的基础设施组件：

| 服务 | 端口 | 说明 |
|------|------|------|
| MySQL | 3306 | 关系型数据库 |
| Redis | 6379 | 缓存/消息队列 |
| Neo4j | 7474, 7687 | 图数据库 |

## 🛠️ 常用命令

### Docker Compose 操作

```bash
make up          # 启动所有服务
make down        # 停止并移除所有服务
make restart     # 重启所有服务
make logs        # 查看所有服务日志
make ps          # 查看服务状态
make health      # 健康检查
```

### 按需启动单个服务

```bash
# MySQL
make mysql-up        # 启动 MySQL
make mysql-down      # 停止 MySQL
make mysql-logs      # 查看 MySQL 日志

# Redis
make redis-up        # 启动 Redis
make redis-down      # 停止 Redis
make redis-logs      # 查看 Redis 日志

# Neo4j
make neo4j-up        # 启动 Neo4j
make neo4j-down      # 停止 Neo4j
make neo4j-logs      # 查看 Neo4j 日志
```

### 备份与恢复

```bash
make backup-mysql    # 备份 MySQL 数据库
make backup-redis    # 备份 Redis 数据
make backup-neo4j    # 备份 Neo4j 数据
make restore-mysql   # 恢复 MySQL 数据库
```

### Kubernetes 操作

```bash
make k8s-apply       # 部署到 K8s 集群
make k8s-delete      # 从 K8s 集群删除
make k8s-status      # 查看 K8s 资源状态
```

## 🔐 安全建议

1. **永远不要提交 `.env` 文件到 Git 仓库**
2. 使用强密码，建议通过密码管理器生成
3. 定期备份数据，测试恢复流程
4. 生产环境使用独立的数据库密码
5. 考虑使用 Docker Secrets 管理敏感信息

## 📝 配置说明

### MySQL 配置

- 默认字符集：`utf8mb4`
- 时区：`+08:00`
- 最大连接数：1000

可通过修改 `compose/mysql/conf/my.cnf` 自定义配置。

### Redis 配置

- 持久化：RDB + AOF
- 数据库数量：16

可通过修改 `compose/redis/conf/redis.conf` 自定义配置。

### Neo4j 配置

- 默认用户：`neo4j`
- HTTP 端口：7474（浏览器界面）
- Bolt 端口：7687（驱动连接）
- 初始内存：512MB
- 最大内存：1GB

首次启动后，请访问 http://localhost:7474 并修改默认密码。

可通过修改 `compose/neo4j/conf/neo4j.conf` 自定义配置。

## 🌍 多环境部署

### 开发环境（Dev）

```bash
export ENV_FILE=.env.dev
make up
```

### 生产环境（Prod）

```bash
export ENV_FILE=.env.prod
docker-compose -f compose/docker-compose.yml -f compose/docker-compose.prod.yml --env-file .env.prod up -d
```

### Kubernetes 环境

```bash
# 开发环境
kubectl apply -k k8s/overlays/dev/

# 生产环境
kubectl apply -k k8s/overlays/prod/
```

## 📊 监控与日志

### 查看日志

```bash
# 查看所有服务日志
make logs

# 查看特定服务日志
docker-compose -f compose/docker-compose.yml logs -f mysql
docker-compose -f compose/docker-compose.yml logs -f redis
```

### 健康检查

```bash
# 自动健康检查
make health

# 手动检查
docker exec infra-mysql mysqladmin ping -h localhost
docker exec infra-redis redis-cli ping
```

## 🔄 从 Docker Compose 迁移到 Kubernetes

当业务增长需要更高可用性时，可以无缝迁移到 Kubernetes：

1. **准备 Kubernetes 集群**
2. **创建 Secret 和 ConfigMap**
3. **应用 K8s 配置**

```bash
kubectl apply -k k8s/overlays/prod/
```

详细迁移指南请参考 [MIGRATION.md](docs/MIGRATION.md)

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 👨‍💻 作者

**idadawn** - [GitHub](https://github.com/idadawn)

## 🙏 致谢

- [Docker](https://www.docker.com/)
- [Kubernetes](https://kubernetes.io/)
- [MySQL](https://www.mysql.com/)
- [Redis](https://redis.io/)

---

⭐ 如果这个项目对你有帮助，请给一个 Star！
