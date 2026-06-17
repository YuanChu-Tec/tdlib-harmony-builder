#!/bin/bash
# RE2 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 RE2 for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "re2" "$RE2_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 RE2 源码，请下载 RE2 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

log_info "源码目录: $SOURCE_DIR"

# 检查是否已编译
if check_already_built "re2" "$ARCH"; then
    log_info "RE2 已经编译安装"
    exit 0
fi

# 创建构建目录
BUILD_DIR=$(create_build_dir "re2" "$ARCH")
cd "$BUILD_DIR" || exit 1

log_step "配置 RE2..."

# RE2 使用 Makefile 构建
cd "$SOURCE_DIR" || exit 1

# 检查是否有 CMakeLists.txt（新版本 RE2 使用 CMake）
if [[ -f "CMakeLists.txt" ]]; then
    # 使用 CMake 构建（禁用 Abseil 依赖）
    cd "$BUILD_DIR" || exit 1
    
    CMAKE_CMD="${OHOS_NDK}/native/build-tools/cmake/bin/cmake"
    if [[ ! -f "$CMAKE_CMD" ]]; then
        CMAKE_CMD="cmake"
    fi
    
    TOOLCHAIN_FILE="${OHOS_TOOLCHAIN_FILE:-}"
    if [[ -z "$TOOLCHAIN_FILE" ]] && command -v get_toolchain_file &> /dev/null; then
        TOOLCHAIN_FILE=$(get_toolchain_file "$OHOS_NDK")
    fi
    if [[ -z "$TOOLCHAIN_FILE" ]]; then
        TOOLCHAIN_FILE="${OHOS_NDK}/build/cmake/ohos.toolchain.cmake"
        if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
            TOOLCHAIN_FILE="${OHOS_NDK}/native/build/cmake/ohos.toolchain.cmake"
        fi
    fi
    
    log_step "配置 RE2 (CMake)..."
    # RE2 需要 Abseil，检查是否已编译 Abseil
    cd "$SOURCE_DIR" || exit 1
    
    # 检查 Abseil 是否已编译
    ABSL_LIB="${ARCH_INSTALL_DIR}/lib/libabsl_strings.a"
    ABSL_INCLUDE="${ARCH_INSTALL_DIR}/include"
    USE_ABSEIL_COMPAT=false
    
    if [[ -f "$ABSL_LIB" ]] && [[ -d "$ABSL_INCLUDE/absl" ]]; then
        log_info "检测到已编译的 Abseil 库，将使用完整 Abseil 库"
        USE_ABSEIL_COMPAT=false
    else
        log_warning "未找到已编译的 Abseil 库，将使用 Abseil 兼容层（可能不完整）"
        log_warning "建议先编译 Abseil: ./scripts/build/build_abseil.sh $ARCH"
        USE_ABSEIL_COMPAT=true
        
        # 创建 Abseil 兼容层目录（作为后备方案）
        ABSL_COMPAT_DIR="${ARCH_INSTALL_DIR}/include/absl"
        ensure_dir "$ABSL_COMPAT_DIR/base"
        ensure_dir "$ABSL_COMPAT_DIR/container"
        ensure_dir "$ABSL_COMPAT_DIR/strings"
        ensure_dir "$ABSL_COMPAT_DIR/synchronization"
        ensure_dir "$ABSL_COMPAT_DIR/types"
        ensure_dir "$ABSL_COMPAT_DIR/log"
        
        # 创建最小的 Abseil 头文件占位符
        cat > "$ABSL_COMPAT_DIR/base/attributes.h" << 'EOF'
