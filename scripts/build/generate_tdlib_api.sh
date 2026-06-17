#!/bin/bash
# 真实生成 TDLib API 文件（主机端 tl-parser + generate_common）
# 用法: ./generate_tdlib_api.sh [arch]
# 生成后可直接用于 build_tdlib.sh / build_tdlib_manual.sh 交叉编译
# 参见: docs/TDLIB_API_GENERATION_FIX.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "${SCRIPT_DIR}/../common.sh"

ARCH="${1:-arm64-v8a}"
# ARCH 仅用于日志/目录命名，API 生成为主机端，与目标架构无关

# 加载配置并解析源码路径（不设置交叉工具链）
if [[ -f "$PROJECT_ROOT/config.sh" ]]; then
    source "$PROJECT_ROOT/config.sh"
fi

SOURCE_DIR=$(find_source_dir "td" "$TDLIB_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 TDLib 源码，请先运行下载与解压脚本"
    exit 1
fi

LOG_DIR="${LOGS_DIR:-$PROJECT_ROOT/logs}/build"
HOST_BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}/tdlib-api-generator"
PATCHES_DIR="${PATCHES_DIR:-$PROJECT_ROOT/patches}"
ensure_dir "$LOG_DIR" >&2
ensure_dir "$HOST_BUILD_DIR" >&2

log_step "真实生成 TDLib API 文件"

# ------------------------------------------------------------------------------
# 1. Windows/MSYS2：修复 wgetopt（tl-parser 用）
# ------------------------------------------------------------------------------
is_windows=false
[[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "${WINDIR:-}" ]] || [[ "$MSYSTEM" == "MINGW"* ]] && is_windows=true

if [[ "$is_windows" == "true" ]]; then
    log_info "检测到 Windows/MSYS2，应用 wgetopt 兼容修复..."
    WGETOPT_H="$SOURCE_DIR/td/generate/tl-parser/wgetopt.h"
    WGETOPT_C="$SOURCE_DIR/td/generate/tl-parser/wgetopt.c"
    PATCH_H="$PATCHES_DIR/tdlib-tl-parser-wgetopt-windows.patch"
    FIX_PY="$PROJECT_ROOT/scripts/fix_wgetopt_c_windows.py"

    if [[ -f "$WGETOPT_H" ]] && [[ -f "$PATCH_H" ]]; then
        if grep -q "extern int getopt ();" "$WGETOPT_H" 2>/dev/null; then
            (cd "$SOURCE_DIR" && patch -p1 -l -i "$PATCH_H" -r - --forward) >>"$LOG_DIR/generate_tdlib_api_wgetopt_patch.log" 2>&1 && true || true
            grep -q "getopt (int ___argc" "$WGETOPT_H" 2>/dev/null && log_info "已应用 wgetopt.h 补丁" || log_warning "wgetopt.h 补丁可能未完全应用，将依赖 fix_wgetopt_c_windows.py"
        fi
    fi
    if [[ -f "$WGETOPT_C" ]] && [[ -f "$FIX_PY" ]]; then
        python3 "$FIX_PY" "$WGETOPT_C" >>"$LOG_DIR/generate_tdlib_api_wgetopt_fix.log" 2>&1 || true
        log_info "已运行 fix_wgetopt_c_windows.py"
    fi
fi

# ------------------------------------------------------------------------------
# 2. CMake 版本（tl-parser 要求 3.5+）
# ------------------------------------------------------------------------------
for f in "$SOURCE_DIR/CMakeLists.txt" "$SOURCE_DIR/td/generate/tl-parser/CMakeLists.txt"; do
    [[ ! -f "$f" ]] && continue
    if grep -q "cmake_minimum_required(VERSION 3\.0" "$f" 2>/dev/null; then
        sed -i.bak 's/3\.0\.2/3.5/g;s/3\.0 FATAL/3.5 FATAL/g' "$f" 2>/dev/null || true
    fi
done

