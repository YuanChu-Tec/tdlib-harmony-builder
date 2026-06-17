#!/bin/bash
# double-conversion 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 double-conversion for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "double-conversion" "$DOUBLE_CONVERSION_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 double-conversion 源码，请下载 double-conversion 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译
if check_already_built "double-conversion" "$ARCH"; then
    log_info "double-conversion 已经编译安装"
    exit 0
fi

# 创建构建目录
BUILD_DIR=$(create_build_dir "double-conversion" "$ARCH")
cd "$BUILD_DIR" || exit 1

log_step "配置 double-conversion..."

# double-conversion 使用 CMake 构建
CMAKE_CMD="${OHOS_NDK}/native/build-tools/cmake/bin/cmake"
if [[ ! -f "$CMAKE_CMD" ]]; then
    CMAKE_CMD="cmake"
fi

# 获取工具链文件路径
TOOLCHAIN_FILE="${OHOS_TOOLCHAIN_FILE:-}"
if [[ -z "$TOOLCHAIN_FILE" ]] && command -v get_toolchain_file &> /dev/null; then
    TOOLCHAIN_FILE=$(get_toolchain_file "$OHOS_NDK")
fi
if [[ -z "$TOOLCHAIN_FILE" ]]; then
    # 默认路径
    TOOLCHAIN_FILE="${OHOS_NDK}/build/cmake/ohos.toolchain.cmake"
    if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
        TOOLCHAIN_FILE="${OHOS_NDK}/native/build/cmake/ohos.toolchain.cmake"
    fi
fi

# 配置 CMake（降低 CMake 版本要求，兼容 HarmonyOS SDK 自带的 CMake）
run_command \
    "\"$CMAKE_CMD\" \"$SOURCE_DIR\" \
        -DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE\" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DOHOS_ARCH=\"$ARCH\" \
        -DOHOS_STL=c++_static \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=\"$ARCH_INSTALL_DIR\" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF" \
    "${LOGS_DIR}/build/double_conversion_${ARCH}_configure.log" \
    "配置 double-conversion"

if [[ $? -ne 0 ]]; then
    log_error "double-conversion 配置失败"
    exit 1
fi

# 编译（使用 cmake --build 以支持不同的生成器）
log_step "编译 double-conversion..."
run_command \
    "\"$CMAKE_CMD\" --build . -j${PARALLEL_JOBS}" \
    "${LOGS_DIR}/build/double_conversion_${ARCH}_build.log" \
    "编译 double-conversion"

if [[ $? -ne 0 ]]; then
    log_error "double-conversion 编译失败"
    exit 1
fi

# 安装（使用 cmake --install）
log_step "安装 double-conversion..."
run_command \
    "\"$CMAKE_CMD\" --install ." \
    "${LOGS_DIR}/build/double_conversion_${ARCH}_install.log" \
    "安装 double-conversion"

if [[ $? -ne 0 ]]; then
    log_error "double-conversion 安装失败"
    exit 1
fi

# 编译后验证
if ! verify_build_result "double-conversion" "$ARCH" "libdouble-conversion.a" "double-conversion"; then
    log_error "double-conversion 编译验证失败"
    exit 1
fi

log_success "double-conversion 编译安装完成: $ARCH"
