#!/bin/bash
# 按《手动编译 TDLib for HarmonyOS 详细指南》自动执行的手动流程
# 用法: ./build_tdlib_manual.sh [arm64-v8a] [--skip-deps] [--placeholder-api]
# 参见: docs/MANUAL_BUILD_TDLIB_HARMONYOS.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

ARCH="arm64-v8a"
SKIP_DEPS=false
USE_PLACEHOLDER_API=false
for arg in "$@"; do
    case "$arg" in
        --skip-deps) SKIP_DEPS=true ;;
        --placeholder-api) USE_PLACEHOLDER_API=true ;;
        arm64-v8a|armeabi-v7a|x86_64) ARCH="$arg" ;;
    esac
done
[[ -n "$1" ]] && [[ "$1" != --* ]] && ARCH="$1"

log_step "手动编译 TDLib for HarmonyOS: $ARCH"

# ------------------------------------------------------------------------------
# 1. 环境与路径（对应指南 §1）
# ------------------------------------------------------------------------------
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

SOURCE_DIR=$(find_source_dir "td" "$TDLIB_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 TDLib 源码，请先运行下载与解压脚本"
    exit 1
fi

BUILD_DIR=$(create_build_dir "tdlib" "$ARCH")
export TD_SRC="$SOURCE_DIR"
export TD_BUILD="$BUILD_DIR"
export TD_INSTALL="$ARCH_INSTALL_DIR"
ensure_dir "${LOGS_DIR}/build" >&2

log_info "TD_SRC=$TD_SRC"
log_info "TD_BUILD=$TD_BUILD"
log_info "TD_INSTALL=$TD_INSTALL"

# ------------------------------------------------------------------------------
# 2. 编译依赖（对应指南 §3）
# ------------------------------------------------------------------------------
if [[ "$SKIP_DEPS" != "true" ]]; then
    log_step "编译依赖库 (顺序同 build_all.sh)"
    for script in build_zlib build_openssl build_sqlite build_icu build_protobuf \
                  build_crc32c build_xxhash build_abseil build_re2 build_libevent \
                  build_lz4 build_snappy build_double_conversion build_libphonenumber; do
        path="${SCRIPT_DIR}/${script}.sh"
        if [[ -f "$path" ]]; then
            log_info "运行 $script..."
            "$path" "$ARCH" >/dev/null 2>&1 || true
        fi
    done
    log_success "依赖库就绪"
else
    log_info "跳过依赖编译 (--skip-deps)"
fi

# ------------------------------------------------------------------------------
# 3. API 文件与占位符（对应指南 §2）
# ------------------------------------------------------------------------------
MT_H="$SOURCE_DIR/td/mtproto/mtproto_api.h"
MT_AUTO="$SOURCE_DIR/td/generate/auto/td/mtproto/mtproto_api.h"
need_placeholder=false
need_generate=false

if [[ "$USE_PLACEHOLDER_API" == "true" ]]; then
    need_placeholder=true
elif [[ ! -f "$MT_H" ]] && [[ ! -f "$MT_AUTO" ]]; then
    need_generate=true
elif [[ -f "$MT_H" ]] && grep -q "Auto-generated placeholder\|Placeholder for HarmonyOS" "$MT_H" 2>/dev/null; then
    need_generate=true
fi

if [[ "$need_generate" == "true" ]]; then
    log_step "真实生成 API 文件（主机端 tl-parser + generate_common）"
    gen_script="${SCRIPT_DIR}/generate_tdlib_api.sh"
    if ! "$gen_script" "$ARCH"; then
        log_error "API 生成失败。可改用 --placeholder-api 使用占位符，或参见 docs/TDLIB_API_GENERATION_FIX.md"
        exit 1
    fi
    log_success "API 文件已生成"
    need_placeholder=false
fi

if [[ "$need_placeholder" == "true" ]]; then
    log_step "创建 API 占位符（对应指南 §2.1）"
    source "${SCRIPT_DIR}/ensure_manual_api_placeholders.sh"
    log_warning "使用占位符 API；编译可能通过配置，但链接会因缺少符号失败。完整编译请先生成真实 API，参见 docs/TDLIB_API_GENERATION_FIX.md"
else
    log_info "使用已有/已生成 API 文件"
    if [[ ! -f "$MT_H" ]] && [[ -f "$MT_AUTO" ]]; then
        ensure_dir "$(dirname "$MT_H")" >&2
        # 创建包装文件，避免与 auto 目录下的文件重复定义
        # 如果文件已存在但不是包装文件，则替换为包装文件
        if ! grep -q "Wrapper to include the actual generated" "$MT_H" 2>/dev/null; then
            cat > "$MT_H" << 'EOF'
#pragma once
// Wrapper to include the actual generated mtproto_api.h
// This avoids redefinition errors when both td/mtproto/mtproto_api.h and
// td/generate/auto/td/mtproto/mtproto_api.h are included.
#include "../generate/auto/td/mtproto/mtproto_api.h"
EOF
            log_info "已创建/更新 mtproto_api.h 包装文件到 td/mtproto/"
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 4. 工具链与 CMake
# ------------------------------------------------------------------------------
CMAKE_CMD="${OHOS_NDK}/native/build-tools/cmake/bin/cmake"
[[ ! -f "$CMAKE_CMD" ]] && CMAKE_CMD="cmake"

TOOLCHAIN_FILE="${OHOS_TOOLCHAIN_FILE:-}"
[[ -z "$TOOLCHAIN_FILE" ]] && command -v get_toolchain_file &>/dev/null && TOOLCHAIN_FILE=$(get_toolchain_file "$OHOS_NDK")
if [[ -z "$TOOLCHAIN_FILE" ]] || [[ ! -f "$TOOLCHAIN_FILE" ]]; then
    ndk_path=$(echo "$OHOS_NDK" | sed 's|\\|/|g')
    TOOLCHAIN_FILE="${ndk_path}/build/cmake/ohos.toolchain.cmake"
    [[ ! -f "$TOOLCHAIN_FILE" ]] && TOOLCHAIN_FILE="${ndk_path}/native/build/cmake/ohos.toolchain.cmake"
fi
[[ ! -f "$TOOLCHAIN_FILE" ]] && { log_error "未找到工具链文件"; exit 1; }

# 编译器由工具链文件提供，不覆盖（避免 aarch64-*-clang++ 在 Windows 上 not a valid Win32 application）
to_unix() { echo "$1" | sed 's|C:|/c|;s|\\|/|g'; }
ARCH_INSTALL_UNIX=$(to_unix "$ARCH_INSTALL_DIR")
SOURCE_UNIX=$(to_unix "$SOURCE_DIR")
TOOLCHAIN_UNIX=$(to_unix "$TOOLCHAIN_FILE")

# CMake 版本
for f in "$SOURCE_DIR/CMakeLists.txt" "$SOURCE_DIR/td/generate/tl-parser/CMakeLists.txt"; do
    [[ ! -f "$f" ]] && continue
    grep -q "cmake_minimum_required(VERSION 3\.0" "$f" 2>/dev/null && sed -i.bak 's/3\.0\.2/3.5/g;s/3\.0 FATAL/3.5 FATAL/g' "$f" 2>/dev/null || true
done

# ------------------------------------------------------------------------------
# 5. 配置（对应指南 §4）
# ------------------------------------------------------------------------------
log_step "配置 TDLib (对应指南 §4.2)"
rm -rf "$BUILD_DIR"
ensure_dir "$BUILD_DIR" >&2
cd "$BUILD_DIR"

LOG_CFG="${LOGS_DIR}/build/tdlib_manual_${ARCH}_configure.log"
"$CMAKE_CMD" "$SOURCE_DIR" \
    -GNinja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_UNIX" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DOHOS_ARCH="$ARCH" \
    -DOHOS_STL=c++_static \
    -DOHOS_PLATFORM=OHOS \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$ARCH_INSTALL_UNIX" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=$(echo "$ARCH" | sed 's/arm64-v8a/aarch64/;s/armeabi-v7a/arm/;s/x86_64/x86_64/') \
    -DOPENSSL_USE_STATIC_LIBS=TRUE \
    -DOPENSSL_ROOT_DIR="$ARCH_INSTALL_UNIX" \
    -DOPENSSL_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DOPENSSL_CRYPTO_LIBRARY="$ARCH_INSTALL_UNIX/lib/libcrypto.a" \
    -DOPENSSL_SSL_LIBRARY="$ARCH_INSTALL_UNIX/lib/libssl.a" \
    -DZLIB_FOUND=TRUE \
    -DZLIB_ROOT="$ARCH_INSTALL_UNIX" \
    -DZLIB_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DZLIB_LIBRARY="$ARCH_INSTALL_UNIX/lib/libz.a" \
    -DZLIB_LIBRARIES="$ARCH_INSTALL_UNIX/lib/libz.a" \
    -DSQLite3_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DSQLite3_LIBRARY="$ARCH_INSTALL_UNIX/lib/libsqlite3.a" \
    -DICU_ROOT="$ARCH_INSTALL_UNIX" \
    -DICU_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DPROTOBUF_ROOT="$ARCH_INSTALL_UNIX" \
    -DPROTOBUF_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DPROTOBUF_LIBRARY="$ARCH_INSTALL_UNIX/lib/libprotobuf.a" \
    -DCRC32C_ROOT="$ARCH_INSTALL_UNIX" \
    -DCRC32C_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DCRC32C_LIBRARY="$ARCH_INSTALL_UNIX/lib/libcrc32c.a" \
    -DXXHASH_ROOT="$ARCH_INSTALL_UNIX" \
    -DXXHASH_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DXXHASH_LIBRARY="$ARCH_INSTALL_UNIX/lib/libxxhash.a" \
    -DLIBEVENT_ROOT="$ARCH_INSTALL_UNIX" \
    -DLIBEVENT_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DLIBEVENT_LIBRARY="$ARCH_INSTALL_UNIX/lib/libevent.a" \
    -DLZ4_ROOT="$ARCH_INSTALL_UNIX" \
    -DLZ4_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DLZ4_LIBRARY="$ARCH_INSTALL_UNIX/lib/liblz4.a" \
    -DSNAPPY_ROOT="$ARCH_INSTALL_UNIX" \
    -DSNAPPY_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DSNAPPY_LIBRARY="$ARCH_INSTALL_UNIX/lib/libsnappy.a" \
    -DDOUBLE_CONVERSION_ROOT="$ARCH_INSTALL_UNIX" \
    -DDOUBLE_CONVERSION_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DDOUBLE_CONVERSION_LIBRARY="$ARCH_INSTALL_UNIX/lib/libdouble-conversion.a" \
    -DLIBPHONENUMBER_ROOT="$ARCH_INSTALL_UNIX" \
    -DLIBPHONENUMBER_INCLUDE_DIR="$ARCH_INSTALL_UNIX/include" \
    -DLIBPHONENUMBER_LIBRARY="$ARCH_INSTALL_UNIX/lib/libphonenumber.a" \
    -DCMAKE_PREFIX_PATH="$ARCH_INSTALL_UNIX" \
    -DTD_ENABLE_LTO=ON \
    -DTD_ENABLE_JNI=OFF \
    -DTD_ENABLE_DOTNET=OFF \
    -DTD_ENABLE_PARSER=OFF \
    -DTD_ENABLE_OPENSSL=ON \
    -DTDUTILS_MIME_TYPE=ON \
    -DBUILD_AUTO_TOOLS=OFF \
    -DBUILD_GENERATOR=OFF \
    -DCMAKE_C_FLAGS="$CFLAGS -DOHOS -DTD_EVENTFD_UNSUPPORTED=1" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS -DOHOS -Wno-deprecated-declarations -DTD_EVENTFD_UNSUPPORTED=1 -DTD_HARMONYOS=1" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
    >"$LOG_CFG" 2>&1 || { log_error "配置失败，见 $LOG_CFG"; exit 1; }
log_success "配置完成"

# ------------------------------------------------------------------------------
# 6. 编译与安装（对应指南 §5）
# ------------------------------------------------------------------------------
log_step "编译 TDLib"
LOG_BLD="${LOGS_DIR}/build/tdlib_manual_${ARCH}_build.log"
"$CMAKE_CMD" --build . -j"${PARALLEL_JOBS:-4}" >"$LOG_BLD" 2>&1 || { log_error "编译失败，见 $LOG_BLD"; exit 1; }
log_success "编译完成"

log_step "安装 TDLib"
"$CMAKE_CMD" --install . >"${LOGS_DIR}/build/tdlib_manual_${ARCH}_install.log" 2>&1 || { log_error "安装失败"; exit 1; }
log_success "安装完成"

# ------------------------------------------------------------------------------
# 7. 验证（对应指南 §8）
# ------------------------------------------------------------------------------
TDLIB_LIBS="libtdclient.a,libtdcore.a,libtdapi.a"
[[ -f "$ARCH_INSTALL_DIR/lib/libtdjson.so" ]] && TDLIB_LIBS="libtdjson.so,libtdclient.a,libtdcore.a,libtdapi.a"
if ! verify_build_result "tdlib" "$ARCH" "$TDLIB_LIBS" "td/telegram"; then
    log_error "tdlib 验证未通过"
    exit 1
fi

log_success "手动编译 TDLib 完成: $ARCH"
