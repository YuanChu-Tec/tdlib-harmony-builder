#!/bin/bash
# xxHash 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 xxHash for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "xxHash" "$XXHASH_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 xxHash 源码，请下载 xxHash 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译
if check_already_built "xxhash" "$ARCH"; then
    log_info "xxHash 已经编译安装"
    exit 0
fi

# 创建构建目录
BUILD_DIR=$(create_build_dir "xxhash" "$ARCH")
cd "$BUILD_DIR" || exit 1

log_step "配置 xxHash..."

# xxHash 可能使用 Makefile 或 CMake
cd "$SOURCE_DIR" || exit 1

# 检查是否有 CMakeLists.txt
if [[ -f "CMakeLists.txt" ]]; then
    # 使用 CMake 构建
    cd "$BUILD_DIR" || exit 1
    
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
    
    log_step "配置 xxHash (CMake)..."
    run_command \
        "\"$CMAKE_CMD\" \"$SOURCE_DIR\" \
            -DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE\" \
            -DOHOS_ARCH=\"$ARCH\" \
            -DOHOS_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=\"$ARCH_INSTALL_DIR\" \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_C_COMPILER=\"$CC\" \
            -DCMAKE_CXX_COMPILER=\"$CXX\" \
            -DCMAKE_C_FLAGS=\"$CFLAGS\" \
            -DCMAKE_CXX_FLAGS=\"$CXXFLAGS\"" \
        "${LOGS_DIR}/build/xxhash_${ARCH}_configure.log" \
        "配置 xxHash"
    
    log_step "编译 xxHash..."
    run_command \
        "\"$CMAKE_CMD\" --build . --config Release -j${PARALLEL_JOBS}" \
        "${LOGS_DIR}/build/xxhash_${ARCH}_build.log" \
        "编译 xxHash"
    
    log_step "安装 xxHash..."
    run_command \
        "\"$CMAKE_CMD\" --install . --config Release" \
        "${LOGS_DIR}/build/xxhash_${ARCH}_install.log" \
        "安装 xxHash"
else
    # 使用 Makefile 构建（禁用 x86 dispatch，因为这是 ARM 架构）
    log_step "编译 xxHash (Makefile)..."
    # 对于 ARM 架构，需要禁用 x86 dispatch
    # 修改 Makefile 或使用环境变量
    export XXHSUM_DISPATCH=0
    # 对于 ARM 架构，跳过编译 xxh_x86dispatch.c
    # 修改 Makefile 以排除该文件
    if [[ -f "Makefile" ]]; then
        # 备份原始 Makefile
        cp Makefile Makefile.bak 2>/dev/null || true
        # 移除 xxh_x86dispatch.o 的编译规则（如果存在）
        sed -i '/xxh_x86dispatch\.o/d' Makefile 2>/dev/null || true
        # 从 CLI_OBJS 中移除 xxh_x86dispatch.o（如果存在）
        sed -i 's/xxh_x86dispatch\.o//g' Makefile 2>/dev/null || true
        # 从所有变量中移除 xxh_x86dispatch.o
        sed -i 's/xxh_x86dispatch//g' Makefile 2>/dev/null || true
        # 注释掉 xxh_x86dispatch.c 的编译规则
        sed -i 's/^\(.*xxh_x86dispatch\.c.*\)$/# \1/' Makefile 2>/dev/null || true
    fi
    # 如果存在 cli/Makefile，也修改它
    if [[ -f "cli/Makefile" ]]; then
        cp cli/Makefile cli/Makefile.bak 2>/dev/null || true
        sed -i '/xxh_x86dispatch\.o/d' cli/Makefile 2>/dev/null || true
        sed -i 's/xxh_x86dispatch\.o//g' cli/Makefile 2>/dev/null || true
        sed -i 's/xxh_x86dispatch//g' cli/Makefile 2>/dev/null || true
        sed -i 's/^\(.*xxh_x86dispatch\.c.*\)$/# \1/' cli/Makefile 2>/dev/null || true
    fi
    # 直接编译库文件，跳过所有 CLI 相关目标
    # 先尝试只编译库文件，忽略 x86 dispatch 相关的错误
    # 如果 Makefile 中仍然有 xxh_x86dispatch.c 的引用，直接删除该文件
    if [[ -f "xxh_x86dispatch.c" ]]; then
        mv xxh_x86dispatch.c xxh_x86dispatch.c.bak 2>/dev/null || true
    fi
    if [[ -f "cli/xxh_x86dispatch.c" ]]; then
        mv cli/xxh_x86dispatch.c cli/xxh_x86dispatch.c.bak 2>/dev/null || true
    fi
    
    run_command \
        "make -j${PARALLEL_JOBS} \
            CC=\"$CC\" \
            CXX=\"$CXX\" \
            CFLAGS=\"$CFLAGS\" \
            CXXFLAGS=\"$CXXFLAGS\" \
            LDFLAGS=\"$LDFLAGS\" \
            XXHSUM_DISPATCH=0 \
            MOREFLAGS=\"-DXXHSUM_DISPATCH=0\" \
            libxxhash.a 2>&1 | grep -v 'xxh_x86dispatch' || true" \
        "${LOGS_DIR}/build/xxhash_${ARCH}_build.log" \
        "编译 xxHash"
    
    # 如果失败，尝试更简单的方法：直接编译单个文件
    if [[ $? -ne 0 ]] || [[ ! -f "libxxhash.a" ]]; then
        log_info "尝试直接编译库文件..."
        run_command \
            "\"$CC\" -c $CFLAGS xxhash.c -o xxhash.o && \"$AR\" rcs libxxhash.a xxhash.o" \
            "${LOGS_DIR}/build/xxhash_${ARCH}_build.log" \
            "编译 xxHash (直接方法)"
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "xxHash 编译失败"
        exit 1
    fi
    
    # 手动安装（如果make install不可用）
    log_step "安装 xxHash..."
    ensure_dir "${ARCH_INSTALL_DIR}/lib"
    ensure_dir "${ARCH_INSTALL_DIR}/include"
    
    # 查找生成的库文件
    if [[ -f "libxxhash.a" ]]; then
        cp "libxxhash.a" "${ARCH_INSTALL_DIR}/lib/"
    elif [[ -f "xxhash/libxxhash.a" ]]; then
        cp "xxhash/libxxhash.a" "${ARCH_INSTALL_DIR}/lib/"
    fi
    
    # 复制头文件
    if [[ -f "xxhash.h" ]]; then
        cp "xxhash.h" "${ARCH_INSTALL_DIR}/include/"
    elif [[ -d "xxhash" ]]; then
        cp xxhash/*.h "${ARCH_INSTALL_DIR}/include/" 2>/dev/null || true
    fi
    
    log_success "xxHash 安装完成"
fi

# 编译后验证
if ! verify_build_result "xxhash" "$ARCH" "libxxhash.a" "xxhash.h"; then
    log_error "xxHash 编译验证失败"
    exit 1
fi

log_success "xxHash 编译安装完成: $ARCH"
