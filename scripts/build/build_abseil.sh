#!/bin/bash
# Abseil 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 Abseil for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "abseil" "$ABSEIL_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 Abseil 源码，请下载 Abseil 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译
if check_already_built "abseil" "$ARCH"; then
    log_info "Abseil 已经编译安装"
    exit 0
fi

# 创建构建目录
BUILD_DIR=$(create_build_dir "abseil" "$ARCH")
cd "$BUILD_DIR" || exit 1

# 若项目路径变更（如移动目录），CMake 缓存中的路径会失效，配置前清理缓存
clean_cmake_cache "$BUILD_DIR"

log_step "配置 Abseil..."

# Abseil 使用 CMake 构建
CMAKE_CMD="${OHOS_NDK}/native/build-tools/cmake/bin/cmake"
if [[ ! -f "$CMAKE_CMD" ]]; then
    CMAKE_CMD="cmake"
fi

# 获取工具链文件路径
TOOLCHAIN_FILE="${OHOS_TOOLCHAIN_FILE:-}"
if [[ -z "$TOOLCHAIN_FILE" ]] && command -v get_toolchain_file &> /dev/null; then
    TOOLCHAIN_FILE=$(get_toolchain_file "$OHOS_NDK")
fi
if [[ -z "$TOOLCHAIN_FILE" ]] || [[ ! -f "$TOOLCHAIN_FILE" ]]; then
    # 默认路径
    ndk_path=$(echo "$OHOS_NDK" | sed 's|\\|/|g')
    if [[ "$ndk_path" == *"/native" ]] || [[ "$ndk_path" == *"/native/" ]]; then
        TOOLCHAIN_FILE="${ndk_path}/build/cmake/ohos.toolchain.cmake"
    else
        TOOLCHAIN_FILE="${ndk_path}/build/cmake/ohos.toolchain.cmake"
        if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
            TOOLCHAIN_FILE="${ndk_path}/native/build/cmake/ohos.toolchain.cmake"
        fi
    fi
fi

# 验证工具链文件是否存在
if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
    log_error "未找到工具链文件: $TOOLCHAIN_FILE"
    log_error "OHOS_NDK: $OHOS_NDK"
    exit 1
fi

# 转换路径格式
TOOLCHAIN_FILE_UNIX=$(echo "$TOOLCHAIN_FILE" | sed 's|C:|/c|;s|\\|/|g')
ARCH_INSTALL_DIR_UNIX=$(echo "$ARCH_INSTALL_DIR" | sed 's|C:|/c|;s|\\|/|g')

# 配置 Abseil
# 注意：使用工具链文件时，不需要手动设置 CMAKE_C_COMPILER 和 CMAKE_CXX_COMPILER
# 工具链文件会自动设置这些变量，手动设置可能导致路径格式冲突
run_command \
    "\"$CMAKE_CMD\" \"$SOURCE_DIR\" \
        -G \"Ninja\" \
        -DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE_UNIX\" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DOHOS_ARCH=\"$ARCH\" \
        -DOHOS_STL=c++_static \
        -DOHOS_PLATFORM=OHOS \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=\"$ARCH_INSTALL_DIR_UNIX\" \
        -DBUILD_SHARED_LIBS=OFF \
        -DABSL_BUILD_TESTING=OFF \
        -DABSL_PROPAGATE_CXX_STD=ON \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_C_FLAGS=\"$CFLAGS -Wno-unused-command-line-argument\" \
        -DCMAKE_CXX_FLAGS=\"$CXXFLAGS -Wno-unused-command-line-argument -Wno-deprecated-builtins\" \
        -DCMAKE_EXE_LINKER_FLAGS=\"$LDFLAGS\"" \
    "${LOGS_DIR}/build/abseil_${ARCH}_configure.log" \
    "配置 Abseil"

if [[ $? -ne 0 ]]; then
    log_error "Abseil 配置失败"
    exit 1
fi

# 编译
log_step "编译 Abseil..."
run_command \
    "\"$CMAKE_CMD\" --build . --config Release -j${PARALLEL_JOBS}" \
    "${LOGS_DIR}/build/abseil_${ARCH}_build.log" \
    "编译 Abseil"

if [[ $? -ne 0 ]]; then
    log_error "Abseil 编译失败"
    exit 1
fi

# 安装
log_step "安装 Abseil..."
run_command \
    "\"$CMAKE_CMD\" --install . --config Release" \
    "${LOGS_DIR}/build/abseil_${ARCH}_install.log" \
    "安装 Abseil"

if [[ $? -ne 0 ]]; then
    log_error "Abseil 安装失败"
    exit 1
fi

# 编译后验证（Abseil 有多个库文件，至少检查一个）
if ! verify_build_result "abseil" "$ARCH" "libabsl_strings.a" "absl"; then
    log_error "Abseil 编译验证失败"
    exit 1
fi

log_success "Abseil 编译安装完成: $ARCH"
