#!/bin/bash
# 环境初始化脚本
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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Infra 环境初始化${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 .env 文件
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${YELLOW}警告: .env 文件已存在${NC}"
    read -p "是否重新创建? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}跳过环境初始化${NC}"
        exit 0
    fi
    mv "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup.$(date +%Y%m%d_%H%M%S)"
fi

# 复制 .env.example 到 .env
if [ -f "$PROJECT_ROOT/.env.example" ]; then
    cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
    echo -e "${GREEN}✓ 已创建 .env 文件${NC}"
else
    echo -e "${RED}错误: 找不到 .env.example 文件${NC}"
    exit 1
fi

# 创建必要的目录
echo ""
echo -e "${BLUE}创建必要的目录...${NC}"
mkdir -p "$PROJECT_ROOT/backup"
mkdir -p "$PROJECT_ROOT/logs"
echo -e "${GREEN}✓ 目录创建完成${NC}"

# 生成随机密码
echo ""
echo -e "${BLUE}生成随机密码...${NC}"

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

MYSQL_ROOT_PASS=$(generate_password)
MYSQL_USER_PASS=$(generate_password)
REDIS_PASS=$(generate_password)

# 更新 .env 文件
echo ""
echo -e "${BLUE}更新 .env 文件...${NC}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/your_secure_root_password_here/$MYSQL_ROOT_PASS/" "$PROJECT_ROOT/.env"
    sed -i '' "s/your_secure_db_password_here/$MYSQL_USER_PASS/" "$PROJECT_ROOT/.env"
    sed -i '' "s/your_secure_redis_password_here/$REDIS_PASS/" "$PROJECT_ROOT/.env"
else
    # Linux
    sed -i "s/your_secure_root_password_here/$MYSQL_ROOT_PASS/" "$PROJECT_ROOT/.env"
    sed -i "s/your_secure_db_password_here/$MYSQL_USER_PASS/" "$PROJECT_ROOT/.env"
    sed -i "s/your_secure_redis_password_here/$REDIS_PASS/" "$PROJECT_ROOT/.env"
fi

echo -e "${GREEN}✓ 密码已生成并保存到 .env 文件${NC}"

# 显示密码信息
echo ""
echo -e "${YELLOW}重要: 请保存以下密码信息${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MySQL Root 密码: ${NC}${MYSQL_ROOT_PASS}"
echo -e "${BLUE}MySQL 用户密码: ${NC}${MYSQL_USER_PASS}"
echo -e "${BLUE}Redis 密码: ${NC}${REDIS_PASS}"
echo -e "${BLUE}========================================${NC}"

# 创建密码备份文件
PASSWORD_FILE="$PROJECT_ROOT/.env.passwords.$(date +%Y%m%d_%H%M%S).txt"
cat > "$PASSWORD_FILE" << EOF
# Infra 密码信息
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

MySQL Root 密码: $MYSQL_ROOT_PASS
MySQL 用户密码: $MYSQL_USER_PASS
Redis 密码: $REDIS_PASS

警告: 请妥善保管此文件，使用后建议删除
EOF

chmod 600 "$PASSWORD_FILE"
echo ""
echo -e "${GREEN}✓ 密码已备份到: ${PASSWORD_FILE}${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}    环境初始化完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${BLUE}下一步操作:${NC}"
echo -e "  1. 检查 .env 文件配置"
echo -e "  2. 运行: make up"
echo -e "  3. 运行: make health"
echo ""
