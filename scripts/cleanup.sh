#!/bin/bash
# 清理构建文件脚本
#
# 用法:
#   ./scripts/cleanup.sh           # 清理全部构建产物
#   ./scripts/cleanup.sh --keep-src   # 仅清理编译产物，保留 src 目录
#
# 注意: 下载目录 (src/downloads) 永远不会被清理

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ABS="$(cd "$SCRIPTS_ABS/.." && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "${PROJECT_ABS}/config.sh"

KEEP_SRC=false
for arg in "$@"; do
    case "$arg" in
        --keep-src|-k) KEEP_SRC=true ;;
    esac
done

# 下载目录永远不会被清理
if [[ "$KEEP_SRC" == "true" ]]; then
    log_step "清理编译产物（保留 src 目录）"
    CLEAN_DIRS=(
        "$BUILD_DIR"
        "$INSTALL_DIR"
        "$DIST_DIR"
        "$LOGS_DIR"
    )
    echo "将清理: build/, install/, dist/, logs/"
    echo "保留: src/downloads/, src/extracted/"
else
    log_step "清理构建文件（保留下载目录）"
    CLEAN_DIRS=(
        "$BUILD_DIR"
        "$INSTALL_DIR"
        "$EXTRACT_DIR"
        "$DIST_DIR"
        "$LOGS_DIR"
    )
    echo "将清理: build/, install/, dist/, logs/, src/extracted/"
    echo "保留: src/downloads/ (下载目录永远不会被清理)"
fi

echo ""
echo "以下目录将被清空:"
for dir in "${CLEAN_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo "  • $dir ($size)"
    fi
done

echo ""
read -p "确认清理？ [y/N]: " confirm

if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log_info "取消清理"
    exit 0
fi

for dir in "${CLEAN_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        log_info "清理: $dir"
        rm -rf "$dir"/*
        log_success "已清理: $dir"
    fi
done

log_success "清理完成"
