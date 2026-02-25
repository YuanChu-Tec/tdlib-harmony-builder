#!/bin/bash
# 重置所有源码为最新版本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"

log_step "重置所有源码为最新版本"

# 确认操作
echo ""
log_warning "此操作将："
echo "  1. 清理所有已下载的源码"
echo "  2. 清理所有已解压的源码"
echo "  3. 启用最新版本下载"
echo "  4. 重新下载所有依赖库的最新版本"
echo ""
read -p "确认继续？ [y/N]: " confirm
if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log_info "操作已取消"
    exit 0
fi

# 1. 清理已下载的源码
log_step "清理已下载的源码..."
if [[ -d "$DOWNLOAD_DIR" ]]; then
    log_info "删除下载目录: $DOWNLOAD_DIR"
    rm -rf "$DOWNLOAD_DIR"/* 2>/dev/null || true
    log_success "已清理下载目录"
else
    log_info "下载目录不存在，跳过"
fi

# 2. 清理已解压的源码
log_step "清理已解压的源码..."
if [[ -d "$EXTRACT_DIR" ]]; then
    log_info "删除解压目录: $EXTRACT_DIR"
    rm -rf "$EXTRACT_DIR"/* 2>/dev/null || true
    log_success "已清理解压目录"
else
    log_info "解压目录不存在，跳过"
fi

# 3. 启用最新版本下载
log_step "启用最新版本下载..."
export USE_LATEST_VERSION="true"
log_success "已启用最新版本下载"

# 4. 重新下载所有依赖库的最新版本
log_step "开始下载所有依赖库的最新版本..."
bash "$(dirname "${BASH_SOURCE[0]}")/download_sources.sh"

if [[ $? -eq 0 ]]; then
    log_success "所有依赖库的最新版本已下载完成！"
    log_info "下载位置: $DOWNLOAD_DIR"
    log_info "解压位置: $EXTRACT_DIR"
    echo ""
    log_info "下一步：运行编译脚本"
    log_info "  ./scripts/build_all.sh --arch arm64-v8a"
else
    log_error "下载过程中出现错误，请检查日志"
    exit 1
fi
