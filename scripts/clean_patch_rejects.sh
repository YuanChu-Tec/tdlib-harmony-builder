#!/bin/bash
# 清理补丁应用失败时产生的 .rej 文件

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

log_step "清理补丁拒绝文件"

# 查找所有 .rej 文件
REJ_FILES=$(find "$EXTRACT_DIR" -name "*.rej" -type f 2>/dev/null)

if [[ -z "$REJ_FILES" ]]; then
    log_info "未找到任何 .rej 文件"
    exit 0
fi

# 显示找到的文件
log_info "找到以下 .rej 文件:"
echo "$REJ_FILES" | sed 's/^/  /'

# 询问是否删除
echo ""
read -p "是否删除这些文件? (y/N): " confirm

if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
    echo "$REJ_FILES" | while read -r file; do
        if rm -f "$file" 2>/dev/null; then
            log_success "已删除: $file"
        else
            log_error "删除失败: $file"
        fi
    done
    log_success "清理完成"
else
    log_info "已取消清理"
fi
