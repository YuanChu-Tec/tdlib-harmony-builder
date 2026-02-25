#!/bin/bash
# 修复 ICU 解压问题的脚本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

ICU_FILE="src/downloads/icu4c-78_2-src.tgz"

log_step "修复 ICU 解压问题"

# 检查文件是否存在
if [[ ! -f "$ICU_FILE" ]]; then
    log_error "ICU 文件不存在: $ICU_FILE"
    exit 1
fi

log_info "ICU 文件: $ICU_FILE"
log_info "目标目录: $EXTRACT_DIR"

# 确保目标目录存在
mkdir -p "$EXTRACT_DIR"

# 检查解压是否成功的辅助函数
check_extract_success() {
    local dest=$1
    # 检查目录是否有内容（即使有符号链接错误，文件也应该解压出来了）
    if [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
        # 检查是否有 icu 相关目录
        if ls -d "$dest"/icu* 2>/dev/null | head -1 > /dev/null; then
            return 0
        fi
    fi
    return 1
}

# 方法1: 标准 tar 解压（忽略符号链接错误）
log_info "尝试方法1: 标准 tar 解压（忽略符号链接错误）..."
tar_output=$(tar -xzf "$ICU_FILE" -C "$EXTRACT_DIR" --no-same-owner --no-same-permissions 2>&1)
if check_extract_success "$EXTRACT_DIR"; then
    log_success "ICU 解压成功（方法1）"
    if echo "$tar_output" | grep -qi "symlink\|Cannot create"; then
        log_info "已忽略符号链接错误（Windows 环境正常）"
    fi
    exit 0
fi

# 方法2: 切换到目标目录解压
log_info "尝试方法2: 切换到目标目录解压..."
old_pwd=$(pwd)
if cd "$EXTRACT_DIR" 2>/dev/null; then
    tar_output=$(tar -xzf "$(cd "$old_pwd" && pwd)/$ICU_FILE" --no-same-owner --no-same-permissions 2>&1)
    cd "$old_pwd"
    if check_extract_success "$EXTRACT_DIR"; then
        log_success "ICU 解压成功（方法2）"
        if echo "$tar_output" | grep -qi "symlink\|Cannot create"; then
            log_info "已忽略符号链接错误（Windows 环境正常）"
        fi
        exit 0
    fi
fi

# 方法3: 使用绝对路径
log_info "尝试方法3: 使用绝对路径..."
abs_file=$(cd "$(dirname "$ICU_FILE")" && pwd)/$(basename "$ICU_FILE")
abs_dest=$(cd "$EXTRACT_DIR" && pwd 2>/dev/null || echo "$EXTRACT_DIR")

tar_output=$(tar -xzf "$abs_file" -C "$abs_dest" --no-same-owner --no-same-permissions 2>&1)
if check_extract_success "$EXTRACT_DIR"; then
    log_success "ICU 解压成功（方法3）"
    if echo "$tar_output" | grep -qi "symlink\|Cannot create"; then
        log_info "已忽略符号链接错误（Windows 环境正常）"
    fi
    exit 0
fi

# 方法4: 使用相对路径（从项目根目录）
log_info "尝试方法4: 从项目根目录解压..."
cd "$PROJECT_ROOT" 2>/dev/null || cd "$(dirname "${BASH_SOURCE[0]}")/.."
tar_output=$(tar -xzf "$ICU_FILE" -C "$EXTRACT_DIR" --no-same-owner --no-same-permissions 2>&1)
if check_extract_success "$EXTRACT_DIR"; then
    log_success "ICU 解压成功（方法4）"
    if echo "$tar_output" | grep -qi "symlink\|Cannot create"; then
        log_info "已忽略符号链接错误（Windows 环境正常）"
    fi
    exit 0
fi

# 方法5: 尝试不使用 -C 参数
log_info "尝试方法5: 不使用 -C 参数..."
if cd "$EXTRACT_DIR" 2>/dev/null; then
    abs_file=$(cd "$PROJECT_ROOT" && pwd)/$ICU_FILE
    tar_output=$(tar -xzf "$abs_file" --no-same-owner --no-same-permissions 2>&1)
    if check_extract_success "$EXTRACT_DIR"; then
        log_success "ICU 解压成功（方法5）"
        if echo "$tar_output" | grep -qi "symlink\|Cannot create"; then
            log_info "已忽略符号链接错误（Windows 环境正常）"
        fi
        exit 0
    fi
fi

# 所有方法都失败
log_error "所有解压方法都失败"
log_info "请尝试手动解压:"
echo ""
echo "  cd $EXTRACT_DIR"
echo "  tar -xzf $PROJECT_ROOT/$ICU_FILE"
echo ""
echo "或使用 7-Zip (Windows):"
echo "  7z x $PROJECT_ROOT/$ICU_FILE -o$EXTRACT_DIR/"
echo ""

exit 1
