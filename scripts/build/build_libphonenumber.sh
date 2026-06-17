#!/bin/bash
# libphonenumber 编译脚本 for HarmonyOS

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BUILD_SCRIPT_DIR/.." && pwd)/common.sh"

ARCH=$1
if [[ -z "$ARCH" ]]; then
    log_error "请指定架构"
    exit 1
fi

log_step "开始编译 libphonenumber for $ARCH"

# 设置编译环境
if ! setup_build_env "$ARCH"; then
    log_error "环境设置失败"
    exit 1
fi

# 查找源码目录
SOURCE_DIR=$(find_source_dir "libphonenumber" "$LIBPHONENUMBER_VERSION")
if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "未找到 libphonenumber 源码，请下载 libphonenumber 源码压缩包并放到 src/downloads/ 目录"
    exit 1
fi

# libphonenumber 的 C++ 实现在 cpp 子目录
if [[ -d "$SOURCE_DIR/cpp" ]]; then
    SOURCE_DIR="$SOURCE_DIR/cpp"
fi

log_info "源码目录: $SOURCE_DIR"

# 应用补丁（如果存在）
PATCH_APPLIED=false
# 直接修复源文件（内联修复，无需补丁）
log_info "修复 libphonenumber 源文件以兼容 RE2..."

# 修复 regexp_adapter_re2.cc
REGEXP_RE2_FILE="$SOURCE_DIR/cpp/src/phonenumbers/regexp_adapter_re2.cc"
if [[ -f "$REGEXP_RE2_FILE" ]]; then
    # 检查是否已经修复
    if ! grep -q "using StringPiece = re2::StringPiece;" "$REGEXP_RE2_FILE" 2>/dev/null; then
        log_info "修复 regexp_adapter_re2.cc..."
        # 在 namespace 后添加 using 声明
        sed -i '/^namespace i18n {/,/^namespace phonenumbers {/{
            /^namespace phonenumbers {/a\
// 使用 re2::StringPiece (在新版本 RE2 中是 absl::string_view 的别名)\
using StringPiece = re2::StringPiece;
        }' "$REGEXP_RE2_FILE" 2>/dev/null || true
        
        # 修复 ToString() 方法
        sed -i 's/return utf8_input_\.ToString();/return std::string(utf8_input_.data(), utf8_input_.size());/' "$REGEXP_RE2_FILE" 2>/dev/null || true
        
        # 修复 StringPiece 类型声明
        sed -i 's/StringPiece\* Data()/re2::StringPiece* Data()/g' "$REGEXP_RE2_FILE" 2>/dev/null || true
        sed -i 's/StringPiece utf8_input_/re2::StringPiece utf8_input_/g' "$REGEXP_RE2_FILE" 2>/dev/null || true
        sed -i 's/StringPiece\* utf8_input =/re2::StringPiece* utf8_input =/g' "$REGEXP_RE2_FILE" 2>/dev/null || true
    fi
    
    # 验证修复是否成功
    if grep -q "using StringPiece = re2::StringPiece;" "$REGEXP_RE2_FILE" 2>/dev/null && \
       grep -q "return std::string(utf8_input_.data(), utf8_input_.size());" "$REGEXP_RE2_FILE" 2>/dev/null; then
        log_success "regexp_adapter_re2.cc 修复验证成功"
    else
        log_error "regexp_adapter_re2.cc 修复验证失败，可能需要手动修复"
        exit 1
    fi
fi

# 修复 string_byte_sink.h
STRING_BYTE_SINK_FILE="$SOURCE_DIR/cpp/src/phonenumbers/string_byte_sink.h"
if [[ -f "$STRING_BYTE_SINK_FILE" ]]; then
    # 检查是否已经包含 bytestream.h
    if ! grep -q "#include <unicode/bytestream.h>" "$STRING_BYTE_SINK_FILE" 2>/dev/null; then
        log_info "修复 string_byte_sink.h..."
        # 在 unistr.h 后添加 bytestream.h
        sed -i '/#include <unicode\/unistr.h>/a\
#include <unicode/bytestream.h>
' "$STRING_BYTE_SINK_FILE" 2>/dev/null || true
    fi
    
    # 验证修复是否成功
    if grep -q "#include <unicode/bytestream.h>" "$STRING_BYTE_SINK_FILE" 2>/dev/null; then
        log_success "string_byte_sink.h 修复验证成功"
    else
        log_error "string_byte_sink.h 修复验证失败，可能需要手动修复"
        exit 1
    fi
fi

log_success "源文件修复完成并验证通过"

# 检查是否已编译
if check_already_built "libphonenumber" "$ARCH"; then
    log_info "libphonenumber 已经编译安装"
    exit 0
fi

# 扩展 Abseil 兼容层，添加 Protobuf 需要的头文件
# Protobuf 33.4 依赖 Abseil，需要确保所有必要的 Abseil 头文件存在
ABSL_COMPAT_DIR="${ARCH_INSTALL_DIR}/include/absl"
if [[ ! -d "$ABSL_COMPAT_DIR" ]]; then
    log_info "创建 Abseil 兼容层目录..."
    ensure_dir "$ABSL_COMPAT_DIR/base"
    ensure_dir "$ABSL_COMPAT_DIR/strings"
    ensure_dir "$ABSL_COMPAT_DIR/container"
