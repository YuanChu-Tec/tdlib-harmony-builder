#!/bin/bash
# OpenSSL 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 OpenSSL for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "openssl" "$OPENSSL_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 OpenSSL 源码，请下载 OpenSSL 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译
if check_already_built "openssl" "$ARCH"; then
    log_info "OpenSSL 已经编译安装"
    exit 0
fi

# 创建构建目录
BUILD_DIR=$(create_build_dir "openssl" "$ARCH")
cd "$BUILD_DIR" || exit 1

log_step "配置 OpenSSL..."

# 根据架构选择配置
case $ARCH in
    arm64-v8a)
        OPENSSL_ARCH="linux-aarch64"
        ;;
    armeabi-v7a)
        OPENSSL_ARCH="linux-armv4"
        ;;
    x86_64)
        OPENSSL_ARCH="linux-x86_64"
        ;;
    *)
        log_error "不支持的架构: $ARCH"
        exit 1
        ;;
esac

# 配置 OpenSSL
run_command \
    "\"$SOURCE_DIR/Configure\" $OPENSSL_ARCH \
        --prefix=\"$ARCH_INSTALL_DIR\" \
        --openssldir=\"$ARCH_INSTALL_DIR\" \
        no-shared \
        no-dso \
        no-engine \
        no-unit-test \
        no-tests \
        -D__OHOS__ \
        -D__MUSL__=1 \
        -DOPENSSL_NO_SECURE_MEMORY \
        -DHAVE_FORK=0 \
        -DOPENSSL_SMALL_FOOTPRINT \
        -DOPENSSL_USE_NODELETE \
        -DOPENSSL_PIC \
        -DNDEBUG" \
    "${LOGS_DIR}/build/openssl_${ARCH}_configure.log" \
    "配置 OpenSSL"

if [[ $? -ne 0 ]]; then
    log_error "OpenSSL 配置失败"
    exit 1
fi

# 编译
log_step "编译 OpenSSL..."

# 对于 armeabi-v7a 架构，如果 sysroot 中没有 libatomic，需要从 Makefile 中移除 -latomic
# 或者使用编译器内置的原子操作支持
if [[ "$ARCH" == "armeabi-v7a" ]]; then
    # 检查 sysroot 中是否有 libatomic
    local atomic_lib=""
    if [[ -f "${SYSROOT}/usr/lib/libatomic.a" ]]; then
        atomic_lib="${SYSROOT}/usr/lib/libatomic.a"
    elif [[ -f "${SYSROOT}/lib/libatomic.a" ]]; then
        atomic_lib="${SYSROOT}/lib/libatomic.a"
    fi
    
    if [[ -z "$atomic_lib" ]]; then
        log_info "未找到 libatomic，尝试从 OpenSSL Makefile 中移除 -latomic"
        # 在编译前修改 Makefile，移除 -latomic
        if [[ -f "Makefile" ]]; then
            # 备份 Makefile
            cp Makefile Makefile.bak 2>/dev/null || true
            # 移除 -latomic（但保留其他库）
            sed -i 's/-latomic[[:space:]]*//g' Makefile 2>/dev/null || \
            sed -i.bak 's/-latomic[[:space:]]*//g' Makefile 2>/dev/null || true
            log_info "已从 Makefile 中移除 -latomic"
        fi
    fi
fi

run_command \
    "make -j${PARALLEL_JOBS}" \
    "${LOGS_DIR}/build/openssl_${ARCH}_build.log" \
    "编译 OpenSSL"

if [[ $? -ne 0 ]]; then
    log_error "OpenSSL 编译失败"
    exit 1
fi

# 安装（只安装软件，不安装文档）
log_step "安装 OpenSSL..."
run_command \
    "make install_sw" \
    "${LOGS_DIR}/build/openssl_${ARCH}_install.log" \
    "安装 OpenSSL"

if [[ $? -ne 0 ]]; then
    log_error "OpenSSL 安装失败"
    exit 1
fi

# 编译后验证
if ! verify_build_result "openssl" "$ARCH" "libssl.a,libcrypto.a" "openssl"; then
    log_error "OpenSSL 编译验证失败"
    exit 1
fi

log_success "OpenSSL 编译安装完成: $ARCH"
