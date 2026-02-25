#!/bin/bash
# 测试 find_source_dir 函数

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

echo "测试 find_source_dir 函数:"
echo ""

echo "1. OpenSSL:"
result=$(find_source_dir "openssl" "$OPENSSL_VERSION")
echo "  版本: $OPENSSL_VERSION"
echo "  找到: $result"
echo ""

echo "2. SQLite:"
result=$(find_source_dir "sqlite" "$SQLITE_VERSION")
echo "  版本: $SQLITE_VERSION"
echo "  找到: $result"
echo ""

echo "3. ICU:"
result=$(find_source_dir "icu" "$ICU_VERSION")
echo "  版本: $ICU_VERSION"
echo "  找到: $result"
echo ""

echo "4. TDLib:"
result=$(find_source_dir "td" "$TDLIB_VERSION")
echo "  版本: $TDLIB_VERSION"
echo "  找到: $result"
echo ""

echo "实际目录列表:"
ls -d "$EXTRACT_DIR"/*/ 2>/dev/null | sed 's|.*/||' | sed 's/^/  /'