fi

# 添加 Protobuf 需要的 Abseil 头文件
log_info "扩展 Abseil 兼容层，添加 Protobuf 需要的头文件..."

# absl/base/optimization.h (Protobuf 需要)
if [[ ! -f "$ABSL_COMPAT_DIR/base/optimization.h" ]]; then
    cat > "$ABSL_COMPAT_DIR/base/optimization.h" << 'EOF'
#ifndef ABSL_BASE_OPTIMIZATION_H_
#define ABSL_BASE_OPTIMIZATION_H_

// Minimal Abseil optimization.h for Protobuf compatibility
#define ABSL_CACHELINE_SIZE 64
#define ABSL_PREDICT_TRUE(x) (x)
#define ABSL_PREDICT_FALSE(x) (x)
#define ABSL_UNLIKELY(x) (x)
#define ABSL_LIKELY(x) (x)

#endif  // ABSL_BASE_OPTIMIZATION_H_
EOF
fi

# absl/strings/string_view.h (libphonenumber 需要)
if [[ ! -f "$ABSL_COMPAT_DIR/strings/string_view.h" ]]; then
    cat > "$ABSL_COMPAT_DIR/strings/string_view.h" << 'EOF'
#ifndef ABSL_STRINGS_STRING_VIEW_H_
#define ABSL_STRINGS_STRING_VIEW_H_

#include <string_view>

namespace absl {
using string_view = std::string_view;
}  // namespace absl

#endif  // ABSL_STRINGS_STRING_VIEW_H_
EOF
fi

# absl/container/btree_map.h (某些代码可能需要，但主构建中不需要)
# 为了完整性，也创建这个文件
if [[ ! -f "$ABSL_COMPAT_DIR/container/btree_map.h" ]]; then
    ensure_dir "$ABSL_COMPAT_DIR/container"
    cat > "$ABSL_COMPAT_DIR/container/btree_map.h" << 'EOF'
#ifndef ABSL_CONTAINER_BTREE_MAP_H_
#define ABSL_CONTAINER_BTREE_MAP_H_

#include <map>

namespace absl {
template<typename Key, typename Value>
using btree_map = std::map<Key, Value>;
}  // namespace absl

#endif  // ABSL_CONTAINER_BTREE_MAP_H_
EOF
fi

# 确保 Protobuf 的 runtime_version.h 存在（Protobuf 3.21+ 需要）
# 如果文件不存在，创建一个占位符
PROTOBUF_RUNTIME_VERSION_H="${ARCH_INSTALL_DIR}/include/google/protobuf/runtime_version.h"
if [[ ! -f "$PROTOBUF_RUNTIME_VERSION_H" ]]; then
    log_info "创建 Protobuf runtime_version.h 占位符文件..."
    ensure_dir "$(dirname "$PROTOBUF_RUNTIME_VERSION_H")" >&2
    cat > "$PROTOBUF_RUNTIME_VERSION_H" << 'EOF'
// Auto-generated placeholder for Protobuf runtime_version.h
// This file is required by Protobuf 3.21+ generated code
#ifndef GOOGLE_PROTOBUF_RUNTIME_VERSION_H_
#define GOOGLE_PROTOBUF_RUNTIME_VERSION_H_

// Protobuf runtime version (placeholder)
#define GOOGLE_PROTOBUF_VERSION 3304000

#endif  // GOOGLE_PROTOBUF_RUNTIME_VERSION_H_
EOF
    log_info "已创建 runtime_version.h 占位符"
fi

