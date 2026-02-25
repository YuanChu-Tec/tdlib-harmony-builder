#!/bin/bash
# 测试解压特定文件

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

FILE=${1:-"src/downloads/icu4c-78_2-src.tgz"}

if [[ ! -f "$FILE" ]]; then
    log_error "文件不存在: $FILE"
    exit 1
fi

log_step "测试解压文件: $FILE"

# 检查文件
log_info "文件信息:"
ls -lh "$FILE" 2>/dev/null || echo "无法获取文件信息"

# 检查 tar 命令
log_info "检查 tar 命令:"
if command -v tar &> /dev/null; then
    tar --version 2>/dev/null || tar -V 2>/dev/null || echo "tar 命令存在但无法获取版本"
else
    log_error "tar 命令不存在"
    exit 1
fi

# 测试解压
TEST_DIR="${EXTRACT_DIR}/test_extract_$$"
mkdir -p "$TEST_DIR"

log_info "测试解压到: $TEST_DIR"

# 尝试解压
if extract_file "$FILE" "$TEST_DIR"; then
    log_success "解压测试成功"
    log_info "解压后的内容:"
    ls -la "$TEST_DIR" 2>/dev/null | head -10
    rm -rf "$TEST_DIR"
    exit 0
else
    log_error "解压测试失败"
    log_info "尝试手动解压:"
    echo "  cd $TEST_DIR"
    echo "  tar -xzf \"$FILE\""
    
    # 尝试手动解压查看错误
    log_info "手动解压测试:"
    cd "$TEST_DIR" 2>/dev/null || mkdir -p "$TEST_DIR" && cd "$TEST_DIR"
    tar -xzf "$FILE" 2>&1 | head -20
    
    rm -rf "$TEST_DIR"
    exit 1
fi
