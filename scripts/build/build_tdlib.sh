#!/bin/bash
# TDLib 主库编译脚本 for HarmonyOS（精简版，手动执行流程）

set -e

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH="${1:-}"
if [[ -z "$ARCH" ]]; then
    log_error "用法: $0 <架构>  例: $0 arm64-v8a"
    exit 1
fi

log_step "开始编译 TDLib for $ARCH"

# ------------------------------------------------------------------------------
# 1. 环境与路径
# ------------------------------------------------------------------------------
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

SOURCE_DIR=$(find_source_dir "tdlib" "$TDLIB_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 TDLib 源码，请下载 TDLib 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

if check_already_built "tdlib" "$ARCH"; then
    log_info "TDLib 已编译安装，跳过"
    exit 0
fi

BUILD_DIR=$(create_build_dir "tdlib" "$ARCH")
ensure_dir "${LOGS_DIR}/build" >&2

export PKG_CONFIG_PATH="${ARCH_INSTALL_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"
export C_INCLUDE_PATH="${ARCH_INSTALL_DIR}/include:${C_INCLUDE_PATH}"
export CPLUS_INCLUDE_PATH="${ARCH_INSTALL_DIR}/include:${CPLUS_INCLUDE_PATH}"
export LIBRARY_PATH="${ARCH_INSTALL_DIR}/lib:${LIBRARY_PATH}"

# ------------------------------------------------------------------------------
# 2. 工具链与 CMake
# ------------------------------------------------------------------------------
CMAKE_CMD="${OHOS_NDK}/native/build-tools/cmake/bin/cmake"
[[ ! -f "$CMAKE_CMD" ]] && CMAKE_CMD="cmake"

TOOLCHAIN_FILE="${OHOS_TOOLCHAIN_FILE:-}"
if [[ -z "$TOOLCHAIN_FILE" ]] && command -v get_toolchain_file &>/dev/null; then
    TOOLCHAIN_FILE=$(get_toolchain_file "$OHOS_NDK")
fi
if [[ -z "$TOOLCHAIN_FILE" ]] || [[ ! -f "$TOOLCHAIN_FILE" ]]; then
    ndk_path=$(echo "$OHOS_NDK" | sed 's|\\|/|g')
    TOOLCHAIN_FILE="${ndk_path}/build/cmake/ohos.toolchain.cmake"
    [[ ! -f "$TOOLCHAIN_FILE" ]] && TOOLCHAIN_FILE="${ndk_path}/native/build/cmake/ohos.toolchain.cmake"
fi
if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
    log_error "未找到工具链文件: $TOOLCHAIN_FILE"
    exit 1
fi

# Unix 风格路径（Windows 下）；编译器由工具链文件提供，不覆盖
to_unix() { echo "$1" | sed 's|C:|/c|;s|\\|/|g'; }
ARCH_INSTALL_UNIX=$(to_unix "$ARCH_INSTALL_DIR")
SOURCE_UNIX=$(to_unix "$SOURCE_DIR")
TOOLCHAIN_UNIX=$(to_unix "$TOOLCHAIN_FILE")

# ------------------------------------------------------------------------------
# 2.5 应用 HarmonyOS 适配补丁（线程亲和、EventFdPipe、AsyncFileLog 桩）
# ------------------------------------------------------------------------------
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$BUILD_SCRIPT_DIR/../.." && pwd)}"
PATCHES_DIR="${PATCHES_DIR:-$PROJECT_ROOT/patches}"
EVENTFD_PIPE_SRCDIR="$PATCHES_DIR/tdlib-eventfd-pipe"
TDLIB_PORT_DETAIL="$SOURCE_DIR/tdutils/td/utils/port/detail"

# 若缺少 EventFdPipe 源文件则从项目补丁目录复制（用于无 eventfd 时用 pipe 实现 AsyncFileLog）
if [[ ! -f "$TDLIB_PORT_DETAIL/EventFdPipe.h" ]] && [[ -d "$EVENTFD_PIPE_SRCDIR" ]]; then
  log_info "复制 EventFdPipe 源文件到 TDLib 源码..."
  for f in EventFdPipe.h EventFdPipe.cpp; do
    if [[ -f "$EVENTFD_PIPE_SRCDIR/$f" ]]; then
      cp "$EVENTFD_PIPE_SRCDIR/$f" "$TDLIB_PORT_DETAIL/$f"
    fi
  done
fi

# 检测补丁目标修改是否已存在于源码（避免对已打补丁的源码再次 patch 产生失败与警告）
check_patch_already_applied() {
  local p="$1"
  local src="$SOURCE_DIR"
  if [[ "$p" == "tdlib-harmony-thread-affinity.patch" ]]; then
    grep -q "defined(TD_HARMONYOS)" "$src/tdutils/td/utils/port/detail/ThreadPthread.h" 2>/dev/null && \
    grep -q "sched_setaffinity" "$src/tdutils/td/utils/port/detail/ThreadPthread.cpp" 2>/dev/null
    return $?
  fi
  if [[ "$p" == "tdlib-harmony-eventfd-pipe.patch" ]]; then
    grep -q "EventFdPipe" "$src/tdutils/td/utils/port/EventFd.h" 2>/dev/null && \
    grep -q "EventFdPipe.cpp" "$src/tdutils/CMakeLists.txt" 2>/dev/null
    return $?
  fi
  if [[ "$p" == "tdlib-harmony-asyncfilelog-eventfd.patch" ]]; then
    grep -q "TD_EVENTFD_UNSUPPORTED" "$src/tdutils/td/utils/AsyncFileLog.cpp" 2>/dev/null
    return $?
  fi
  return 1
}

for p in tdlib-harmony-thread-affinity.patch tdlib-harmony-eventfd-pipe.patch tdlib-harmony-asyncfilelog-eventfd.patch; do
  if [[ ! -f "$PATCHES_DIR/$p" ]]; then
    continue
  fi
  if check_patch_already_applied "$p"; then
    log_info "补丁已存在: $p，跳过"
  elif apply_patch "$PATCHES_DIR/$p" "$SOURCE_DIR"; then
    :
  else
    log_error "TDLib 补丁应用失败: $p，请检查源码是否为未修改的 TDLib 或参见 docs/TDLIB_HARMONYOS_PATCHES.md"
    exit 1
  fi
done

# ------------------------------------------------------------------------------
# 3. 前置条件：API 文件与 CMake 版本
# ------------------------------------------------------------------------------
MT_PROTO_H="$SOURCE_DIR/td/mtproto/mtproto_api.h"
MT_PROTO_AUTO="$SOURCE_DIR/td/generate/auto/td/mtproto/mtproto_api.h"

need_generate=false
if [[ ! -f "$MT_PROTO_H" ]] && [[ ! -f "$MT_PROTO_AUTO" ]]; then
    need_generate=true
elif [[ -f "$MT_PROTO_H" ]] && grep -q "Auto-generated placeholder\|Placeholder for HarmonyOS" "$MT_PROTO_H" 2>/dev/null; then
    need_generate=true
fi

if [[ "$need_generate" == "true" ]]; then
    log_step "真实生成 API 文件（主机端 tl-parser + generate_common）"
    gen_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/generate_tdlib_api.sh"
    if ! "$gen_script" "$ARCH"; then
        log_error "API 生成失败，无法继续编译 TDLib。参见: docs/TDLIB_API_GENERATION_FIX.md"
        exit 1
    fi
    log_success "API 文件已生成"
fi

if [[ ! -f "$MT_PROTO_H" ]] && [[ -f "$MT_PROTO_AUTO" ]]; then
    ensure_dir "$(dirname "$MT_PROTO_H")" >&2
    # 创建包装文件，避免与 auto 目录下的文件重复定义
    # 如果文件已存在但不是包装文件，则替换为包装文件
    if ! grep -q "Wrapper to include the actual generated" "$MT_PROTO_H" 2>/dev/null; then
        cat > "$MT_PROTO_H" << 'EOF'
#pragma once
// Wrapper to include the actual generated mtproto_api.h
// This avoids redefinition errors when both td/mtproto/mtproto_api.h and
// td/generate/auto/td/mtproto/mtproto_api.h are included.
#include "../generate/auto/td/mtproto/mtproto_api.h"
EOF
        log_info "已创建/更新 mtproto_api.h 包装文件到 td/mtproto/"
    fi
fi

if [[ ! -f "$MT_PROTO_H" ]] || [[ ! -s "$MT_PROTO_H" ]]; then
    log_error "缺少 mtproto_api.h，无法编译 TDLib"
    log_error "请先运行 ./scripts/build/generate_tdlib_api.sh 或参见: docs/TDLIB_API_GENERATION_FIX.md"
    exit 1
fi

if grep -q "Auto-generated placeholder\|Placeholder for HarmonyOS" "$MT_PROTO_H" 2>/dev/null; then
    log_warning "mtproto_api.h 仍为占位符，编译可能失败。请运行 ./scripts/build/generate_tdlib_api.sh 生成真实 API。"
fi

# 放宽 CMake 版本要求
for f in "$SOURCE_DIR/CMakeLists.txt" "$SOURCE_DIR/td/generate/tl-parser/CMakeLists.txt"; do
    [[ ! -f "$f" ]] && continue
    if grep -q "cmake_minimum_required(VERSION 3\.0" "$f" 2>/dev/null; then
        sed -i.bak 's/3\.0\.2/3.5/g;s/3\.0 FATAL/3.5 FATAL/g' "$f" 2>/dev/null || true
    fi
done

ensure_dir "$SOURCE_DIR/tdutils/generate/auto" >&2
ensure_dir "$SOURCE_DIR/td/generate/auto/td/telegram" >&2
ensure_dir "$SOURCE_DIR/td/generate/auto/td/mtproto" >&2

# MIME 占位符（若无 gperf 生成文件）
GEN="$SOURCE_DIR/tdutils/generate/auto"
if [[ ! -f "$GEN/mime_type_to_extension.cpp" ]]; then
    log_info "创建 MIME 占位符: mime_type_to_extension.cpp"
    printf '%s\n' '// placeholder' '#include <cstddef>' 'const char* mime_type_to_extension(const char*, size_t) { return nullptr; }' > "$GEN/mime_type_to_extension.cpp"
fi
if [[ ! -f "$GEN/extension_to_mime_type.cpp" ]]; then
    log_info "创建 MIME 占位符: extension_to_mime_type.cpp"
    printf '%s\n' '// placeholder' '#include <cstddef>' 'const char* extension_to_mime_type(const char*, size_t) { return nullptr; }' > "$GEN/extension_to_mime_type.cpp"
fi

# ------------------------------------------------------------------------------
# 4. 配置
# ------------------------------------------------------------------------------
log_step "配置 TDLib"
# 清理旧配置，避免复用错误编译器缓存（工具链使用 clang/clang++，非 aarch64-*-clang++）
rm -rf "$BUILD_DIR"
ensure_dir "$BUILD_DIR" >&2
cd "$BUILD_DIR"

LOG_CONFIGURE="${LOGS_DIR}/build/tdlib_${ARCH}_configure.log"

# 检测 OpenSSL 库文件位置（x86_64 架构可能安装到 lib64）
OPENSSL_CRYPTO_LIB="${ARCH_INSTALL_DIR}/lib/libcrypto.a"
OPENSSL_SSL_LIB="${ARCH_INSTALL_DIR}/lib/libssl.a"
if [[ "$ARCH" == "x86_64" ]]; then
    if [[ -f "${ARCH_INSTALL_DIR}/lib64/libcrypto.a" ]]; then
        OPENSSL_CRYPTO_LIB="${ARCH_INSTALL_DIR}/lib64/libcrypto.a"
        OPENSSL_SSL_LIB="${ARCH_INSTALL_DIR}/lib64/libssl.a"
        log_info "检测到 OpenSSL 在 lib64 目录（x86_64 架构）"
    fi
fi
OPENSSL_CRYPTO_LIB_UNIX=$(to_unix "$OPENSSL_CRYPTO_LIB")
OPENSSL_SSL_LIB_UNIX=$(to_unix "$OPENSSL_SSL_LIB")

"$CMAKE_CMD" "$SOURCE_DIR" \
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
    -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_CRYPTO_LIB_UNIX" \
    -DOPENSSL_SSL_LIBRARY="$OPENSSL_SSL_LIB_UNIX" \
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
    -DCMAKE_C_FLAGS="$CFLAGS -DOHOS -DTD_EVENTFD_PIPE=1" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS -DOHOS -Wno-deprecated-declarations -DTD_EVENTFD_PIPE=1 -DTD_HARMONYOS=1" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
    >"$LOG_CONFIGURE" 2>&1 || {
    log_error "配置失败，见: $LOG_CONFIGURE"
    exit 1
}
log_success "配置完成"

# ------------------------------------------------------------------------------
# 5. 编译与安装
# ------------------------------------------------------------------------------
log_step "编译 TDLib"
LOG_BUILD="${LOGS_DIR}/build/tdlib_${ARCH}_build.log"
"$CMAKE_CMD" --build . -j"${PARALLEL_JOBS:-4}" >"$LOG_BUILD" 2>&1 || {
    log_error "编译失败，见: $LOG_BUILD"
    exit 1
}
log_success "编译完成"

log_step "安装 TDLib"
"$CMAKE_CMD" --install . >"${LOGS_DIR}/build/tdlib_${ARCH}_install.log" 2>&1 || {
    log_error "安装失败"
    exit 1
}
log_success "安装完成"

# 创建 libtdjson.a 符号链接（如果存在 libtdjson_static.a）
# TDLib 生成的是 libtdjson_static.a，但验证脚本期望 libtdjson.a
if [[ -f "$ARCH_INSTALL_DIR/lib/libtdjson_static.a" ]] && [[ ! -f "$ARCH_INSTALL_DIR/lib/libtdjson.a" ]]; then
    log_info "创建 libtdjson.a 符号链接指向 libtdjson_static.a"
    cd "$ARCH_INSTALL_DIR/lib" || exit 1
    # Windows/MSYS 上使用硬链接或复制，Unix 上使用符号链接
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
        # Windows: 使用复制（符号链接可能不被所有工具支持）
        cp -f "libtdjson_static.a" "libtdjson.a" || {
            log_warning "无法创建 libtdjson.a，但 libtdjson_static.a 存在"
        }
    else
        # Unix: 使用符号链接
        ln -sf "libtdjson_static.a" "libtdjson.a" || {
            log_warning "无法创建 libtdjson.a 符号链接，但 libtdjson_static.a 存在"
        }
    fi
fi

# ------------------------------------------------------------------------------
# 6. 验证
# ------------------------------------------------------------------------------
TDLIB_LIBS="libtdclient.a,libtdcore.a,libtdapi.a"
if [[ -f "$ARCH_INSTALL_DIR/lib/libtdjson.so" ]]; then
    TDLIB_LIBS="libtdjson.so,libtdclient.a,libtdcore.a,libtdapi.a"
fi
# 如果存在 libtdjson.a（或 libtdjson_static.a），也加入验证列表
if [[ -f "$ARCH_INSTALL_DIR/lib/libtdjson.a" ]] || [[ -f "$ARCH_INSTALL_DIR/lib/libtdjson_static.a" ]]; then
    # 如果 TDLIB_LIBS 中还没有 libtdjson.a，添加它
    if [[ "$TDLIB_LIBS" != *"libtdjson.a"* ]]; then
        TDLIB_LIBS="libtdjson.a,$TDLIB_LIBS"
    fi
fi
if ! verify_build_result "tdlib" "$ARCH" "$TDLIB_LIBS" "td/telegram"; then
    log_error "tdlib 编译验证未通过"
    exit 1
fi

log_success "TDLib 编译完成: $ARCH"
