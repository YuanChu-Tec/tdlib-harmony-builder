#!/bin/bash
# 检查补丁状态和实际文件内容

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

log_step "检查补丁状态"

echo ""
echo "=== 1. ICU 补丁检查 ==="
ICU_SOURCE="$EXTRACT_DIR/icu/source"
if [[ -f "$ICU_SOURCE/configure" ]]; then
    echo "✅ configure 文件存在"
    # 检查是否已有相关处理
    if grep -q "U_HAVE_NL_LANGINFO_CODESET" "$ICU_SOURCE/configure" 2>/dev/null; then
        echo "✅ configure 文件中已包含 U_HAVE_NL_LANGINFO_CODESET 处理"
        echo "   补丁可能不需要"
    else
        echo "⚠️  configure 文件中未找到 U_HAVE_NL_LANGINFO_CODESET 处理"
    fi
else
    echo "❌ configure 文件不存在"
fi

echo ""
echo "=== 2. OpenSSL 补丁检查 ==="
OPENSSL_SOURCE="$EXTRACT_DIR/openssl-3.6.0"
if [[ -f "$OPENSSL_SOURCE/crypto/rand/rand_unix.c" ]]; then
    echo "✅ rand_unix.c 文件存在"
else
    echo "❌ rand_unix.c 文件不存在（OpenSSL 3.x 代码结构已改变）"
    echo "   实际文件列表:"
    ls -1 "$OPENSSL_SOURCE/crypto/rand/" 2>/dev/null | sed 's/^/   /' | head -10
fi

echo ""
echo "=== 3. SQLite 补丁检查 ==="
SQLITE_SOURCE="$EXTRACT_DIR/sqlite-autoconf-3510200"
# 查找 os_unix.c 或类似文件
OS_FILE=$(find "$SQLITE_SOURCE" -name "os_unix.c" -o -name "os.c" 2>/dev/null | head -1)
if [[ -n "$OS_FILE" ]]; then
    echo "✅ 找到文件: $OS_FILE"
    if grep -q "SQLITE_OS_UNIX\|__OHOS__" "$OS_FILE" 2>/dev/null; then
        echo "✅ 文件中已包含 HarmonyOS 相关代码"
    else
        echo "⚠️  文件中未找到 HarmonyOS 相关代码"
        echo "   检查第 100 行附近:"
        sed -n '95,110p' "$OS_FILE" 2>/dev/null | sed 's/^/   /'
    fi
else
    echo "❌ 未找到 os_unix.c 或 os.c 文件"
    echo "   查找所有 .c 文件:"
    find "$SQLITE_SOURCE" -name "*.c" -type f 2>/dev/null | head -5 | sed 's/^/   /'
fi

echo ""
echo "=== 4. TDLib 补丁检查 ==="
TD_SOURCE="$EXTRACT_DIR/td-1.8.0"
if [[ -f "$TD_SOURCE/CMakeLists.txt" ]]; then
    echo "✅ CMakeLists.txt 文件存在"
    if grep -q "TD_HARMONYOS\|OHOS" "$TD_SOURCE/CMakeLists.txt" 2>/dev/null; then
        echo "✅ CMakeLists.txt 中已包含 HarmonyOS 相关代码"
    else
        echo "⚠️  CMakeLists.txt 中未找到 HarmonyOS 相关代码"
        echo "   检查第 100 行附近:"
        sed -n '95,110p' "$TD_SOURCE/CMakeLists.txt" 2>/dev/null | sed 's/^/   /'
    fi
else
    echo "❌ CMakeLists.txt 文件不存在"
fi

echo ""
log_step "检查完成"
echo ""
echo "建议:"
echo "1. 如果补丁失败但文件已包含相关代码，可以跳过补丁"
echo "2. 如果补丁失败且文件未包含相关代码，可能需要手动修改或创建新补丁"
echo "3. 可以先尝试编译，如果编译失败再处理补丁问题"
