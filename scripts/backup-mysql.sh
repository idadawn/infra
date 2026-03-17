#!/bin/bash
# MySQL 备份脚本
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
BACKUP_PATH="${PROJECT_ROOT}/backup"
PROJECT_NAME="infra"

# 加载环境变量
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${RED}错误: 找不到 .env 文件${NC}"
    exit 1
fi

# 创建备份目录
mkdir -p "$BACKUP_PATH"

# 生成备份文件名
BACKUP_FILE="${BACKUP_PATH}/mysql_$(date +%Y%m%d_%H%M%S).sql"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    MySQL 数据库备份${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${BLUE}备份信息:${NC}"
echo -e "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  目标: ${BACKUP_FILE}"
echo ""

# 获取 MySQL 容器
MYSQL_CONTAINER=$(docker ps -q -f name="${PROJECT_NAME}-mysql" || true)

if [ -z "$MYSQL_CONTAINER" ]; then
    echo -e "${RED}错误: MySQL 容器未运行${NC}"
    exit 1
fi

# 执行备份
echo -e "${BLUE}正在备份...${NC}"
if docker exec "$MYSQL_CONTAINER" mysqldump \
    -uroot \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --all-databases \
    --single-transaction \
    --quick \
    --lock-tables=false \
    --routines \
    --triggers \
    --events \
    --comments \
    > "$BACKUP_FILE" 2>/dev/null; then

    # 检查备份文件大小
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo -e "${GREEN}✓ 备份成功${NC}"
    echo -e "  文件大小: ${BACKUP_SIZE}"
    echo -e "  路径: ${BACKUP_FILE}"

    # 压缩备份文件
    if command -v gzip &> /dev/null; then
        echo ""
        echo -e "${BLUE}正在压缩备份...${NC}"
        gzip "$BACKUP_FILE"
        COMPRESSED_FILE="${BACKUP_FILE}.gz"
        COMPRESSED_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
        echo -e "${GREEN}✓ 压缩完成${NC}"
        echo -e "  压缩后大小: ${COMPRESSED_SIZE}"
        echo -e "  路径: ${COMPRESSED_FILE}"
    fi

    # 清理旧备份（保留天数）
    if [ -n "$BACKUP_RETENTION_DAYS" ]; then
        echo ""
        echo -e "${BLUE}清理 ${BACKUP_RETENTION_DAYS} 天前的旧备份...${NC}"
        find "$BACKUP_PATH" -name "mysql_*.sql.gz" -type f -mtime +${BACKUP_RETENTION_DAYS} -delete 2>/dev/null || true
        find "$BACKUP_PATH" -name "mysql_*.sql" -type f -mtime +${BACKUP_RETENTION_DAYS} -delete 2>/dev/null || true
        echo -e "${GREEN}✓ 清理完成${NC}"
    fi

else
    echo -e "${RED}✗ 备份失败${NC}"
    [ -f "$BACKUP_FILE" ] && rm -f "$BACKUP_FILE"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}    备份完成${NC}"
echo -e "${BLUE}========================================${NC}"
