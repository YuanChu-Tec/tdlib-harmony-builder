#!/bin/bash
# HarmonyOS 适配补丁说明
# 注意：所有补丁均在编译脚本中自动应用，无需手动执行此脚本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ABS="$(cd "$SCRIPTS_ABS/.." && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "${PROJECT_ABS}/config.sh"

log_step "HarmonyOS 适配补丁说明"
log_info ""
log_info "⚠️  所有补丁均在编译脚本中自动应用，无需手动执行"
log_info ""
log_info "补丁应用时机："
log_info "  • TDLib HarmonyOS 补丁（线程亲和、EventFdPipe、AsyncFileLog）"
log_info "    → 在 build_tdlib.sh 中自动应用（配置前）"
log_info "  • wgetopt Windows 修复补丁"
log_info "    → 在 generate_tdlib_api.sh 中自动处理（仅 Windows/MSYS2）"
log_info "  • libphonenumber RE2 兼容性修复"
log_info "    → 在 build_libphonenumber.sh 中内联实现"
log_info "  • 其他库的 HarmonyOS 适配"
log_info "    → 通过编译选项实现（-DOHOS, -DTD_HARMONYOS 等）"
log_info ""
log_info "✅ 补丁会在编译时自动应用，无需手动操作"

exit 0