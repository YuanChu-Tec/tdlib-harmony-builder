#!/bin/bash
# 修复所有构建脚本中的工具链路径

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"

log_step "修复构建脚本中的工具链路径"

# 需要修复的脚本列表
SCRIPTS=(
    "scripts/build/build_crc32c.sh"
    "scripts/build/build_xxhash.sh"
    "scripts/build/build_tdlib.sh"
    "scripts/build/build_libevent.sh"
    "scripts/build/build_lz4.sh"
    "scripts/build/build_snappy.sh"
    "scripts/build/build_libphonenumber.sh"
)

# 工具链路径修复代码块
TOOLCHAIN_BLOCK='# 获取工具链文件路径
TOOLCHAIN_FILE="${OHOS_TOOLCHAIN_FILE:-}"
if [[ -z "$TOOLCHAIN_FILE" ]] && command -v get_toolchain_file &> /dev/null; then
    TOOLCHAIN_FILE=$(get_toolchain_file "$OHOS_NDK")
fi
if [[ -z "$TOOLCHAIN_FILE" ]]; then
    # 默认路径
    TOOLCHAIN_FILE="${OHOS_NDK}/build/cmake/ohos.toolchain.cmake"
    if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
        TOOLCHAIN_FILE="${OHOS_NDK}/native/build/cmake/ohos.toolchain.cmake"
    fi
fi'

for script in "${SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
        log_warning "脚本不存在: $script"
        continue
    fi
    
    # 检查是否已经修复过
    if grep -q "get_toolchain_file" "$script" 2>/dev/null; then
        log_info "已修复: $script"
        continue
    fi
    
    # 查找需要替换的行
    if grep -q 'DCMAKE_TOOLCHAIN_FILE.*native/build/cmake' "$script" 2>/dev/null; then
        log_info "修复: $script"
        # 这里需要手动修复，因为每个脚本的结构可能不同
        # 建议使用 sed 或手动编辑
    fi
done

log_info "请手动检查并修复以下脚本中的工具链路径:"
for script in "${SCRIPTS[@]}"; do
    if [[ -f "$script" ]] && grep -q 'DCMAKE_TOOLCHAIN_FILE.*native/build/cmake' "$script" 2>/dev/null; then
        echo "  - $script"
    fi
done