#ifndef ABSL_BASE_ATTRIBUTES_H_
#define ABSL_BASE_ATTRIBUTES_H_
#define ABSL_ATTRIBUTE_NORETURN __attribute__((noreturn))
#define ABSL_MUST_USE_RESULT __attribute__((warn_unused_result))
#define ABSL_ATTRIBUTE_UNUSED __attribute__((unused))
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/base/macros.h" << 'EOF'
#ifndef ABSL_BASE_MACROS_H_
#define ABSL_BASE_MACROS_H_
#define ABSL_ARRAYSIZE(array) (sizeof(array) / sizeof(array[0]))
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/base/call_once.h" << 'EOF'
#ifndef ABSL_BASE_CALL_ONCE_H_
#define ABSL_BASE_CALL_ONCE_H_
#include <mutex>
namespace absl {
using std::call_once;
using std::once_flag;
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/base/thread_annotations.h" << 'EOF'
#ifndef ABSL_BASE_THREAD_ANNOTATIONS_H_
#define ABSL_BASE_THREAD_ANNOTATIONS_H_
#define ABSL_GUARDED_BY(x)
#define ABSL_EXCLUSIVE_LOCKS_REQUIRED(...)
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/strings/string_view.h" << 'EOF'
#ifndef ABSL_STRINGS_STRING_VIEW_H_
#define ABSL_STRINGS_STRING_VIEW_H_
#include <string_view>
namespace absl {
using string_view = std::string_view;
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/strings/str_format.h" << 'EOF'
#ifndef ABSL_STRINGS_STR_FORMAT_H_
#define ABSL_STRINGS_STR_FORMAT_H_
#include <string>
#include <sstream>
namespace absl {
template<typename... Args>
std::string StrFormat(const char* format, Args... args) {
    std::ostringstream oss;
    oss << format;  // 简化实现
    return oss.str();
}
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/container/flat_hash_map.h" << 'EOF'
#ifndef ABSL_CONTAINER_FLAT_HASH_MAP_H_
#define ABSL_CONTAINER_FLAT_HASH_MAP_H_
#include <unordered_map>
namespace absl {
template<typename K, typename V>
using flat_hash_map = std::unordered_map<K, V>;
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/container/flat_hash_set.h" << 'EOF'
#ifndef ABSL_CONTAINER_FLAT_HASH_SET_H_
#define ABSL_CONTAINER_FLAT_HASH_SET_H_
#include <unordered_set>
namespace absl {
template<typename K>
using flat_hash_set = std::unordered_set<K>;
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/container/fixed_array.h" << 'EOF'
#ifndef ABSL_CONTAINER_FIXED_ARRAY_H_
#define ABSL_CONTAINER_FIXED_ARRAY_H_
#include <array>
namespace absl {
template<typename T, size_t N>
using FixedArray = std::array<T, N>;
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/container/inlined_vector.h" << 'EOF'
#ifndef ABSL_CONTAINER_INLINED_VECTOR_H_
#define ABSL_CONTAINER_INLINED_VECTOR_H_
#include <vector>
namespace absl {
template<typename T, size_t N>
using InlinedVector = std::vector<T>;
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/types/optional.h" << 'EOF'
#ifndef ABSL_TYPES_OPTIONAL_H_
#define ABSL_TYPES_OPTIONAL_H_
#include <optional>
namespace absl {
template<typename T>
using optional = std::optional<T>;
constexpr auto nullopt = std::nullopt;
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/types/span.h" << 'EOF'
#ifndef ABSL_TYPES_SPAN_H_
#define ABSL_TYPES_SPAN_H_
#include <span>
namespace absl {
template<typename T>
using Span = std::span<T>;
}  // namespace absl
#endif
EOF
        
        cat > "$ABSL_COMPAT_DIR/synchronization/mutex.h" << 'EOF'
#ifndef ABSL_SYNCHRONIZATION_MUTEX_H_
#define ABSL_SYNCHRONIZATION_MUTEX_H_
#include <mutex>
namespace absl {
using mutex = std::mutex;
using Mutex = std::mutex;
}  // namespace absl
#endif
EOF
    
    cat > "$ABSL_COMPAT_DIR/log/absl_check.h" << 'EOF'
#ifndef ABSL_LOG_ABSL_CHECK_H_
#define ABSL_LOG_ABSL_CHECK_H_
#include <cassert>
#define CHECK(x) assert(x)
#define CHECK_EQ(x, y) assert((x) == (y))
#define CHECK_NE(x, y) assert((x) != (y))
#define CHECK_LT(x, y) assert((x) < (y))
#define CHECK_LE(x, y) assert((x) <= (y))
#define CHECK_GT(x, y) assert((x) > (y))
#define CHECK_GE(x, y) assert((x) >= (y))
#endif
EOF
        
