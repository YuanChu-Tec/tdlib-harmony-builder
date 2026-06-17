#!/bin/bash
# ICU 编译脚本 for HarmonyOS
# 注意：ICU 需要先编译主机工具，再进行交叉编译

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 ICU for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "icu" "$ICU_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 ICU 源码，请下载 ICU 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

# ICU 源码通常在 source 子目录
if [[ -d "$SOURCE_DIR/source" ]]; then
    SOURCE_DIR="$SOURCE_DIR/source"
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译
if check_already_built "icu" "$ARCH"; then
    log_info "ICU 已经编译安装"
    exit 0
fi

# ICU 需要先编译主机工具
log_step "编译主机工具..."

# 保存交叉编译环境变量
SAVE_CC="$CC"
SAVE_CXX="$CXX"
SAVE_CFLAGS="$CFLAGS"
SAVE_CXXFLAGS="$CXXFLAGS"
SAVE_LDFLAGS="$LDFLAGS"
SAVE_AR="$AR"
SAVE_LD="$LD"
SAVE_RANLIB="$RANLIB"
SAVE_SYSROOT="$SYSROOT"

# 主机工具使用用户配置的 HOST_CC/HOST_CXX（若已设置），否则使用系统默认
HOST_CC="${HOST_CC:-}"
HOST_CXX="${HOST_CXX:-}"
if [[ -n "$HOST_CC" ]] && [[ -n "$HOST_CXX" ]]; then
    export CC="$HOST_CC"
    export CXX="$HOST_CXX"
    unset CFLAGS CXXFLAGS LDFLAGS AR LD RANLIB SYSROOT
    log_info "使用用户配置的主机编译器: CC=$HOST_CC CXX=$HOST_CXX"
else
    unset CC CXX CFLAGS CXXFLAGS LDFLAGS AR LD RANLIB SYSROOT
fi

# CXXFLAGS: 使用 -std=c++17 + -fext-numeric-literals 支持 GCC 15 <limits> 中的 __float128 Q 后缀
# 注意：单独使用 -fext-numeric-literals + -std=c++11 会导致 "exponent has no digits" 错误
# 但 -std=c++17 + -fext-numeric-literals 可以正常工作
HOST_CXXFLAGS="-std=c++17 -fext-numeric-literals"

# 配置主机版本（使用 config 中的路径）
HOST_BUILD_DIR="${ARCH_BUILD_DIR}/icu-host"
mkdir -p "$HOST_BUILD_DIR"
cd "$HOST_BUILD_DIR" || exit 1

run_command \
    "\"$SOURCE_DIR/configure\" \
        --enable-static \
        --disable-shared \
        --disable-samples \
        --disable-tests \
        CXXFLAGS=\"$HOST_CXXFLAGS\"" \
    "${LOGS_DIR}/build/icu_${ARCH}_host_configure.log" \
    "配置 ICU 主机工具"

# 先整体构建一次（允许失败），通常此时静态库已经生成
log_info "初次构建 ICU 主机库和工具（允许失败）..."
run_command \
    "make -j${PARALLEL_JOBS:-4} CXXFLAGS=\"$HOST_CXXFLAGS\" || true" \
    "${LOGS_DIR}/build/icu_${ARCH}_host_build.log" \
    "初次构建 ICU 主机库和工具（允许失败）"

# 在构建工具之前，先创建兼容名称的库文件（工具链接时需要 -licu*）
# ICU 生成的是 libsicu*.a，但链接器期望 libicu*.a
HOST_LIB_DIR="$HOST_BUILD_DIR/lib"
STUBDATA_LIB_DIR="$HOST_BUILD_DIR/stubdata"

