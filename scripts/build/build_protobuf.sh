#!/bin/bash
# Protocol Buffers 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 Protocol Buffers for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "protobuf" "$PROTOBUF_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 Protocol Buffers 源码，请下载 protobuf 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译（但主机 protoc 可能还未构建）
PROTOBUF_BUILT=false
if check_already_built "protobuf" "$ARCH"; then
    PROTOBUF_BUILT=true
    log_info "Protocol Buffers 已经编译安装"
fi

# 检查主机 protoc 是否存在
HOST_PROTOC_BUILD_DIR="${ARCH_BUILD_DIR}/protobuf-host"
HOST_PROTOC_EXISTS=false
if [[ -f "$HOST_PROTOC_BUILD_DIR/src/protoc" ]] || \
   [[ -f "$HOST_PROTOC_BUILD_DIR/src/protoc.exe" ]] || \
   [[ -f "$HOST_PROTOC_BUILD_DIR/protoc" ]] || \
   [[ -f "$HOST_PROTOC_BUILD_DIR/protoc.exe" ]] || \
   [[ -f "$HOST_PROTOC_BUILD_DIR/install/bin/protoc" ]] || \
   [[ -f "$HOST_PROTOC_BUILD_DIR/install/bin/protoc.exe" ]]; then
    HOST_PROTOC_EXISTS=true
fi

# 如果 protobuf 已编译且主机 protoc 也存在，则退出
if [[ "$PROTOBUF_BUILT" == "true" ]] && [[ "$HOST_PROTOC_EXISTS" == "true" ]]; then
    log_info "Protocol Buffers 和主机 protoc 都已就绪"
    exit 0
fi

# 先构建主机版本的 protoc（用于生成 protobuf 文件）
log_step "构建主机版本的 protoc..."
HOST_PROTOC_BUILD_DIR="${ARCH_BUILD_DIR}/protobuf-host"
mkdir -p "$HOST_PROTOC_BUILD_DIR"
cd "$HOST_PROTOC_BUILD_DIR" || exit 1

# 获取 CMake 命令（用于主机构建）
HOST_CMAKE_CMD="cmake"
if [[ -f "${OHOS_NDK}/native/build-tools/cmake/bin/cmake" ]]; then
    HOST_CMAKE_CMD="${OHOS_NDK}/native/build-tools/cmake/bin/cmake"
fi

# 保存交叉编译环境变量
SAVE_CC="$CC"
SAVE_CXX="$CXX"
SAVE_CFLAGS="$CFLAGS"
SAVE_CXXFLAGS="$CXXFLAGS"
SAVE_LDFLAGS="$LDFLAGS"
SAVE_AR="$AR"
SAVE_RANLIB="$RANLIB"

# 清空交叉编译变量，使用主机编译器
unset CC CXX CFLAGS CXXFLAGS LDFLAGS AR RANLIB

