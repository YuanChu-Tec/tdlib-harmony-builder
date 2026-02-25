#!/bin/bash
# 检查编译器是否存在的辅助脚本

source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

ARCH=${1:-"arm64-v8a"}

echo "检查编译器: $ARCH"
echo ""

# 设置工具链
if ! set_toolchain "$ARCH"; then
    echo "❌ 工具链设置失败"
    exit 1
fi

echo "工具链配置:"
echo "  TOOLCHAIN_DIR: $TOOLCHAIN_DIR"
echo "  TARGET_HOST: $TARGET_HOST"
echo "  OHOS_API_LEVEL: $OHOS_API_LEVEL"
echo ""

# 检查编译器
echo "检查编译器路径:"
echo "  CC: $CC"
echo "  CXX: $CXX"
echo ""

# 检查文件是否存在
check_compiler_file() {
    local compiler=$1
    local name=$2
    
    echo "检查 $name:"
    
    if [[ -f "$compiler" ]]; then
        echo "  ✅ 找到: $compiler"
        file "$compiler" 2>/dev/null || echo "  (文件存在)"
        return 0
    elif [[ -f "${compiler}.exe" ]]; then
        echo "  ✅ 找到: ${compiler}.exe"
        file "${compiler}.exe" 2>/dev/null || echo "  (文件存在)"
        return 0
    else
        echo "  ❌ 未找到: $compiler"
        echo "  ❌ 未找到: ${compiler}.exe"
        return 1
    fi
}

# 检查所有编译器工具
CC_FOUND=false
CXX_FOUND=false

if check_compiler_file "$CC" "C 编译器"; then
    CC_FOUND=true
fi

echo ""

if check_compiler_file "$CXX" "C++ 编译器"; then
    CXX_FOUND=true
fi

echo ""

# 检查其他工具
echo "检查其他工具:"
for tool in AR RANLIB STRIP LD; do
    tool_path=$(eval echo \$$tool)
    if [[ -n "$tool_path" ]]; then
        if [[ -f "$tool_path" ]] || [[ -f "${tool_path}.exe" ]]; then
            echo "  ✅ $tool: $tool_path"
        else
            echo "  ⚠️  $tool: $tool_path (未找到)"
        fi
    fi
done

echo ""

# 总结
if [[ "$CC_FOUND" == true ]] && [[ "$CXX_FOUND" == true ]]; then
    echo "✅ 编译器检查通过"
    exit 0
else
    echo "❌ 编译器检查失败"
    echo ""
    echo "可能的解决方案:"
    echo "  1. 检查 OHOS_NDK 路径是否正确"
    echo "  2. 检查 TOOLCHAIN_DIR 路径: $TOOLCHAIN_DIR"
    echo "  3. 检查编译器文件是否存在:"
    echo "     ls -la \"$TOOLCHAIN_DIR/bin/\""
    exit 1
fi