# 检查并确保 ICU 头文件存在
# 如果 ICU 头文件不存在，可能是安装不完整，尝试从源码复制
ICU_UNISTR_H="${ARCH_INSTALL_DIR}/include/unicode/unistr.h"
ICU_REGEX_H="${ARCH_INSTALL_DIR}/include/unicode/regex.h"
if [[ ! -f "$ICU_UNISTR_H" ]] || [[ ! -f "$ICU_REGEX_H" ]]; then
    log_warning "ICU 头文件缺失，尝试从源码复制..."
    ICU_SOURCE_DIR=$(find_source_dir "icu" "$ICU_VERSION")
    if [[ -n "$ICU_SOURCE_DIR" ]] && [[ -d "$ICU_SOURCE_DIR" ]]; then
        # ICU 源码通常在 source 子目录
        if [[ -d "$ICU_SOURCE_DIR/source" ]]; then
            ICU_SOURCE_DIR="$ICU_SOURCE_DIR/source"
        fi
        
        # 复制 ICU 头文件
        if [[ -d "$ICU_SOURCE_DIR/common/unicode" ]]; then
            ensure_dir "${ARCH_INSTALL_DIR}/include/unicode" >&2
            log_info "从源码复制 ICU 头文件..."
            cp -r "$ICU_SOURCE_DIR/common/unicode"/*.h "${ARCH_INSTALL_DIR}/include/unicode/" 2>/dev/null || true
            cp -r "$ICU_SOURCE_DIR/i18n/unicode"/*.h "${ARCH_INSTALL_DIR}/include/unicode/" 2>/dev/null || true
            log_info "已复制 ICU 头文件"
        else
            log_warning "无法找到 ICU 源码目录，头文件可能缺失"
        fi
    else
        log_warning "无法找到 ICU 源码，头文件可能缺失"
    fi
fi

# 创建构建目录
BUILD_DIR=$(create_build_dir "libphonenumber" "$ARCH")

# 清理构建目录（确保使用最新的源文件修复）
# 注意：只在首次构建或源文件修复后清理，避免不必要的清理
if [[ ! -f "$BUILD_DIR/CMakeCache.txt" ]] || [[ -n "$(find "$SOURCE_DIR" -name "*.cc" -o -name "*.h" -newer "$BUILD_DIR/CMakeCache.txt" 2>/dev/null | head -1)" ]]; then
    log_info "清理构建目录以确保使用最新的源文件修复..."
    clean_build_directory "$BUILD_DIR" "true"
fi

cd "$BUILD_DIR" || exit 1

log_step "配置 libphonenumber..."

# libphonenumber 使用 CMake 构建
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
    # 默认路径（避免重复添加 native）
    # 如果 OHOS_NDK 已经包含 native，直接使用 build/cmake
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

# 转换工具链文件路径为 Unix 格式（用于 CMake）
TOOLCHAIN_FILE_UNIX=$(echo "$TOOLCHAIN_FILE" | sed 's|C:|/c|;s|\\|/|g')

# 配置 CMake（禁用 Boost 依赖，使用标准库，显式指定 Protobuf 路径）
# 转换 Windows 路径为 Unix 格式（用于 CMake 工具链文件）
ARCH_INSTALL_DIR_UNIX=$(echo "$ARCH_INSTALL_DIR" | sed 's|C:|/c|;s|\\|/|g')

# 转换 Windows 路径为 Windows 格式（用于编译器 include 路径）
# Windows 的 clang++ 需要 C:/Users/... 格式，而不是 /c/Users/...
ARCH_INSTALL_DIR_WIN=$(echo "$ARCH_INSTALL_DIR" | sed 's|\\|/|g')

# 添加调试信息
log_info "原始路径: $ARCH_INSTALL_DIR"
log_info "Unix 路径: $ARCH_INSTALL_DIR_UNIX"
log_info "Windows 路径: $ARCH_INSTALL_DIR_WIN"

# 验证头文件存在性
if [[ ! -f "$ARCH_INSTALL_DIR/include/google/protobuf/runtime_version.h" ]]; then
    log_error "Protobuf runtime_version.h 不存在: $ARCH_INSTALL_DIR/include/google/protobuf/runtime_version.h"
fi

# 修改 CMakeLists.txt 以直接设置 Protobuf 和 ICU 路径（在 find_required_library 调用之前）
cd "$SOURCE_DIR" || exit 1
if [[ -f "CMakeLists.txt" ]]; then
    # 检查是否已经修改过（使用标记文件避免重复修改）
    CMAKELISTS_MODIFIED_MARKER="${SOURCE_DIR}/.cmakelists_modified_${ARCH}"
    
    # 如果标记文件存在且 CMakeLists.txt 没有被外部修改，跳过修改
    if [[ -f "$CMAKELISTS_MODIFIED_MARKER" ]] && [[ "$CMakeLists.txt" -ot "$CMAKELISTS_MODIFIED_MARKER" ]]; then
        log_info "CMakeLists.txt 已经修改过，跳过重复修改"
    else
        # 恢复原始 CMakeLists.txt（如果存在备份）
        if [[ -f "CMakeLists.txt.bak" ]]; then
            cp CMakeLists.txt.bak CMakeLists.txt 2>/dev/null || true
        fi
        cp CMakeLists.txt CMakeLists.txt.bak 2>/dev/null || true
        
        # 修复硬编码的 ICU_I18N 路径（第213行）
        # 将硬编码的路径替换为变量
        if grep -q "set(ICU_I18N_INCLUDE_DIR \"/c/Users" CMakeLists.txt 2>/dev/null; then
            log_info "修复硬编码的 ICU_I18N 路径..."
            sed -i "s|set(ICU_I18N_INCLUDE_DIR \"/c/Users.*/install/arm64-v8a/include\")|set(ICU_I18N_INCLUDE_DIR \"$ARCH_INSTALL_DIR_UNIX/include\")|" CMakeLists.txt 2>/dev/null || \
            sed -i.bak "s|set(ICU_I18N_INCLUDE_DIR \"/c/Users.*/install/arm64-v8a/include\")|set(ICU_I18N_INCLUDE_DIR \"$ARCH_INSTALL_DIR_UNIX/include\")|" CMakeLists.txt 2>/dev/null || true
            sed -i "s|set(ICU_I18N_LIB \"/c/Users.*/install/arm64-v8a/lib/libicui18n.a\")|set(ICU_I18N_LIB \"$ARCH_INSTALL_DIR_UNIX/lib/libicui18n.a\")|" CMakeLists.txt 2>/dev/null || \
            sed -i.bak "s|set(ICU_I18N_LIB \"/c/Users.*/install/arm64-v8a/lib/libicui18n.a\")|set(ICU_I18N_LIB \"$ARCH_INSTALL_DIR_UNIX/lib/libicui18n.a\")|" CMakeLists.txt 2>/dev/null || true
        fi
        
        # 强制设置 BUILD_GEOCODER=OFF（在主构建中禁用地理编码器）
        # 在 option() 定义之后直接设置，确保覆盖默认值
        if ! grep -q "# 强制禁用 BUILD_GEOCODER（主构建）" CMakeLists.txt 2>/dev/null; then
            log_info "强制设置 BUILD_GEOCODER=OFF..."
            sed -i "/^option (BUILD_GEOCODER/a\\