# 配置主机版本（不使用工具链文件）
if [[ ! -f "$HOST_PROTOC_BUILD_DIR/Makefile" ]] && [[ ! -f "$HOST_PROTOC_BUILD_DIR/build.ninja" ]]; then
    # 尝试使用 configure（如果存在）
    if [[ -f "$SOURCE_DIR/configure" ]]; then
        run_command \
            "\"$SOURCE_DIR/configure\" \
                --disable-shared \
                --enable-static \
                --prefix=\"$HOST_PROTOC_BUILD_DIR/install\"" \
            "${LOGS_DIR}/build/protobuf_${ARCH}_host_configure.log" \
            "配置主机 protoc" || {
            # 如果 configure 失败，尝试使用 CMake
            log_info "configure 失败，尝试使用 CMake 构建主机 protoc..."
            rm -rf "$HOST_PROTOC_BUILD_DIR"/*
        }
    fi
    
    # 如果 configure 不存在或失败，使用 CMake
    if [[ ! -f "$HOST_PROTOC_BUILD_DIR/Makefile" ]] && [[ ! -f "$HOST_PROTOC_BUILD_DIR/build.ninja" ]]; then
        run_command \
            "\"$HOST_CMAKE_CMD\" \"$SOURCE_DIR\" \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_INSTALL_PREFIX=\"$HOST_PROTOC_BUILD_DIR/install\" \
                -DBUILD_SHARED_LIBS=OFF \
                -Dprotobuf_BUILD_TESTS=OFF \
                -Dprotobuf_BUILD_EXAMPLES=OFF \
                -Dprotobuf_BUILD_PROTOC_BINARIES=ON" \
            "${LOGS_DIR}/build/protobuf_${ARCH}_host_configure.log" \
            "配置主机 protoc (CMake)"
    fi
fi

# 编译主机 protoc
if [[ -f "$HOST_PROTOC_BUILD_DIR/Makefile" ]]; then
    run_command \
        "make -j${PARALLEL_JOBS} protoc" \
        "${LOGS_DIR}/build/protobuf_${ARCH}_host_build.log" \
        "编译主机 protoc"
    # 查找编译后的 protoc（包括符号链接）
    # 先检查直接路径
    if [[ -x "$HOST_PROTOC_BUILD_DIR/protoc" ]]; then
        HOST_PROTOC="$HOST_PROTOC_BUILD_DIR/protoc"
    elif [[ -x "$HOST_PROTOC_BUILD_DIR/src/protoc" ]]; then
        HOST_PROTOC="$HOST_PROTOC_BUILD_DIR/src/protoc"
    elif [[ -x "$HOST_PROTOC_BUILD_DIR/install/bin/protoc" ]]; then
        HOST_PROTOC="$HOST_PROTOC_BUILD_DIR/install/bin/protoc"
    else
        # 最后尝试 find
        HOST_PROTOC=$(find "$HOST_PROTOC_BUILD_DIR" -name protoc \( -type f -o -type l \) 2>/dev/null | head -1)
    fi
elif [[ -f "$HOST_PROTOC_BUILD_DIR/build.ninja" ]] || [[ -f "$HOST_PROTOC_BUILD_DIR/Makefile" ]]; then
    run_command \
        "\"$HOST_CMAKE_CMD\" --build . --target protoc -j${PARALLEL_JOBS}" \
        "${LOGS_DIR}/build/protobuf_${ARCH}_host_build.log" \
        "编译主机 protoc"
    # 查找编译后的 protoc（包括符号链接）
    if [[ -x "$HOST_PROTOC_BUILD_DIR/protoc" ]]; then
        HOST_PROTOC="$HOST_PROTOC_BUILD_DIR/protoc"
    elif [[ -x "$HOST_PROTOC_BUILD_DIR/src/protoc" ]]; then
        HOST_PROTOC="$HOST_PROTOC_BUILD_DIR/src/protoc"
    elif [[ -x "$HOST_PROTOC_BUILD_DIR/install/bin/protoc" ]]; then
        HOST_PROTOC="$HOST_PROTOC_BUILD_DIR/install/bin/protoc"
    else
        HOST_PROTOC=$(find "$HOST_PROTOC_BUILD_DIR" -name protoc \( -type f -o -type l \) 2>/dev/null | head -1)
    fi
else
    log_warning "无法构建主机 protoc，将尝试使用系统 protoc"
    HOST_PROTOC="protoc"
fi

# 恢复交叉编译环境变量
export CC="$SAVE_CC"
export CXX="$SAVE_CXX"
export CFLAGS="$SAVE_CFLAGS"
export CXXFLAGS="$SAVE_CXXFLAGS"
export LDFLAGS="$SAVE_LDFLAGS"
export AR="$SAVE_AR"
export RANLIB="$SAVE_RANLIB"

# 验证主机 protoc 是否存在
# 使用 -e 而不是 -f，因为 find 可能返回符号链接
if [[ -z "$HOST_PROTOC" ]] || [[ ! -e "$HOST_PROTOC" ]]; then
    log_warning "主机 protoc 未找到，将尝试使用系统 protoc（如果可用）"
    HOST_PROTOC="protoc"
fi

log_info "主机 protoc 路径: $HOST_PROTOC"

# 创建构建目录
BUILD_DIR=$(create_build_dir "protobuf" "$ARCH")
cd "$BUILD_DIR" || exit 1

log_step "配置 Protocol Buffers..."

# Protocol Buffers 使用 CMake 构建
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

# 配置 CMake
# 注意：Protobuf 33.4+ 依赖 Abseil，需要确保 Abseil 被正确构建和安装
# 添加 -D_POSIX_C_SOURCE 以启用 POSIX 函数（如 close）
# 
# 注意：不要主动覆盖优化级别，由 CMake Release 模式自动使用 -O3
# 之前尝试 -O0/-O1/-Og 反而触发 clang 15.0.4 解析器崩溃
# 不要添加 -fno-exceptions 或 -fno-rtti，protobuf 35.x 依赖异常和 RTTI
PROTOBUF_C_FLAGS="$CFLAGS -D_POSIX_C_SOURCE=200809L -DOHOS"
PROTOBUF_CXX_FLAGS="$CXXFLAGS -D_POSIX_C_SOURCE=200809L -DOHOS -std=c++17 -Wno-unused-command-line-argument"

# 自动检测 Abseil 安装路径（直接传递 -Dabsl_DIR，避免中间变量引号被 eval 吞掉）
ABSL_CMAKE_DIR=""
if [[ -d "$ARCH_INSTALL_DIR/lib/cmake/absl" ]]; then
    ABSL_CMAKE_DIR="$ARCH_INSTALL_DIR/lib/cmake/absl"
elif [[ -d "$ARCH_INSTALL_DIR/share/cmake/absl" ]]; then
    ABSL_CMAKE_DIR="$ARCH_INSTALL_DIR/share/cmake/absl"
fi
if [[ -n "$ABSL_CMAKE_DIR" ]]; then
    log_info "检测到 Abseil: $ABSL_CMAKE_DIR"
else
    log_warning "未检测到 Abseil 安装，protobuf 35.x 需要 Abseil 依赖"
    log_warning "请先编译安装 Abseil"
fi

# 注意：protobuf 35.x 已不识别 protobuf_ABSL_PROVIDER，
# 直接通过 -Dabsl_DIR 指定路径即可
run_command \
    "\"$CMAKE_CMD\" \"$SOURCE_DIR\" \
        -G \"Ninja\" \
        -DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE\" \
        -DOHOS_ARCH=\"$ARCH\" \
        -DOHOS_STL=c++_static \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=\"$ARCH_INSTALL_DIR\" \
        -DBUILD_SHARED_LIBS=OFF \
        -Dprotobuf_BUILD_TESTS=OFF \
        -Dprotobuf_BUILD_EXAMPLES=OFF \
        -Dprotobuf_INSTALL=ON \
        -Dabsl_DIR=\"${ABSL_CMAKE_DIR}\" \
        -DZLIB_ROOT=\"$ARCH_INSTALL_DIR\" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_C_COMPILER=\"$CC\" \
        -DCMAKE_CXX_COMPILER=\"$CXX\" \
        -DCMAKE_C_FLAGS=\"$PROTOBUF_C_FLAGS\" \
        -DCMAKE_CXX_FLAGS=\"$PROTOBUF_CXX_FLAGS\" \
        -DCMAKE_EXE_LINKER_FLAGS=\"$LDFLAGS\"" \
    "${LOGS_DIR}/build/protobuf_${ARCH}_configure.log" \
    "配置 Protocol Buffers"

if [[ $? -ne 0 ]]; then
    log_error "Protocol Buffers 配置失败"
    exit 1
fi

# 修复 HarmonyOS 兼容性问题：posix_close 函数不存在
# HarmonyOS 基于 musl libc，不支持 posix_close
# 将 posix_close(fd, 0) 统一替换为 close(fd)
log_step "修复 HarmonyOS 兼容性问题..."
POSIX_CLOSE_FILES=$(grep -rl "posix_close" "$SOURCE_DIR/src" 2>/dev/null || true)
if [[ -n "$POSIX_CLOSE_FILES" ]]; then
    log_info "发现以下文件包含 posix_close 调用:"
    echo "$POSIX_CLOSE_FILES" | head -10
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            log_info "修复: $file"
            sed -i 's/posix_close([^)]*)/close(fd)/g' "$file"
        fi
    done <<< "$POSIX_CLOSE_FILES"
    log_success "HarmonyOS 兼容性修复完成"
else
    log_info "未找到 posix_close 调用，跳过修复"
fi

# 编译（使用 cmake --build 以支持不同的生成器）
log_step "编译 Protocol Buffers..."
run_command \
    "\"$CMAKE_CMD\" --build . --config Release -j${PARALLEL_JOBS}" \
    "${LOGS_DIR}/build/protobuf_${ARCH}_build.log" \
    "编译 Protocol Buffers"

if [[ $? -ne 0 ]]; then
    log_error "Protocol Buffers 编译失败"
    exit 1
fi

# 安装（使用 cmake --install）
# 注意：需要安装所有组件，包括头文件
log_step "安装 Protocol Buffers..."
run_command \
    "\"$CMAKE_CMD\" --install . --config Release --component protobuf-headers" \
    "${LOGS_DIR}/build/protobuf_${ARCH}_install.log" \
    "安装 Protocol Buffers 头文件" || true

run_command \
    "\"$CMAKE_CMD\" --install . --config Release" \
    "${LOGS_DIR}/build/protobuf_${ARCH}_install.log" \
    "安装 Protocol Buffers"

if [[ $? -ne 0 ]]; then
    log_error "Protocol Buffers 安装失败"
    exit 1
fi

# 编译后验证
if ! verify_build_result "protobuf" "$ARCH" "libprotobuf.a" "google/protobuf"; then
    log_error "Protocol Buffers 编译验证失败"
    exit 1
fi

log_success "Protocol Buffers 编译安装完成: $ARCH"
