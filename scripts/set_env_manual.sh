#!/bin/bash
# 手动编译 TDLib for HarmonyOS — 环境变量设置
# 用法: source scripts/set_env_manual.sh [arm64-v8a]
# 与 docs/MANUAL_BUILD_TDLIB_HARMONYOS.md 中的手动指南对应

ARCH="${1:-arm64-v8a}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 加载项目配置并设置工具链
if [[ -f "$PROJECT_ROOT/config.sh" ]]; then
    source "$PROJECT_ROOT/config.sh"
fi
if command -v set_toolchain &>/dev/null; then
    set_toolchain "$ARCH" 2>/dev/null || true
fi

# HarmonyOS SDK
export OHOS_SDK="${OHOS_SDK:-$OHOS_NDK}"
OHOS_SDK=$(echo "$OHOS_SDK" | sed 's|\\|/|g')
[[ -n "$OHOS_SDK" ]] && [[ "$OHOS_SDK" != *"/native"* ]] && [[ -d "${OHOS_SDK}/native" ]] && OHOS_SDK="${OHOS_SDK}/native"
export OHOS_SDK

# 工具链（优先使用 config 已设置的 CC/CXX）
if [[ -z "$CC" ]] && [[ -n "$OHOS_SDK" ]]; then
    case "$ARCH" in
        arm64-v8a) T=${OHOS_SDK}/llvm/bin/aarch64-unknown-linux-ohos-clang ;;
        armeabi-v7a) T=${OHOS_SDK}/llvm/bin/armv7a-unknown-linux-ohos-clang ;;
        x86_64) T=${OHOS_SDK}/llvm/bin/x86_64-unknown-linux-ohos-clang ;;
        *) T=${OHOS_SDK}/llvm/bin/aarch64-unknown-linux-ohos-clang ;;
    esac
    export CC="$T"
    export CXX="${T%clang}clang++"
fi
[[ -z "$AR" ]] && [[ -n "$OHOS_SDK" ]] && export AR="${OHOS_SDK}/llvm/bin/llvm-ar"
[[ -z "$RANLIB" ]] && [[ -n "$OHOS_SDK" ]] && export RANLIB="${OHOS_SDK}/llvm/bin/llvm-ranlib"
[[ -z "$STRIP" ]] && [[ -n "$OHOS_SDK" ]] && export STRIP="${OHOS_SDK}/llvm/bin/llvm-strip"

# CMake 工具链文件
export CMAKE_TOOLCHAIN="${CMAKE_TOOLCHAIN:-}"
if [[ -z "$CMAKE_TOOLCHAIN" ]] || [[ ! -f "$CMAKE_TOOLCHAIN" ]]; then
    for base in "$OHOS_SDK" "$OHOS_NDK"; do
        [[ -z "$base" ]] && continue
        base=$(echo "$base" | sed 's|\\|/|g')
        for p in "${base}/build/cmake/ohos.toolchain.cmake" "${base}/native/build/cmake/ohos.toolchain.cmake"; do
            [[ -f "$p" ]] && CMAKE_TOOLCHAIN="$p" && break 2
        done
    done
fi
export CMAKE_TOOLCHAIN

export SYSROOT="${SYSROOT:-${OHOS_SDK}/sysroot}"

# 工作目录（与项目布局一致）
export TD_SRC="${TD_SRC:-${PROJECT_ROOT}/src/extracted/td-${TDLIB_VERSION:-1.8.0}}"
export TD_BUILD="${TD_BUILD:-${ARCH_BUILD_DIR:-${PROJECT_ROOT}/build/${ARCH}}/tdlib}"
export TD_INSTALL="${TD_INSTALL:-${ARCH_INSTALL_DIR:-${PROJECT_ROOT}/install/${ARCH}}}"

echo "✅ 手动编译环境已设置 (ARCH=$ARCH)"
echo "   OHOS_SDK=$OHOS_SDK"
echo "   TD_SRC=$TD_SRC"
echo "   TD_BUILD=$TD_BUILD"
echo "   TD_INSTALL=$TD_INSTALL"
echo "   CMAKE_TOOLCHAIN=$CMAKE_TOOLCHAIN"
