#!/bin/bash
# 检查依赖库编译状态脚本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"

ARCH="${1:-arm64-v8a}"

echo "=========================================="
echo "检查依赖库编译状态 (架构: $ARCH)"
echo "=========================================="
echo ""

ARCH_INSTALL_DIR="${INSTALL_DIR}/${ARCH}"

# 检查函数
check_library() {
    local name=$1
    local lib_file=$2
    local header_file=$3
    
    echo -n "检查 $name: "
    
    if [[ -f "$lib_file" ]]; then
        echo -n "✅ 库文件存在"
    else
        echo -n "❌ 库文件缺失"
    fi
    
    if [[ -n "$header_file" ]]; then
        if [[ -f "$header_file" ]]; then
            echo " ✅ 头文件存在"
        else
            echo " ❌ 头文件缺失"
        fi
    else
        echo ""
    fi
}

# 检查 ICU
check_library "ICU" \
    "${ARCH_INSTALL_DIR}/lib/libicuuc.a" \
    "${ARCH_INSTALL_DIR}/include/unicode/unistr.h"

# 检查 RE2
check_library "RE2" \
    "${ARCH_INSTALL_DIR}/lib/libre2.a" \
    "${ARCH_INSTALL_DIR}/include/re2/re2.h"

# 检查 Abseil 兼容层
echo -n "检查 Abseil 兼容层: "
if [[ -f "${ARCH_INSTALL_DIR}/include/absl/base/optimization.h" ]]; then
    echo "✅ 存在"
else
    echo "❌ 缺失"
fi

# 检查 Protobuf
check_library "Protobuf" \
    "${ARCH_INSTALL_DIR}/lib/libprotobuf.a" \
    "${ARCH_INSTALL_DIR}/include/google/protobuf/message.h"

# 检查 libphonenumber
check_library "libphonenumber" \
    "${ARCH_INSTALL_DIR}/lib/libphonenumber.a" \
    "${ARCH_INSTALL_DIR}/include/phonenumbers/phonenumber.h"

echo ""
echo "=========================================="
echo "建议："
echo "=========================================="

# 检查是否可以使用 RE2 替代 ICU
if [[ ! -f "${ARCH_INSTALL_DIR}/lib/libicuuc.a" ]] && [[ -f "${ARCH_INSTALL_DIR}/lib/libre2.a" ]]; then
    echo "✅ 可以使用 RE2 替代 ICU 来编译 libphonenumber"
    echo "   设置: USE_RE2=ON, USE_ICU_REGEXP=OFF"
elif [[ -f "${ARCH_INSTALL_DIR}/lib/libicuuc.a" ]] && [[ -f "${ARCH_INSTALL_DIR}/lib/libre2.a" ]]; then
    echo "✅ ICU 和 RE2 都已编译，可以选择使用任意一个"
    echo "   推荐使用 RE2（更轻量，不依赖 ICU）"
elif [[ ! -f "${ARCH_INSTALL_DIR}/lib/libicuuc.a" ]] && [[ ! -f "${ARCH_INSTALL_DIR}/lib/libre2.a" ]]; then
    echo "⚠️  ICU 和 RE2 都未编译，需要编译其中一个"
    echo "   推荐编译 RE2（更简单，不依赖 ICU）"
fi