# ------------------------------------------------------------------------------
# 3. 主机构建目录与配置（不使用工具链）
# ------------------------------------------------------------------------------
# 若由 build_tdlib.sh 调用，当前环境已包含交叉编译的 CC/CXX/CFLAGS/LDFLAGS，
# 会导致 CMake 用 OHOS 的 clang 配置“主机”生成器，链接时混用 lld 与 Windows 库而失败。
# 此处显式清除，让 CMake 使用主机原生编译器（如 MSYS2 的 g++）。
unset CC CXX CFLAGS CXXFLAGS LDFLAGS AR RANLIB STRIP
unset CMAKE_TOOLCHAIN_FILE

# 若目录内存在旧 CMake 缓存（可能含 OHOS 的 CFLAGS/CXXFLAGS），清理后重新配置，
# 否则 g++ 会收到 -target aarch64-linux-ohos 等参数而报错。
if [[ -f "$HOST_BUILD_DIR/CMakeCache.txt" ]] || [[ -d "$HOST_BUILD_DIR/CMakeFiles" ]]; then
    rm -f "$HOST_BUILD_DIR/CMakeCache.txt"
    rm -rf "$HOST_BUILD_DIR/CMakeFiles"
fi

cd "$HOST_BUILD_DIR"
LOG_CFG="$LOG_DIR/generate_tdlib_api_configure.log"
CMAKE_CMD="cmake"
[[ -x "${OHOS_NDK}/native/build-tools/cmake/bin/cmake" ]] && CMAKE_CMD="${OHOS_NDK}/native/build-tools/cmake/bin/cmake"

# 显式指定主机编译器，避免 CMake 误用交叉编译器（或 PATH 中优先的 OHOS 工具链）
# 优先使用 user_config.sh 中的 HOST_CC/HOST_CXX；Windows 上自动检测 gcc/g++ 或 clang/clang++
HOST_CMAKE_EXTRA=()
if [[ -n "${HOST_CC:-}" ]] && [[ -n "${HOST_CXX:-}" ]]; then
    HOST_CMAKE_EXTRA=(-DCMAKE_C_COMPILER="$HOST_CC" -DCMAKE_CXX_COMPILER="$HOST_CXX")
elif [[ "$is_windows" == "true" ]]; then
    if command -v gcc &>/dev/null && command -v g++ &>/dev/null; then
        HOST_CMAKE_EXTRA=(-DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++)
    elif command -v clang &>/dev/null && command -v clang++ &>/dev/null; then
        HOST_CMAKE_EXTRA=(-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++)
    fi
fi

log_info "配置主机代码生成器 (无工具链)..."
"$CMAKE_CMD" "$SOURCE_DIR" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_C_FLAGS= \
    -DCMAKE_CXX_FLAGS= \
    -DCMAKE_EXE_LINKER_FLAGS= \
    -DTD_ENABLE_JNI=OFF \
    -DTD_ENABLE_DOTNET=OFF \
    -DTD_ENABLE_PARSER=OFF \
    -DTD_ENABLE_OPENSSL=OFF \
    -DTD_ENABLE_LTO=OFF \
    -DTDUTILS_MIME_TYPE=ON \
    "${HOST_CMAKE_EXTRA[@]}" \
    >"$LOG_CFG" 2>&1 || {
    log_error "主机代码生成器配置失败，见 $LOG_CFG"
    exit 1
}
log_success "配置完成"

