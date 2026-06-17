#!/bin/bash
# libevent 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 libevent for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "libevent" "$LIBEVENT_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 libevent 源码，请下载 libevent 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译
if check_already_built "libevent" "$ARCH"; then
    log_info "libevent 已经编译安装"
    exit 0
fi

# 创建构建目录
BUILD_DIR=$(create_build_dir "libevent" "$ARCH")
cd "$BUILD_DIR" || exit 1

log_step "配置 libevent..."

# libevent 使用 CMake 构建
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

# 配置 CMake（添加 CMake 策略版本以兼容旧版本）
# 注意：需要在 CMakeLists.txt 之前设置策略版本
# 使用 -DCMAKE_POLICY_DEFAULT_CMP<number>=NEW 来设置策略
run_command \
    "\"$CMAKE_CMD\" \"$SOURCE_DIR\" \
        -DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE\" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_POLICY_DEFAULT_CMP0054=NEW \
        -DCMAKE_POLICY_DEFAULT_CMP0074=NEW \
        -DCMAKE_POLICY_DEFAULT_CMP0075=NEW \
        -DOHOS_ARCH=\"$ARCH\" \
        -DOHOS_STL=c++_static \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=\"$ARCH_INSTALL_DIR\" \
        -DBUILD_SHARED_LIBS=OFF \
        -DEVENT__DISABLE_OPENSSL=ON \
        -DEVENT__DISABLE_TESTS=ON \
        -DEVENT__DISABLE_SAMPLES=ON \
        -DEVENT__LIBRARY_TYPE=STATIC" \
    "${LOGS_DIR}/build/libevent_${ARCH}_configure.log" \
    "配置 libevent"

if [[ $? -ne 0 ]]; then
    log_error "libevent 配置失败"
    exit 1
fi

# 编译（使用 cmake --build）
log_step "编译 libevent..."
run_command \
    "\"$CMAKE_CMD\" --build . --config Release -j${PARALLEL_JOBS}" \
    "${LOGS_DIR}/build/libevent_${ARCH}_build.log" \
    "编译 libevent"

if [[ $? -ne 0 ]]; then
    log_error "libevent 编译失败"
    exit 1
fi

# 安装（使用 cmake --install）
log_step "安装 libevent..."
run_command \
    "\"$CMAKE_CMD\" --install . --config Release" \
    "${LOGS_DIR}/build/libevent_${ARCH}_install.log" \
    "安装 libevent"

if [[ $? -ne 0 ]]; then
    log_error "libevent 安装失败"
    exit 1
fi

# 编译后验证（libevent 可能生成 .a 或 .so）
# 注意：即使设置了 BUILD_SHARED_LIBS=OFF，某些情况下仍可能生成 .so
# 检查实际安装的库文件
LIBEVENT_LIBS=""
LIBEVENT_FOUND=false

# 优先查找静态库
if [[ -f "${ARCH_INSTALL_DIR}/lib/libevent.a" ]]; then
    LIBEVENT_LIBS="libevent.a"
    LIBEVENT_FOUND=true
    log_info "找到 libevent 静态库: libevent.a"
elif [[ -f "${ARCH_INSTALL_DIR}/usr/lib/libevent.a" ]]; then
    LIBEVENT_LIBS="libevent.a"
    LIBEVENT_FOUND=true
    log_info "找到 libevent 静态库: libevent.a (在 usr/lib)"
fi

# 如果没有静态库，查找动态库
if [[ "$LIBEVENT_FOUND" == false ]]; then
    if [[ -f "${ARCH_INSTALL_DIR}/lib/libevent.so" ]]; then
        LIBEVENT_LIBS="libevent.so"
        LIBEVENT_FOUND=true
        log_info "找到 libevent 动态库: libevent.so"
    elif [[ -f "${ARCH_INSTALL_DIR}/lib/libevent-2.1.so" ]]; then
        LIBEVENT_LIBS="libevent-2.1.so"
        LIBEVENT_FOUND=true
        log_info "找到 libevent 动态库: libevent-2.1.so"
    elif [[ -f "${ARCH_INSTALL_DIR}/usr/lib/libevent.so" ]]; then
        LIBEVENT_LIBS="libevent.so"
        LIBEVENT_FOUND=true
        log_info "找到 libevent 动态库: libevent.so (在 usr/lib)"
    fi
fi

if [[ "$LIBEVENT_FOUND" == false ]]; then
    log_error "未找到 libevent 库文件"
    log_info "检查目录: ${ARCH_INSTALL_DIR}/lib"
    ls -la "${ARCH_INSTALL_DIR}/lib/libevent"* 2>/dev/null || true
    exit 1
fi

# 验证库文件（对于动态库，在 Windows 环境下会使用改进的验证逻辑）
if ! verify_build_result "libevent" "$ARCH" "$LIBEVENT_LIBS" "event2"; then
    log_error "libevent 编译验证失败"
    log_info "提示：如果这是动态库验证问题，在 Windows 环境下这是正常的"
    exit 1
fi

log_success "libevent 编译安装完成: $ARCH"