if [[ -d "$HOST_LIB_DIR" ]]; then
    log_info "创建 ICU 库兼容名称（用于工具链接）..."
    # libsicuuc.a -> libicuuc.a
    if [[ -f "$HOST_LIB_DIR/libsicuuc.a" && ! -f "$HOST_LIB_DIR/libicuuc.a" ]]; then
        cp "$HOST_LIB_DIR/libsicuuc.a" "$HOST_LIB_DIR/libicuuc.a" 2>/dev/null || true
    fi
    # libsicuio.a -> libicuio.a
    if [[ -f "$HOST_LIB_DIR/libsicuio.a" && ! -f "$HOST_LIB_DIR/libicuio.a" ]]; then
        cp "$HOST_LIB_DIR/libsicuio.a" "$HOST_LIB_DIR/libicuio.a" 2>/dev/null || true
    fi
    # libsicutu.a -> libicutu.a
    if [[ -f "$HOST_LIB_DIR/libsicutu.a" && ! -f "$HOST_LIB_DIR/libicutu.a" ]]; then
        cp "$HOST_LIB_DIR/libsicutu.a" "$HOST_LIB_DIR/libicutu.a" 2>/dev/null || true
    fi
    # libsicuin.a -> libicuin.a
    if [[ -f "$HOST_LIB_DIR/libsicuin.a" && ! -f "$HOST_LIB_DIR/libicuin.a" ]]; then
        cp "$HOST_LIB_DIR/libsicuin.a" "$HOST_LIB_DIR/libicuin.a" 2>/dev/null || true
    fi
fi

# stubdata 中的 libsicudt.a -> libicudt.a（工具链接 -licudt）
if [[ -d "$STUBDATA_LIB_DIR" ]]; then
    if [[ -f "$STUBDATA_LIB_DIR/libsicudt.a" ]]; then
        mkdir -p "$HOST_LIB_DIR" 2>/dev/null || true
        if [[ ! -f "$HOST_LIB_DIR/libicudt.a" ]]; then
            cp "$STUBDATA_LIB_DIR/libsicudt.a" "$HOST_LIB_DIR/libicudt.a" 2>/dev/null || true
        fi
    fi
fi

# 现在仅构建 tools 目录（依赖上面已经生成的静态库和兼容名称）
log_info "构建 ICU 主机工具..."
run_command \
    "make -j${PARALLEL_JOBS:-4} CXXFLAGS=\"$HOST_CXXFLAGS\" -C tools" \
    "${LOGS_DIR}/build/icu_${ARCH}_host_build.log" \
    "编译 ICU 主机工具"

if [[ $? -ne 0 ]]; then
    log_error "ICU 主机工具编译失败"
    exit 1
fi

# 安装主机工具到临时目录再合并，避免 make install 时源与目标相同（同一构建目录）导致失败
INSTALL_STAGE="$HOST_BUILD_DIR/.install_stage"
rm -rf "$INSTALL_STAGE"
ensure_dir "${LOGS_DIR}/build"
log_info "安装 ICU 主机工具..."
if eval "make install DESTDIR=\"$INSTALL_STAGE\" prefix=\"\"" >> "${LOGS_DIR}/build/icu_${ARCH}_host_install.log" 2>&1; then
    log_success "安装 ICU 主机工具 完成"
    # 合并到 HOST_BUILD_DIR（覆盖 lib/include/bin）
    for d in lib include bin; do
        if [[ -d "$INSTALL_STAGE/$d" ]]; then
            mkdir -p "$HOST_BUILD_DIR/$d"
            cp -r "$INSTALL_STAGE/$d/"* "$HOST_BUILD_DIR/$d/" 2>/dev/null || true
        fi
    done
    rm -rf "$INSTALL_STAGE"
else
    log_warning "安装 ICU 主机工具 失败（可能源与目标相同），尝试保留已有 build 产物"
    rm -rf "$INSTALL_STAGE"
    # 若 include 缺失，从源码复制
    if [[ ! -d "$HOST_BUILD_DIR/include/unicode" ]] && [[ -d "$SOURCE_DIR/common/unicode" ]]; then
        mkdir -p "$HOST_BUILD_DIR/include/unicode"
        cp -r "$SOURCE_DIR/common/unicode/"* "$HOST_BUILD_DIR/include/unicode/" 2>/dev/null || true
        log_info "已从源码复制 include/unicode 到主机构建目录"
    fi
fi

# 再次确保兼容名称存在（合并时可能被覆盖）
if [[ -d "$HOST_LIB_DIR" ]]; then
    for _src in libsicuuc.a:libicuuc.a libsicuio.a:libicuio.a libsicutu.a:libicutu.a libsicuin.a:libicuin.a; do
        _s="${_src%%:*}"; _t="${_src##*:}"
        if [[ -f "$HOST_LIB_DIR/$_s" && ! -f "$HOST_LIB_DIR/$_t" ]]; then
            cp "$HOST_LIB_DIR/$_s" "$HOST_LIB_DIR/$_t" 2>/dev/null || true
        fi
    done
fi

