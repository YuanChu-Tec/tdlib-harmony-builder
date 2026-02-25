#!/bin/bash
# 应用 HarmonyOS 适配补丁
# 注意：大部分 HarmonyOS 适配已在编译脚本中通过编译选项实现
# 此脚本仅处理特殊的补丁（如 Windows wgetopt 修复）

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ABS="$(cd "$SCRIPTS_ABS/.." && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "${PROJECT_ABS}/config.sh"

log_step "开始应用 HarmonyOS 适配补丁"

# 检查补丁目录
if [[ ! -d "$PATCHES_DIR" ]]; then
    log_warning "补丁目录不存在: $PATCHES_DIR"
    exit 0
fi

# 检查解压目录
if [[ ! -d "$EXTRACT_DIR" ]] || [[ -z "$(ls -A "$EXTRACT_DIR" 2>/dev/null)" ]]; then
    log_warning "解压目录为空，跳过补丁应用"
    log_info "提示：大部分 HarmonyOS 适配已在编译脚本中通过编译选项实现，无需补丁"
    exit 0
fi

# 统计
APPLIED_COUNT=0
SKIPPED_COUNT=0

# 只处理 wgetopt 相关补丁（Windows 下 TDLib API 生成器需要）
for patch_file in "$PATCHES_DIR"/*wgetopt*.patch; do
    if [[ ! -f "$patch_file" ]]; then
        continue
    fi
    
    patch_name=$(basename "$patch_file")
    log_step "处理补丁: $patch_name"
    
    # wgetopt 补丁在 generate_tdlib_api.sh 中处理，这里跳过
    log_info "此补丁在 API 生成时自动处理，跳过"
    ((SKIPPED_COUNT++))
done

# 输出结果
echo ""
log_step "补丁应用完成总结:"

if [[ $APPLIED_COUNT -gt 0 ]]; then
    log_success "✅ 成功应用 ($APPLIED_COUNT 个补丁)"
fi

if [[ $SKIPPED_COUNT -gt 0 ]]; then
    log_info "ℹ️  跳过 ($SKIPPED_COUNT 个补丁，已在编译脚本中处理)"
fi

log_info ""
log_info "说明："
log_info "  • HarmonyOS 平台适配主要通过编译选项实现（-DOHOS, -DTD_HARMONYOS 等）"
log_info "  • libphonenumber RE2 兼容性修复在 build_libphonenumber.sh 中内联实现"
log_info "  • wgetopt Windows 修复在 generate_tdlib_api.sh 中自动处理"
log_info "  • TDLib HarmonyOS 补丁（线程亲和、AsyncFileLog 无 eventfd）在 build_tdlib.sh 中自动应用"
log_info "  • 无需手动应用补丁"

exit 0