        log_info "已创建 Abseil 兼容层"
        # 备份 CMakeLists.txt
        cp CMakeLists.txt CMakeLists.txt.bak 2>/dev/null || true
        # 修改 CMakeLists.txt 以跳过 Abseil 查找
        # 注释掉 find_package(absl REQUIRED) 行（如果还没有注释）
        if grep -q "^[[:space:]]*find_package(absl REQUIRED)" CMakeLists.txt 2>/dev/null; then
            sed -i 's/^\([[:space:]]*find_package(absl REQUIRED)\)/# \1/' CMakeLists.txt 2>/dev/null || \
            sed -i.bak 's/^\([[:space:]]*find_package(absl REQUIRED)\)/# \1/' CMakeLists.txt 2>/dev/null || true
        fi
        # 确保 ABSL_DEPS 被设置为空列表（替换原有的 ABSL_DEPS 定义）
        # 查找 ABSL_DEPS 的定义位置（第72-88行之间）
        if grep -q "^set(ABSL_DEPS" CMakeLists.txt 2>/dev/null; then
            # 如果已经有 set(ABSL_DEPS，替换为空列表
            sed -i 's/^set(ABSL_DEPS.*)/set(ABSL_DEPS "")/' CMakeLists.txt 2>/dev/null || \
            sed -i.bak 's/^set(ABSL_DEPS.*)/set(ABSL_DEPS "")/' CMakeLists.txt 2>/dev/null || true
        else
            # 如果没有，在 find_package 之后添加
            sed -i '/#.*find_package(absl REQUIRED)/a set(ABSL_DEPS "")' CMakeLists.txt 2>/dev/null || \
            sed -i.bak '/#.*find_package(absl REQUIRED)/a set(ABSL_DEPS "")' CMakeLists.txt 2>/dev/null || true
        fi
        # 注释掉 list(APPEND REQUIRES ${ABSL_DEPS}) 行（如果还没有注释）
        if grep -q "^[[:space:]]*list(APPEND REQUIRES \${ABSL_DEPS})" CMakeLists.txt 2>/dev/null; then
            sed -i 's/^\([[:space:]]*list(APPEND REQUIRES ${ABSL_DEPS})\)/# \1/' CMakeLists.txt 2>/dev/null || \
            sed -i.bak 's/^\([[:space:]]*list(APPEND REQUIRES ${ABSL_DEPS})\)/# \1/' CMakeLists.txt 2>/dev/null || true
        fi
        # 注释掉 foreach 循环中的 absl:: 引用（第167-172行）
        # 由于 ABSL_DEPS 已经是空列表，foreach 循环不会执行，但为了安全起见，我们还是注释掉它
        if grep -q "^foreach(dep \${ABSL_DEPS})" CMakeLists.txt 2>/dev/null && ! grep -q "^#.*foreach(dep \${ABSL_DEPS})" CMakeLists.txt 2>/dev/null; then
            # 注释掉整个 foreach 循环块（使用更精确的匹配）
            sed -i '/^foreach(dep ${ABSL_DEPS})/,/^endforeach()/{
                s/^/# /
            }' CMakeLists.txt 2>/dev/null || \
            sed -i.bak '/^foreach(dep ${ABSL_DEPS})/,/^endforeach()/{
                s/^/# /
            }' CMakeLists.txt 2>/dev/null || true
        fi
    fi
    
    cd "$BUILD_DIR" || exit 1
    # 清理 CMake 缓存，确保修改生效
    clean_cmake_cache "$BUILD_DIR"
    
    # 备份现有的 Abseil 头文件目录（如果存在且不是我们刚创建的兼容层）
    ABSL_INCLUDE_BACKUP="${ARCH_INSTALL_DIR}/include/absl.backup"
    if [[ -d "${ARCH_INSTALL_DIR}/include/absl" ]] && [[ ! -f "${ARCH_INSTALL_DIR}/include/absl/base/attributes.h" ]]; then
        log_info "备份现有的 Abseil 头文件目录"
        mv "${ARCH_INSTALL_DIR}/include/absl" "$ABSL_INCLUDE_BACKUP" 2>/dev/null || true
    fi
    
    # 转换路径格式（Windows 格式用于编译器）
    ARCH_INSTALL_DIR_WIN=$(echo "$ARCH_INSTALL_DIR" | sed 's|\\|/|g')
    ARCH_INSTALL_DIR_UNIX=$(echo "$ARCH_INSTALL_DIR" | sed 's|C:|/c|;s|\\|/|g')
    
    # 配置 CMake 参数
    CMAKE_ARGS=(
        "\"$CMAKE_CMD\" \"$SOURCE_DIR\""
        "-DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE\""
        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
        "-DOHOS_ARCH=\"$ARCH\""
        "-DOHOS_STL=c++_static"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_INSTALL_PREFIX=\"$ARCH_INSTALL_DIR_UNIX\""
        "-DBUILD_SHARED_LIBS=OFF"
        "-DRE2_BUILD_TESTING=OFF"
        "-DRE2_USE_ICU=0"
        "-DCMAKE_CXX_STANDARD=17"
    )
    
