#!/bin/bash
# 获取工具链文件路径的辅助函数

get_toolchain_file() {
    local ndk_path="${1:-$OHOS_NDK}"
    
    if [[ -z "$ndk_path" ]] || [[ ! -d "$ndk_path" ]]; then
        return 1
    fi
    
    # 转换 Windows 路径格式（统一使用正斜杠）
    ndk_path=$(echo "$ndk_path" | sed 's|\\|/|g')
    
    # 尝试多种可能的工具链文件路径
    # 如果 NDK 路径以 "/native" 结尾，直接使用 build/cmake 路径（避免重复添加 native）
    local toolchain_files=()
    if [[ "$ndk_path" == *"/native" ]] || [[ "$ndk_path" == *"\\native" ]] || [[ "$ndk_path" == *"/native/" ]] || [[ "$ndk_path" == *"\\native\\" ]]; then
        # NDK 路径已经包含 native，直接使用 build/cmake
        toolchain_files=(
            "${ndk_path}/build/cmake/ohos.toolchain.cmake"
            "${ndk_path}/../build/cmake/ohos.toolchain.cmake"  # 备用：上一级目录
        )
    else
        # NDK 路径不包含 native，尝试添加 native
        toolchain_files=(
            "${ndk_path}/build/cmake/ohos.toolchain.cmake"  # 如果 NDK 已经指向 native 目录
            "${ndk_path}/native/build/cmake/ohos.toolchain.cmake"  # 标准结构（如果 NDK 指向 SDK 根目录）
            "${ndk_path}/../build/cmake/ohos.toolchain.cmake"  # 如果 NDK 指向 native/llvm 等子目录
        )
    fi
    
    # 查找存在的工具链文件
    for toolchain_file in "${toolchain_files[@]}"; do
        toolchain_file=$(echo "$toolchain_file" | sed 's|\\|/|g')
        if [[ -f "$toolchain_file" ]]; then
            echo "$toolchain_file"
            return 0
        fi
    done
    
    return 1
}

# 如果直接运行此脚本，测试工具链文件查找
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"
    
    if [[ -z "$OHOS_NDK" ]]; then
        echo "❌ 错误: OHOS_NDK 未设置"
        exit 1
    fi
    
    toolchain_file=$(get_toolchain_file "$OHOS_NDK")
    
    if [[ -n "$toolchain_file" ]]; then
        echo "✅ 找到工具链文件: $toolchain_file"
        exit 0
    else
        echo "❌ 未找到工具链文件"
        exit 1
    fi
fi
