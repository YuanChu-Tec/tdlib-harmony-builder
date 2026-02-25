#!/bin/bash
# 验证编译器路径

source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

echo "验证编译器路径..."
echo ""

# 用户提供的路径
USER_CLANG="C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20/native/llvm/bin/clang.exe"
USER_CLANGXX="C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20/native/llvm/bin/clang++.exe"

echo "用户提供的编译器路径:"
echo "  CC:  $USER_CLANG"
echo "  CXX: $USER_CLANGXX"
echo ""

# 规范化路径
NORMALIZED_CLANG=$(normalize_path "$USER_CLANG")
NORMALIZED_CLANGXX=$(normalize_path "$USER_CLANGXX")

echo "规范化后的路径:"
echo "  CC:  $NORMALIZED_CLANG"
echo "  CXX: $NORMALIZED_CLANGXX"
echo ""

# 检查文件是否存在
if [[ -f "$NORMALIZED_CLANG" ]]; then
    echo "✅ clang.exe 存在"
    ls -lh "$NORMALIZED_CLANG" 2>/dev/null || echo "  文件大小: $(stat -f%z "$NORMALIZED_CLANG" 2>/dev/null || echo "未知")"
else
    echo "❌ clang.exe 不存在: $NORMALIZED_CLANG"
fi

if [[ -f "$NORMALIZED_CLANGXX" ]]; then
    echo "✅ clang++.exe 存在"
    ls -lh "$NORMALIZED_CLANGXX" 2>/dev/null || echo "  文件大小: $(stat -f%z "$NORMALIZED_CLANGXX" 2>/dev/null || echo "未知")"
else
    echo "❌ clang++.exe 不存在: $NORMALIZED_CLANGXX"
fi

echo ""
echo "检查系统自动检测的路径..."

# 设置工具链
if set_toolchain arm64-v8a 2>/dev/null; then
    echo "✅ 工具链设置成功"
    echo ""
    echo "系统检测到的编译器路径:"
    echo "  CC:  $CC"
    echo "  CXX: $CXX"
    echo ""
    
    if [[ -f "$CC" ]]; then
        echo "✅ 系统检测的 CC 存在"
    else
        echo "❌ 系统检测的 CC 不存在: $CC"
    fi
    
    if [[ -f "$CXX" ]]; then
        echo "✅ 系统检测的 CXX 存在"
    else
        echo "❌ 系统检测的 CXX 不存在: $CXX"
    fi
    
    echo ""
    echo "工具链目录: $TOOLCHAIN_DIR"
    if [[ -d "$TOOLCHAIN_DIR" ]]; then
        echo "✅ 工具链目录存在"
    else
        echo "❌ 工具链目录不存在: $TOOLCHAIN_DIR"
    fi
else
    echo "❌ 工具链设置失败"
fi

echo ""
echo "验证完成"