# ------------------------------------------------------------------------------
# 4. 构建 tl_generate_mtproto、tl_generate_common、tl_generate_json（生成 API 文件）
#    mtproto_api.h 由 tl_generate_mtproto 生成，td_api/telegram_api 等由 tl_generate_common 生成
# ------------------------------------------------------------------------------
LOG_BLD="$LOG_DIR/generate_tdlib_api_build.log"
log_info "构建 tl-parser、generate_mtproto、generate_common、generate_json 并生成 API 文件..."
"$CMAKE_CMD" --build . --target tl_generate_mtproto -j"${PARALLEL_JOBS:-4}" >"$LOG_BLD" 2>&1 || {
    log_error "构建/生成 tl_generate_mtproto 失败，见 $LOG_BLD"
    exit 1
}
log_info "tl_generate_mtproto 完成，继续 tl_generate_common..."
"$CMAKE_CMD" --build . --target tl_generate_common -j"${PARALLEL_JOBS:-4}" >>"$LOG_BLD" 2>&1 || {
    log_error "构建/生成 tl_generate_common 失败，见 $LOG_BLD"
    exit 1
}
log_info "tl_generate_common 完成，继续生成 JSON API 文件..."
"$CMAKE_CMD" --build . --target tl_generate_json -j"${PARALLEL_JOBS:-4}" >>"$LOG_BLD" 2>&1 || {
    log_error "构建/生成 tl_generate_json 失败，见 $LOG_BLD"
    exit 1
}
log_success "API 生成完成（含 JSON）"

# ------------------------------------------------------------------------------
# 5. 创建 td/mtproto/mtproto_api.h 包装文件（避免重复定义）
# ------------------------------------------------------------------------------
AUTO_MT="$SOURCE_DIR/td/generate/auto/td/mtproto/mtproto_api.h"
MT_SRC="$SOURCE_DIR/td/mtproto/mtproto_api.h"
if [[ -f "$AUTO_MT" ]]; then
    ensure_dir "$(dirname "$MT_SRC")" >&2
    # 检查是否已经是包装文件，如果不是，则替换为包装文件（避免重复定义）
    if [[ ! -f "$MT_SRC" ]] || ! grep -q "Wrapper to include the actual generated" "$MT_SRC" 2>/dev/null; then
        cat > "$MT_SRC" << 'EOF'
#pragma once
// Wrapper to include the actual generated mtproto_api.h
// This avoids redefinition errors when both td/mtproto/mtproto_api.h and
// td/generate/auto/td/mtproto/mtproto_api.h are included.
#include "../generate/auto/td/mtproto/mtproto_api.h"
EOF
        log_info "已创建/更新 mtproto_api.h 包装文件到 td/mtproto/"
    fi
fi

# ------------------------------------------------------------------------------
# 6. 验证生成结果
# ------------------------------------------------------------------------------
if [[ ! -f "$MT_SRC" ]] || [[ ! -s "$MT_SRC" ]]; then
    log_error "mtproto_api.h 缺失或为空，生成可能失败"
    exit 1
fi
if grep -q "Auto-generated placeholder\|Placeholder for HarmonyOS" "$MT_SRC" 2>/dev/null; then
    log_error "mtproto_api.h 仍为占位符，未生成真实 API"
    exit 1
fi

TD_API_H="$SOURCE_DIR/td/generate/auto/td/telegram/td_api.h"
if [[ ! -f "$TD_API_H" ]] || [[ ! -s "$TD_API_H" ]]; then
    log_error "td_api.h 缺失或为空"
    exit 1
fi

# TDLib 生成 td_api_json_0.cpp～td_api_json_9.cpp 和 td_api_json.h，无单一 td_api_json.cpp
TD_API_JSON_0_CPP="$SOURCE_DIR/td/generate/auto/td/telegram/td_api_json_0.cpp"
TD_API_JSON_H="$SOURCE_DIR/td/generate/auto/td/telegram/td_api_json.h"
if [[ ! -f "$TD_API_JSON_0_CPP" ]] || [[ ! -s "$TD_API_JSON_0_CPP" ]]; then
    log_error "td_api_json_0.cpp 缺失或为空，JSON API 生成可能失败"
    exit 1
fi
if [[ ! -f "$TD_API_JSON_H" ]] || [[ ! -s "$TD_API_JSON_H" ]]; then
    log_error "td_api_json.h 缺失或为空，JSON API 生成可能失败"
    exit 1
fi

log_success "真实 API 文件已生成，可用于交叉编译"
log_info "  mtproto: $MT_SRC"
log_info "  td_api:  $TD_API_H"
log_info "  td_api_json: td_api_json_0..9.cpp, $TD_API_JSON_H"
