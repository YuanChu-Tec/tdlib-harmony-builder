#!/bin/bash
# 下载所有依赖库的最新版本源码

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"

log_step "准备下载所有依赖库的最新版本"

# 检查是否启用最新版本
if [[ "$USE_LATEST_VERSION" != "true" ]] && \
   [[ "$USE_LATEST_VERSION" != "auto" ]] && \
   [[ "$USE_LATEST_VERSION" != "latest" ]]; then
    log_warning "USE_LATEST_VERSION 未启用，将使用固定版本"
    log_info "要启用最新版本，请在 user_config.sh 中设置："
    log_info "  export USE_LATEST_VERSION=\"true\""
    echo ""
    read -p "是否继续使用固定版本？ [Y/n]: " response
    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        log_info "请先设置 USE_LATEST_VERSION=true，然后重新运行此脚本"
        exit 1
    fi
fi

# 临时启用最新版本（如果未启用）
TEMP_USE_LATEST="$USE_LATEST_VERSION"
export USE_LATEST_VERSION="true"

# 加载配置
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

# 询问是否清理已下载的源码
echo ""
log_info "选项："
echo "  1. 清理已下载的源码，重新下载最新版本（推荐）"
echo "  2. 保留已下载的源码，只下载缺失的库"
echo ""
read -p "请选择 [1/2] (默认: 1): " choice
choice=${choice:-1}

if [[ "$choice" == "1" ]]; then
    log_step "清理已下载的源码..."
    if [[ -d "$DOWNLOAD_DIR" ]]; then
        log_info "删除下载目录: $DOWNLOAD_DIR"
        rm -rf "$DOWNLOAD_DIR"/* 2>/dev/null || true
    fi
    if [[ -d "$EXTRACT_DIR" ]]; then
        log_info "删除解压目录: $EXTRACT_DIR"
        rm -rf "$EXTRACT_DIR"/* 2>/dev/null || true
    fi
    log_success "已清理旧源码"
fi

# 运行下载脚本
log_step "开始下载最新版本源码..."
bash "$(dirname "${BASH_SOURCE[0]}")/download_sources.sh"

# 恢复原始设置
export USE_LATEST_VERSION="$TEMP_USE_LATEST"

log_success "下载完成！"
log_info "所有依赖库已下载最新版本到: $DOWNLOAD_DIR"