# 确保主机工具在 PATH 中（用于后续的交叉编译）
HOST_BIN_DIR="$HOST_BUILD_DIR/bin"
if [[ -d "$HOST_BIN_DIR" ]]; then
    export PATH="$HOST_BIN_DIR:$PATH"
    log_info "已将 ICU 主机工具目录添加到 PATH: $HOST_BIN_DIR"
fi

# 恢复交叉编译环境变量
export CC="$SAVE_CC"
export CXX="$SAVE_CXX"
export CFLAGS="$SAVE_CFLAGS"
export CXXFLAGS="$SAVE_CXXFLAGS"
export LDFLAGS="$SAVE_LDFLAGS"
export AR="$SAVE_AR"
export LD="$SAVE_LD"
export RANLIB="$SAVE_RANLIB"
export SYSROOT="$SAVE_SYSROOT"

# 清理主机构建产物（保留工具）
cd "$SOURCE_DIR" || exit 1
make clean 2>/dev/null || true

# 创建交叉编译构建目录
BUILD_DIR=$(create_build_dir "icu" "$ARCH")
cd "$BUILD_DIR" || exit 1

# 解决 install 阶段缺少 LICENSE 文件的问题（由于 Windows 上解压 symlink 失败）
ICU_LICENSE_PATH="$SOURCE_DIR/../LICENSE"
if [[ ! -f "$ICU_LICENSE_PATH" ]]; then
    log_warning "未找到 ICU LICENSE 文件，创建占位 LICENSE 以避免安装失败"
    {
        echo "ICU License placeholder"
        echo "Original LICENSE file was not extracted correctly on this platform."
    } > "$ICU_LICENSE_PATH" 2>/dev/null || true
fi

log_step "配置 ICU 交叉编译..."

# 配置目标平台
# ICU 的 autotools 不认识 "ohos" 系统类型，使用 "linux-gnu" 代替
# 但保持使用 HarmonyOS 的编译器
# 注意：在 Git Bash 中，local 只能在函数内使用
icu_host="${TARGET_HOST/ohos/gnu}"
if [[ "$ARCH" == "arm64-v8a" ]]; then
    icu_host="aarch64-linux-gnu"
elif [[ "$ARCH" == "armeabi-v7a" ]]; then
    icu_host="arm-linux-gnueabihf"
elif [[ "$ARCH" == "x86_64" ]]; then
    icu_host="x86_64-linux-gnu"
fi

run_command \
    "\"$SOURCE_DIR/configure\" \
        --host=\"$icu_host\" \
        --prefix=\"$ARCH_INSTALL_DIR\" \
        --enable-static \
        --disable-shared \
        --disable-samples \
        --disable-tests \
        --with-cross-build=\"$HOST_BUILD_DIR\" \
        CC=\"$CC\" \
        CXX=\"$CXX\" \
        CFLAGS=\"$CFLAGS\" \
        CXXFLAGS=\"$CXXFLAGS\" \
        LDFLAGS=\"$LDFLAGS\"" \
    "${LOGS_DIR}/build/icu_${ARCH}_configure.log" \
    "配置 ICU 交叉编译"

if [[ $? -ne 0 ]]; then
    log_error "ICU 配置失败"
    exit 1
fi

# 确保主机工具在 PATH 中（用于交叉编译）
HOST_BIN_DIR="$HOST_BUILD_DIR/bin"
if [[ -d "$HOST_BIN_DIR" ]]; then
    export PATH="$HOST_BIN_DIR:$PATH"
    log_info "已将 ICU 主机工具目录添加到 PATH: $HOST_BIN_DIR"
fi

# 编译
log_step "编译 ICU..."
run_command \
    "make -j${PARALLEL_JOBS}" \
    "${LOGS_DIR}/build/icu_${ARCH}_build.log" \
    "编译 ICU"

if [[ $? -ne 0 ]]; then
    log_error "ICU 编译失败"
    exit 1
fi

# 安装
log_step "安装 ICU..."
run_command \
    "make install" \
    "${LOGS_DIR}/build/icu_${ARCH}_install.log" \
    "安装 ICU"

if [[ $? -ne 0 ]]; then
    log_error "ICU 安装失败"
    exit 1
fi

# 编译后验证
if ! verify_build_result "icu" "$ARCH" "libicuuc.a,libicudata.a,libicui18n.a" "unicode"; then
    log_error "ICU 编译验证失败"
    exit 1
fi

log_success "ICU 编译安装完成: $ARCH"