    if [[ "$USE_ABSEIL_COMPAT" == false ]]; then
        # 使用编译好的 Abseil 库
        log_info "使用已编译的 Abseil 库"
        CMAKE_ARGS+=(
            "-Dabsl_DIR=\"$ARCH_INSTALL_DIR_UNIX/lib/cmake/absl\""
            "-DCMAKE_PREFIX_PATH=\"$ARCH_INSTALL_DIR_UNIX\""
            "-DCMAKE_INCLUDE_PATH=\"$ARCH_INSTALL_DIR_UNIX/include\""
        )
    else
        # 使用 Abseil 兼容层
        log_info "使用 Abseil 兼容层"
        
        # 确保 Abseil 兼容层头文件存在
        if [[ ! -f "${ARCH_INSTALL_DIR}/include/absl/base/macros.h" ]]; then
            log_error "Abseil 兼容层头文件缺失: ${ARCH_INSTALL_DIR}/include/absl/base/macros.h"
            log_error "请先编译 Abseil: ./scripts/build/build_abseil.sh $ARCH"
            exit 1
        fi
        
        CMAKE_ARGS+=(
            "-DCMAKE_DISABLE_FIND_PACKAGE_absl=TRUE"
            "-DCMAKE_CXX_FLAGS=\"-DRE2_USE_ICU=0 -DABSL_ATTRIBUTE_NORETURN=__attribute__((noreturn)) -I$ARCH_INSTALL_DIR_WIN/include -I$ARCH_INSTALL_DIR_UNIX/include\""
            "-DCMAKE_INCLUDE_PATH=\"$ARCH_INSTALL_DIR_UNIX/include\""
            "-DCMAKE_PREFIX_PATH=\"$ARCH_INSTALL_DIR_UNIX\""
        )
    fi
    
    run_command \
        "${CMAKE_ARGS[*]}" \
        "${LOGS_DIR}/build/re2_${ARCH}_configure.log" \
        "配置 RE2"
    
    if [[ $? -ne 0 ]]; then
        log_error "RE2 配置失败"
        exit 1
    fi
    
    log_step "编译 RE2..."
    run_command \
        "\"$CMAKE_CMD\" --build . -j${PARALLEL_JOBS}" \
        "${LOGS_DIR}/build/re2_${ARCH}_build.log" \
        "编译 RE2"
    
    if [[ $? -ne 0 ]]; then
        log_error "RE2 编译失败"
        exit 1
    fi
    
    log_step "安装 RE2..."
    run_command \
        "\"$CMAKE_CMD\" --install ." \
        "${LOGS_DIR}/build/re2_${ARCH}_install.log" \
        "安装 RE2"
    
    # 恢复 Abseil 头文件目录（如果之前备份了）
    if [[ -d "$ABSL_INCLUDE_BACKUP" ]]; then
        log_info "恢复 Abseil 头文件目录"
        rm -rf "${ARCH_INSTALL_DIR}/include/absl" 2>/dev/null || true
        mv "$ABSL_INCLUDE_BACKUP" "${ARCH_INSTALL_DIR}/include/absl" 2>/dev/null || true
    fi
else
    # 使用 Makefile 构建（禁用 absl 依赖，使用内置实现，使用 C++17）
    log_step "编译 RE2 (Makefile)..."
    run_command \
        "make -j${PARALLEL_JOBS} \
            CXX=\"$CXX\" \
            CXXFLAGS=\"$CXXFLAGS -std=c++17 -DRE2_USE_ICU=0\" \
            LDFLAGS=\"$LDFLAGS\" \
            RE2_BUILD_TESTING=OFF" \
        "${LOGS_DIR}/build/re2_${ARCH}_build.log" \
        "编译 RE2"

    if [[ $? -ne 0 ]]; then
        log_error "RE2 编译失败"
        exit 1
    fi

    # 安装
    log_step "安装 RE2..."
    ensure_dir "${ARCH_INSTALL_DIR}/lib"
    ensure_dir "${ARCH_INSTALL_DIR}/include/re2"

    # 查找生成的库文件
    if [[ -f "obj/libre2.a" ]]; then
        cp "obj/libre2.a" "${ARCH_INSTALL_DIR}/lib/"
    elif [[ -f "libre2.a" ]]; then
        cp "libre2.a" "${ARCH_INSTALL_DIR}/lib/"
    fi

    # 复制头文件
    if [[ -d "re2" ]]; then
        cp re2/*.h "${ARCH_INSTALL_DIR}/include/re2/" 2>/dev/null || true
    fi

    log_success "RE2 安装完成"

    # 编译后验证
    if ! verify_build_result "re2" "$ARCH" "libre2.a" "re2"; then
        log_error "re2 编译验证失败"
        exit 1
    fi

    log_success "RE2 编译安装完成: $ARCH"
fi
