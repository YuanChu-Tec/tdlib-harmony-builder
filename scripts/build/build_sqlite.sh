#!/bin/bash
# SQLite 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 SQLite for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "sqlite" "$SQLITE_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 SQLite 源码，请下载 SQLite 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译
if check_already_built "sqlite" "$ARCH"; then
    log_info "SQLite 已经编译安装"
    exit 0
fi

# 创建构建目录
BUILD_DIR=$(create_build_dir "sqlite" "$ARCH")
cd "$BUILD_DIR" || exit 1

log_step "配置 SQLite..."

# 在 Windows 上，如果指定的编译器不存在，尝试使用 clang.exe
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
    if [[ ! -f "$CC" ]] && [[ ! -x "$CC" ]]; then
        clang_exe="${TOOLCHAIN_DIR}/bin/clang.exe"
        if [[ -f "$clang_exe" ]]; then
            log_info "编译器 $CC 不存在，使用 $clang_exe"
            export CC="$clang_exe"
        else
            log_warning "编译器 $CC 不存在，且 $clang_exe 也不存在"
        fi
    fi
fi

# 验证编译器是否可执行
if ! command -v "$CC" &>/dev/null && [[ ! -x "$CC" ]]; then
    log_error "编译器不可执行: $CC"
    log_info "请检查编译器路径是否正确"
    exit 1
fi

# 确保 configure/make 使用 UTF-8，避免中文路径在 Makefile 中乱码导致 make 失败
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

# SQLite 使用 autotools 构建
run_command \
    "\"$SOURCE_DIR/configure\" \
        --host=\"$TARGET_HOST\" \
        --prefix=\"$ARCH_INSTALL_DIR\" \
        --enable-static \
        --disable-shared \
        CC=\"$CC\" \
        CFLAGS=\"$CFLAGS\" \
        LDFLAGS=\"$LDFLAGS\"" \
    "${LOGS_DIR}/build/sqlite_${ARCH}_configure.log" \
    "配置 SQLite"

if [[ $? -ne 0 ]]; then
    log_error "SQLite 配置失败"
    exit 1
fi

# 编译（与 configure 同目录下执行，Makefile 中的路径编码与当前一致）
log_step "编译 SQLite..."
run_command \
    "make -j${PARALLEL_JOBS}" \
    "${LOGS_DIR}/build/sqlite_${ARCH}_build.log" \
    "编译 SQLite"

if [[ $? -ne 0 ]]; then
    log_error "SQLite 编译失败"
    exit 1
fi

# 安装
log_step "安装 SQLite..."
run_command \
    "make install" \
    "${LOGS_DIR}/build/sqlite_${ARCH}_install.log" \
    "安装 SQLite"

if [[ $? -ne 0 ]]; then
    log_error "SQLite 安装失败"
    exit 1
fi

# 编译后验证
if ! verify_build_result "sqlite" "$ARCH" "libsqlite3.a" "sqlite3.h"; then
    log_error "SQLite 编译验证失败"
    exit 1
fi

log_success "SQLite 编译安装完成: $ARCH"
