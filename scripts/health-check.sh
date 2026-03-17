#!/bin/bash
# 健康检查脚本
# 作者：idadawn

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
PROJECT_NAME="infra"

# 检查环境变量文件
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}错误: 找不到 .env 文件${NC}"
    exit 1
fi

# 加载环境变量
source "$ENV_FILE"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    基础设施健康检查${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 MySQL
echo -e "${BLUE}[MySQL]${NC}"
MYSQL_CONTAINER=$(docker ps -q -f name="${PROJECT_NAME}-mysql" || true)

if [ -z "$MYSQL_CONTAINER" ]; then
    echo -e "  状态: ${RED}未运行${NC}"
else
    # 检查容器健康状态
    MYSQL_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$MYSQL_CONTAINER" 2>/dev/null || echo "unknown")

    case $MYSQL_HEALTH in
        healthy)
            echo -e "  状态: ${GREEN}健康${NC}"
            ;;
        unhealthy)
            echo -e "  状态: ${YELLOW}不健康${NC}"
            ;;
        *)
            echo -e "  状态: ${YELLOW}未知${NC}"
            ;;
    esac

    # 尝试连接
    if docker exec "$MYSQL_CONTAINER" mysqladmin ping -h localhost -uroot -p"${MYSQL_ROOT_PASSWORD}" &>/dev/null; then
        echo -e "  连接: ${GREEN}成功${NC}"

        # 显示版本
        MYSQL_VERSION=$(docker exec "$MYSQL_CONTAINER" mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT VERSION();" -s 2>/dev/null || echo "unknown")
        echo -e "  版本: $MYSQL_VERSION"

        # 显示数据库列表
        DB_COUNT=$(docker exec "$MYSQL_CONTAINER" mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW DATABASES;" -s 2>/dev/null | grep -v -E "information_schema|performance_schema|mysql|sys" | wc -l)
        echo -e "  数据库数量: $DB_COUNT"
    else
        echo -e "  连接: ${RED}失败${NC}"
    fi
fi

echo ""

# 检查 Redis
echo -e "${BLUE}[Redis]${NC}"
REDIS_CONTAINER=$(docker ps -q -f name="${PROJECT_NAME}-redis" || true)

if [ -z "$REDIS_CONTAINER" ]; then
    echo -e "  状态: ${RED}未运行${NC}"
else
    # 检查容器健康状态
    REDIS_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$REDIS_CONTAINER" 2>/dev/null || echo "unknown")

    case $REDIS_HEALTH in
        healthy)
            echo -e "  状态: ${GREEN}健康${NC}"
            ;;
        unhealthy)
            echo -e "  状态: ${YELLOW}不健康${NC}"
            ;;
        *)
            echo -e "  状态: ${YELLOW}未知${NC}"
            ;;
    esac

    # 尝试连接
    if docker exec "$REDIS_CONTAINER" redis-cli -a "${REDIS_PASSWORD}" ping &>/dev/null; then
        echo -e "  连接: ${GREEN}成功${NC}"

        # 显示版本
        REDIS_VERSION=$(docker exec "$REDIS_CONTAINER" redis-cli -a "${REDIS_PASSWORD}" INFO server 2>/dev/null | grep redis_version || echo "unknown")
        echo -e "  $REDIS_VERSION"

        # 显示内存使用
        REDIS_MEMORY=$(docker exec "$REDIS_CONTAINER" redis-cli -a "${REDIS_PASSWORD}" INFO memory 2>/dev/null | grep used_memory_human || echo "unknown")
        echo -e "  内存使用: $REDIS_MEMORY"

        # 显示连接数
        REDIS_CLIENTS=$(docker exec "$REDIS_CONTAINER" redis-cli -a "${REDIS_PASSWORD}" INFO clients 2>/dev/null | grep connected_clients || echo "unknown")
        echo -e "  连接数: $REDIS_CLIENTS"
    else
        echo -e "  连接: ${RED}失败${NC}"
    fi
fi

echo ""

# 检查 Neo4j
echo -e "${BLUE}[Neo4j]${NC}"
NEO4J_CONTAINER=$(docker ps -q -f name="${PROJECT_NAME}-neo4j" || true)

if [ -z "$NEO4J_CONTAINER" ]; then
    echo -e "  状态: ${RED}未运行${NC}"
else
    # 检查容器健康状态
    NEO4J_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$NEO4J_CONTAINER" 2>/dev/null || echo "unknown")

    case $NEO4J_HEALTH in
        healthy)
            echo -e "  状态: ${GREEN}健康${NC}"
            ;;
        unhealthy)
            echo -e "  状态: ${YELLOW}不健康${NC}"
            ;;
        *)
            echo -e "  状态: ${YELLOW}未知${NC}"
            ;;
    esac

    # 尝试连接
    NEO4J_HTTP_PORT=$(grep NEO4J_HTTP_PORT "$ENV_FILE" | cut -d '=' -f2)
    if wget --no-verbose --tries=1 --spider "http://localhost:${NEO4J_HTTP_PORT}" &>/dev/null; then
        echo -e "  连接: ${GREEN}成功${NC}"
        echo -e "  浏览器: ${GREEN}http://localhost:${NEO4J_HTTP_PORT}${NC}"
        echo -e "  Bolt端口: ${NEO4J_BOLT_PORT:-7687}"
    else
        echo -e "  连接: ${RED}失败${NC}"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    检查完成${NC}"
echo -e "${BLUE}========================================${NC}"