# 强制禁用 BUILD_GEOCODER（主构建）\\
set(BUILD_GEOCODER OFF CACHE BOOL \"Build the offline phone number geocoder\" FORCE)\\
" CMakeLists.txt 2>/dev/null || \
            sed -i.bak "/^option (BUILD_GEOCODER/a\\
# 强制禁用 BUILD_GEOCODER（主构建）\\
set(BUILD_GEOCODER OFF CACHE BOOL \"Build the offline phone number geocoder\" FORCE)\\
" CMakeLists.txt 2>/dev/null || true
        fi
        
        # 直接注释掉 tools 目录的 add_subdirectory 调用（主构建中不应该编译工具）
        # 这样可以确保即使 BUILD_GEOCODER 设置失败，也不会编译工具
        # 注意：CMakeLists.txt 中有两处 add_subdirectory(tools)：
        # 1. 在 BUILD_TOOLS_ONLY 块中（第142行）- 这个可以保留
        # 2. 在 BUILD_GEOCODER 块中（第279行）- 这个需要注释掉
        if ! grep -q "# 主构建中禁用 BUILD_GEOCODER 块中的 tools 目录" CMakeLists.txt 2>/dev/null; then
            log_info "注释掉 BUILD_GEOCODER 块中的 tools 目录 add_subdirectory 调用..."
            # 注释 BUILD_GEOCODER 块中的 add_subdirectory(tools)
            # 查找 "if (BUILD_GEOCODER)" 块中的 add_subdirectory
            sed -i '/^if (BUILD_GEOCODER)/,/^endif()/s|^  add_subdirectory("${TOOLS_DIR}" "${TOOLS_BINARY_DIR}")|# 主构建中禁用 BUILD_GEOCODER 块中的 tools 目录\n#  add_subdirectory("${TOOLS_DIR}" "${TOOLS_BINARY_DIR}")|' CMakeLists.txt 2>/dev/null || \
            sed -i.bak '/^if (BUILD_GEOCODER)/,/^endif()/s|^  add_subdirectory("${TOOLS_DIR}" "${TOOLS_BINARY_DIR}")|# 主构建中禁用 BUILD_GEOCODER 块中的 tools 目录\n#  add_subdirectory("${TOOLS_DIR}" "${TOOLS_BINARY_DIR}")|' CMakeLists.txt 2>/dev/null || true
        fi
        
        # 在 find_required_library (PROTOBUF 调用之前插入变量设置
        # 注意：需要同时设置 include_directories 以确保编译器能找到头文件
        if ! grep -q "set(PROTOBUF_INCLUDE_DIR" CMakeLists.txt 2>/dev/null || ! grep -q "# 设置 Protobuf include 目录（用于主构建）" CMakeLists.txt 2>/dev/null; then
            sed -i "/find_required_library (PROTOBUF/i\\
# 设置 Protobuf include 目录（用于主构建）\\
set(PROTOBUF_INCLUDE_DIR \"$ARCH_INSTALL_DIR_UNIX/include\")\\
set(PROTOBUF_LIB \"$ARCH_INSTALL_DIR_UNIX/lib/libprotobuf.a\")\\
include_directories (\"$ARCH_INSTALL_DIR_UNIX/include\")\\
" CMakeLists.txt 2>/dev/null || \
            sed -i.bak "/find_required_library (PROTOBUF/i\\
# 设置 Protobuf include 目录（用于主构建）\\
set(PROTOBUF_INCLUDE_DIR \"$ARCH_INSTALL_DIR_UNIX/include\")\\
set(PROTOBUF_LIB \"$ARCH_INSTALL_DIR_UNIX/lib/libprotobuf.a\")\\
include_directories (\"$ARCH_INSTALL_DIR_UNIX/include\")\\
" CMakeLists.txt 2>/dev/null || true
        fi
        
        # 在 find_required_library (ICU_UC 调用之前插入 ICU_UC 变量设置
        # 注意：需要同时设置 include_directories 以确保编译器能找到头文件
        if ! grep -q "set(ICU_UC_INCLUDE_DIR" CMakeLists.txt 2>/dev/null || ! grep -q "# 设置 ICU include 目录（用于主构建）" CMakeLists.txt 2>/dev/null; then
            sed -i "/find_required_library (ICU_UC/i\\
# 设置 ICU include 目录（用于主构建）\\
set(ICU_UC_INCLUDE_DIR \"$ARCH_INSTALL_DIR_UNIX/include\")\\
set(ICU_UC_LIB \"$ARCH_INSTALL_DIR_UNIX/lib/libicuuc.a\")\\
include_directories (\"$ARCH_INSTALL_DIR_UNIX/include\")\\
" CMakeLists.txt 2>/dev/null || \
            sed -i.bak "/find_required_library (ICU_UC/i\\
# 设置 ICU include 目录（用于主构建）\\
set(ICU_UC_INCLUDE_DIR \"$ARCH_INSTALL_DIR_UNIX/include\")\\
set(ICU_UC_LIB \"$ARCH_INSTALL_DIR_UNIX/lib/libicuuc.a\")\\
include_directories (\"$ARCH_INSTALL_DIR_UNIX/include\")\\
" CMakeLists.txt 2>/dev/null || true
        fi
        
        # 在 find_required_library (ICU_I18N 调用之前插入 ICU_I18N 变量设置
        # 注意：ICU_I18N 使用与 ICU_UC 相同的 include 目录，不需要重复设置 include_directories
        if ! grep -q "set(ICU_I18N_INCLUDE_DIR" CMakeLists.txt 2>/dev/null; then
            sed -i "/find_required_library (ICU_I18N/i\\
set(ICU_I18N_INCLUDE_DIR \"$ARCH_INSTALL_DIR_UNIX/include\")\\
set(ICU_I18N_LIB \"$ARCH_INSTALL_DIR_UNIX/lib/libicui18n.a\")\\
" CMakeLists.txt 2>/dev/null || \
            sed -i.bak "/find_required_library (ICU_I18N/i\\
set(ICU_I18N_INCLUDE_DIR \"$ARCH_INSTALL_DIR_UNIX/include\")\\
set(ICU_I18N_LIB \"$ARCH_INSTALL_DIR_UNIX/lib/libicui18n.a\")\\
" CMakeLists.txt 2>/dev/null || true
        fi
        
        # 修改 target_include_directories 以包含依赖库的 include 目录
        # 确保编译器能找到 Protobuf 和 ICU 的头文件
        if grep -q "target_include_directories(phonenumber PUBLIC" CMakeLists.txt 2>/dev/null; then
            # 备份原始文件
            cp CMakeLists.txt CMakeLists.txt.bak.target-include 2>/dev/null || true
            # 替换 target_include_directories 行，添加依赖库的 include 目录
            sed -i "s|target_include_directories(phonenumber PUBLIC \$<INSTALL_INTERFACE:include>)|target_include_directories(phonenumber PUBLIC \$<INSTALL_INTERFACE:include> \"$ARCH_INSTALL_DIR_UNIX/include\")|" CMakeLists.txt 2>/dev/null || \
            sed -i.bak "s|target_include_directories(phonenumber PUBLIC \$<INSTALL_INTERFACE:include>)|target_include_directories(phonenumber PUBLIC \$<INSTALL_INTERFACE:include> \"$ARCH_INSTALL_DIR_UNIX/include\")|" CMakeLists.txt 2>/dev/null || true
        fi
        
        # 修改主 CMakeLists.txt 中的 add_definitions 以添加 -Wno-deprecated-builtins
        # 这可以解决 Abseil 使用已弃用内置函数的问题
        if ! grep -q 'Wno-deprecated-builtins' CMakeLists.txt 2>/dev/null; then
            if grep -q 'add_definitions ("-Wall -Werror")' CMakeLists.txt 2>/dev/null; then
                cp CMakeLists.txt CMakeLists.txt.bak.add-definitions 2>/dev/null || true
                sed -i 's/add_definitions ("-Wall -Werror")/add_definitions ("-Wall -Werror -Wno-deprecated-builtins")/' CMakeLists.txt 2>/dev/null || \
                sed -i.bak 's/add_definitions ("-Wall -Werror")/add_definitions ("-Wall -Werror -Wno-deprecated-builtins")/' CMakeLists.txt 2>/dev/null || true
            fi
        fi
        
        # 创建标记文件，记录修改完成
        touch "$CMAKELISTS_MODIFIED_MARKER" 2>/dev/null || true
    fi
fi

# 注意：不再修改 tools/cpp/CMakeLists.txt，因为 BUILD_GEOCODER=OFF，不会编译工具

# 查找主机版本的 protoc（用于生成 protobuf 文件）
# 优先使用主机构建的 protoc，如果没有则尝试系统 protoc
HOST_PROTOC=""
PROTOBUF_HOST_BUILD_DIR="${ARCH_BUILD_DIR}/protobuf-host"
if [[ -f "$PROTOBUF_HOST_BUILD_DIR/src/protoc" ]]; then
    HOST_PROTOC="$PROTOBUF_HOST_BUILD_DIR/src/protoc"
elif [[ -f "$PROTOBUF_HOST_BUILD_DIR/src/protoc.exe" ]]; then
    HOST_PROTOC="$PROTOBUF_HOST_BUILD_DIR/src/protoc.exe"
elif [[ -f "$PROTOBUF_HOST_BUILD_DIR/protoc" ]]; then
    HOST_PROTOC="$PROTOBUF_HOST_BUILD_DIR/protoc"
elif [[ -f "$PROTOBUF_HOST_BUILD_DIR/protoc.exe" ]]; then
    HOST_PROTOC="$PROTOBUF_HOST_BUILD_DIR/protoc.exe"
elif [[ -f "$PROTOBUF_HOST_BUILD_DIR/install/bin/protoc" ]]; then
    HOST_PROTOC="$PROTOBUF_HOST_BUILD_DIR/install/bin/protoc"
elif [[ -f "$PROTOBUF_HOST_BUILD_DIR/install/bin/protoc.exe" ]]; then
    HOST_PROTOC="$PROTOBUF_HOST_BUILD_DIR/install/bin/protoc.exe"
elif command -v protoc &> /dev/null; then
    HOST_PROTOC="protoc"
else
    log_warning "未找到主机 protoc，将尝试使用交叉编译的 protoc（可能失败）"
    HOST_PROTOC="${ARCH_INSTALL_DIR}/bin/protoc"
fi

log_info "使用主机 protoc: $HOST_PROTOC"

# 修改 CMakeLists.txt 以在主构建时也使用主机 protoc
cd "$SOURCE_DIR" || exit 1
if [[ -f "CMakeLists.txt" ]] && [[ -n "$HOST_PROTOC" ]] && [[ -f "$HOST_PROTOC" ]]; then
    # 检查是否已经修改过（避免重复修改）
    if ! grep -q "# 设置主机 protoc 路径（用于主构建）" CMakeLists.txt 2>/dev/null; then
        cp CMakeLists.txt CMakeLists.txt.bak.main-build 2>/dev/null || true
        # 将 HOST_PROTOC 转换为 Unix 格式
        HOST_PROTOC_UNIX=$(echo "$HOST_PROTOC" | sed 's|C:|/c|;s|\\|/|g')
        # 在 find_required_program (PROTOC 之前插入 PROTOC_BIN 设置
        # 使用临时文件来插入多行内容（更可靠的方法）
        PROTOC_INSERT_FILE="${SOURCE_DIR}/protoc_insert_main_build.txt"
        cat > "$PROTOC_INSERT_FILE" <<EOF
# 设置主机 protoc 路径（用于主构建）
if(EXISTS "$HOST_PROTOC_UNIX")
  set(PROTOC_BIN "$HOST_PROTOC_UNIX" CACHE FILEPATH "Protocol Buffers compiler" FORCE)
endif()
EOF
        # 使用 awk 来插入多行（最可靠的方法）
        awk -v insert_file="$PROTOC_INSERT_FILE" '
            /^find_required_program \(PROTOC/ {
                while ((getline line < insert_file) > 0) {
                    print line
                }
                close(insert_file)
            }
            {print}
        ' CMakeLists.txt > CMakeLists.txt.tmp && \
        mv CMakeLists.txt.tmp CMakeLists.txt 2>/dev/null || true
        rm -f "$PROTOC_INSERT_FILE" 2>/dev/null || true
    fi
fi

cd "$BUILD_DIR" || exit 1

# 如果 CMakeCache.txt 存在，说明之前已经配置过，需要清理缓存以应用新配置
if [[ -f "CMakeCache.txt" ]]; then
    log_info "检测到旧的 CMake 配置，清理缓存以应用新配置..."
    clean_cmake_cache "$BUILD_DIR"
fi

# 确保必要的头文件存在（在配置之前）
# 注意：这些检查已经在前面完成，这里只做最终确认
if [[ ! -f "$PROTOBUF_RUNTIME_VERSION_H" ]]; then
    log_warning "Protobuf runtime_version.h 不存在，将在配置时创建"
fi

if [[ ! -f "$ICU_UNISTR_H" ]] || [[ ! -f "$ICU_REGEX_H" ]]; then
    log_warning "ICU 头文件缺失，可能影响编译"
fi

# 将主机 protoc 的目录添加到 PATH（用于编译 .proto 文件）
if [[ -n "$HOST_PROTOC" ]] && [[ -f "$HOST_PROTOC" ]]; then
    HOST_PROTOC_DIR=$(dirname "$HOST_PROTOC")
    export PATH="$HOST_PROTOC_DIR:$PATH"
    log_info "已将主机 protoc 目录添加到 PATH: $HOST_PROTOC_DIR"
fi

# 将 HOST_PROTOC 转换为 Unix 格式（用于 CMake）
HOST_PROTOC_UNIX=$(echo "$HOST_PROTOC" | sed 's|C:|/c|;s|\\|/|g')

# 检查是否可以使用 RE2 替代 ICU（推荐，更轻量且避免 ICU 相关问题）
USE_RE2_FOR_REGEXP=false
RE2_LIB="${ARCH_INSTALL_DIR}/lib/libre2.a"
RE2_HEADER="${ARCH_INSTALL_DIR}/include/re2/re2.h"

if [[ -f "$RE2_LIB" ]] && [[ -f "$RE2_HEADER" ]]; then
    USE_RE2_FOR_REGEXP=true
    log_info "检测到 RE2 库，将使用 RE2 替代 ICU 正则表达式引擎（推荐）"
elif [[ -f "${ARCH_INSTALL_DIR}/lib/libicuuc.a" ]] && [[ -f "${ARCH_INSTALL_DIR}/include/unicode/unistr.h" ]]; then
    log_info "使用 ICU 正则表达式引擎"
else
    log_warning "未找到 RE2 或 ICU，将尝试使用 ICU（如果编译失败，请先编译 RE2）"
fi

# 确保 BUILD_GEOCODER 被强制设置为 OFF（使用 FORCE 覆盖缓存）
CMAKE_ARGS=(
    "\"$CMAKE_CMD\" \"$SOURCE_DIR\""
    "-G \"Ninja\""
    "-DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE_UNIX\""
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DOHOS_ARCH=\"$ARCH\""
    "-DOHOS_STL=c++_static"
    "-DOHOS_PLATFORM=OHOS"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_INSTALL_PREFIX=\"$ARCH_INSTALL_DIR_UNIX\""
    "-DBUILD_SHARED_LIBS=OFF"
    "-DBUILD_TESTING=OFF"
    "-DREGENERATE_METADATA=OFF"
    "-DBUILD_GEOCODER=OFF"
    "-DUSE_STD_MAP=ON"
    "-DUSE_BOOST=OFF"
)

# 根据可用库选择正则表达式引擎
# 注意：即使使用 RE2，libphonenumber 的某些代码（如 string_byte_sink.h）仍然需要 ICU 头文件
if [[ "$USE_RE2_FOR_REGEXP" == true ]]; then
    CMAKE_ARGS+=(
        "-DUSE_RE2=ON"
        "-DUSE_ICU_REGEXP=OFF"
        "-DRE2_ROOT=\"$ARCH_INSTALL_DIR_UNIX\""
        "-DRE2_INCLUDE_DIR=\"$ARCH_INSTALL_DIR_UNIX/include\""
        "-DRE2_LIB=\"$ARCH_INSTALL_DIR_UNIX/lib/libre2.a\""
        # 即使使用 RE2，也需要 ICU 头文件（某些代码依赖 ICU）
        "-DICU_ROOT=\"$ARCH_INSTALL_DIR_UNIX\""
        "-DICU_INCLUDE_DIR=\"$ARCH_INSTALL_DIR_UNIX/include\""
        "-DICU_UC_INCLUDE_DIR=\"$ARCH_INSTALL_DIR_UNIX/include\""
    )
    log_info "配置 libphonenumber 使用 RE2 正则表达式引擎（但仍需要 ICU 头文件）"
else
    CMAKE_ARGS+=(
        "-DUSE_RE2=OFF"
        "-DUSE_ICU_REGEXP=ON"
        "-DICU_ROOT=\"$ARCH_INSTALL_DIR_UNIX\""
        "-DICU_INCLUDE_DIR=\"$ARCH_INSTALL_DIR_UNIX/include\""
        "-DICU_UC_INCLUDE_DIR=\"$ARCH_INSTALL_DIR_UNIX/include\""
        "-DICU_UC_LIB=\"$ARCH_INSTALL_DIR_UNIX/lib/libicuuc.a\""
        "-DICU_I18N_INCLUDE_DIR=\"$ARCH_INSTALL_DIR_UNIX/include\""
        "-DICU_I18N_LIB=\"$ARCH_INSTALL_DIR_UNIX/lib/libicui18n.a\""
    )
    log_info "配置 libphonenumber 使用 ICU 正则表达式引擎"
fi

CMAKE_ARGS+=(
    "-DPROTOBUF_ROOT=\"$ARCH_INSTALL_DIR_UNIX\""
    "-DPROTOBUF_INCLUDE_DIR=\"$ARCH_INSTALL_DIR_UNIX/include\""
    "-DPROTOBUF_LIBRARY=\"$ARCH_INSTALL_DIR_UNIX/lib/libprotobuf.a\""
    "-DPROTOBUF_LIB=\"$ARCH_INSTALL_DIR_UNIX/lib/libprotobuf.a\""
    "-DCMAKE_PREFIX_PATH=\"$ARCH_INSTALL_DIR_UNIX\""
    "-DCMAKE_INCLUDE_PATH=\"$ARCH_INSTALL_DIR_UNIX/include\""
    "-DCMAKE_LIBRARY_PATH=\"$ARCH_INSTALL_DIR_UNIX/lib\""
    "-DCMAKE_FIND_ROOT_PATH=\"$ARCH_INSTALL_DIR\""
    "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
    "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    "-DCMAKE_C_COMPILER=\"$CC\""
    "-DCMAKE_CXX_COMPILER=\"$CXX\""
    "-DCMAKE_C_FLAGS=\"$CFLAGS -Wno-unused-command-line-argument -I$ARCH_INSTALL_DIR_WIN/include -I$ARCH_INSTALL_DIR_WIN/include/unicode\""
    "-DCMAKE_CXX_FLAGS=\"$CXXFLAGS -Wno-unused-command-line-argument -Wno-deprecated-builtins -I$ARCH_INSTALL_DIR_WIN/include -I$ARCH_INSTALL_DIR_WIN/include/unicode -I$ARCH_INSTALL_DIR_WIN/include/absl\""
    "-DCMAKE_CXX_STANDARD=17"
    "-DCMAKE_CXX_STANDARD_REQUIRED=ON"
    "-DCMAKE_EXE_LINKER_FLAGS=\"$LDFLAGS\""
    "-DPROTOC=\"$HOST_PROTOC\""
    "-DPROTOC_BIN=\"$HOST_PROTOC_UNIX\""
)

# 构建完整的 CMake 命令
CMAKE_CMD_STR="${CMAKE_ARGS[*]}"

run_command \
    "$CMAKE_CMD_STR" \
    "${LOGS_DIR}/build/libphonenumber_${ARCH}_configure.log" \
    "配置 libphonenumber" || {
    log_error "libphonenumber 配置失败"
    exit 1
}

# 配置后再次强制设置 BUILD_GEOCODER=OFF（确保覆盖缓存）
log_info "再次强制设置 BUILD_GEOCODER=OFF（覆盖缓存）..."
run_command \
    "\"$CMAKE_CMD\" -DBUILD_GEOCODER:BOOL=OFF ." \
    "${LOGS_DIR}/build/libphonenumber_${ARCH}_configure_force_geocoder_off.log" \
    "强制设置 BUILD_GEOCODER=OFF" || true

# 注意：不再构建主机工具（generate_geocoding_data）
# BUILD_GEOCODER=OFF 已禁用地理编码功能，TDLib 只需要电话号码解析功能
# 主机工具不是必需的，可以安全删除

# 编译（使用 cmake --build）
cd "$BUILD_DIR" || exit 1
log_step "编译 libphonenumber..."
run_command \
    "\"$CMAKE_CMD\" --build . --config Release -j${PARALLEL_JOBS}" \
    "${LOGS_DIR}/build/libphonenumber_${ARCH}_build.log" \
    "编译 libphonenumber"

if [[ $? -ne 0 ]]; then
    log_error "libphonenumber 编译失败"
    # 恢复 Abseil 兼容层目录（如果之前备份了）
    if [[ -d "$ABSL_COMPAT_BACKUP" ]]; then
        log_info "恢复 Abseil 兼容层目录"
        rm -rf "$ABSL_COMPAT_DIR" 2>/dev/null || true
        mv "$ABSL_COMPAT_BACKUP" "$ABSL_COMPAT_DIR" 2>/dev/null || true
    fi
    # 恢复 CMakeLists.txt（如果之前修改过）
    if [[ -f "$SOURCE_DIR/CMakeLists.txt.bak.main-build" ]]; then
        mv "$SOURCE_DIR/CMakeLists.txt.bak.main-build" "$SOURCE_DIR/CMakeLists.txt" 2>/dev/null || true
    fi
    exit 1
fi

# 安装（使用 cmake --install）
log_step "安装 libphonenumber..."
run_command \
    "\"$CMAKE_CMD\" --install . --config Release" \
    "${LOGS_DIR}/build/libphonenumber_${ARCH}_install.log" \
    "安装 libphonenumber"

if [[ $? -ne 0 ]]; then
    log_error "libphonenumber 安装失败"
    # 恢复 Abseil 兼容层目录（如果之前备份了）
    if [[ -d "$ABSL_COMPAT_BACKUP" ]]; then
        log_info "恢复 Abseil 兼容层目录"
        rm -rf "$ABSL_COMPAT_DIR" 2>/dev/null || true
        mv "$ABSL_COMPAT_BACKUP" "$ABSL_COMPAT_DIR" 2>/dev/null || true
    fi
    exit 1
fi

# 编译后验证
if ! verify_build_result "libphonenumber" "$ARCH" "libphonenumber.a" "phonenumbers"; then
    log_error "libphonenumber 编译验证失败"
    # 恢复 Abseil 兼容层目录（如果之前备份了）
    if [[ -d "$ABSL_COMPAT_BACKUP" ]]; then
        log_info "恢复 Abseil 兼容层目录"
        rm -rf "$ABSL_COMPAT_DIR" 2>/dev/null || true
        mv "$ABSL_COMPAT_BACKUP" "$ABSL_COMPAT_DIR" 2>/dev/null || true
    fi
    exit 1
fi

# 恢复 Abseil 兼容层目录（如果之前备份了）
if [[ -d "$ABSL_COMPAT_BACKUP" ]]; then
    log_info "恢复 Abseil 兼容层目录"
    rm -rf "$ABSL_COMPAT_DIR" 2>/dev/null || true
    mv "$ABSL_COMPAT_BACKUP" "$ABSL_COMPAT_DIR" 2>/dev/null || true
fi

log_success "libphonenumber 编译安装完成: $ARCH"
