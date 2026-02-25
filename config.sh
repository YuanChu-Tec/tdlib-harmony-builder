#!/bin/bash
# TDLib for HarmonyOS 构建配置文件

# ============================================
# 路径规范化函数
# ============================================
# 将路径解析为绝对路径（不依赖当前工作目录）
to_absolute_path() {
    local path="$1"
    local base="${2:-}"
    if [[ -z "$path" ]]; then
        echo ""
        return
    fi
    # 已是绝对路径：Unix / 开头 或 Windows 盘符
    if [[ "$path" == /* ]] || [[ "$path" =~ ^[A-Za-z]: ]]; then
        echo "$path"
        return
    fi
    # 相对路径：先 cd 到 base 或当前目录再 pwd
    if [[ -n "$base" ]] && [[ -d "$base" ]]; then
        (cd "$base" 2>/dev/null && cd "$path" 2>/dev/null && pwd) || echo "${base}/${path}"
    else
        (cd "$path" 2>/dev/null && pwd) || echo "$path"
    fi
}

# 规范化 Windows 路径格式
normalize_path() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        echo ""
        return
    fi
    
    # 在 Windows 环境下，规范化路径格式
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
        # 方法1: 使用 tr 命令（更可靠）
        if command -v tr &> /dev/null; then
            path=$(echo "$path" | tr '\\' '/')
        else
            # 方法2: 使用 sed（备用）
            path=$(echo "$path" | sed 's|\\|/|g' 2>/dev/null || echo "$path")
        fi
        
        # 处理 Windows 路径格式（如 C:Users -> C:/Users）
        # 使用更简单的字符串操作
        if [[ "$path" =~ ^[A-Za-z]:[^/] ]]; then
            # 在冒号后添加斜杠
            path=$(echo "$path" | sed 's|^\([A-Za-z]\):\([^/]\)|\1:/\2|' 2>/dev/null || echo "$path")
        fi
        
        # 移除末尾的斜杠（如果有）
        path="${path%/}"
    fi
    
    echo "$path"
}

# ============================================
# 加载用户配置文件
# ============================================
# 首先尝试加载用户配置文件（使用绝对路径，与工作目录无关）
CONFIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_CONFIG_FILE="${CONFIG_SCRIPT_DIR}/user_config.sh"
if [[ -f "$USER_CONFIG_FILE" ]]; then
    source "$USER_CONFIG_FILE"
    echo "✅ 已加载用户配置文件: $USER_CONFIG_FILE"
    
    # 规范化 Windows 路径（在加载配置后立即处理）
    # 如果路径包含示例值（YourName），则忽略它
    if [[ -n "$OHOS_NDK" ]]; then
        if [[ "$OHOS_NDK" == *"YourName"* ]]; then
            # 如果是从环境变量读取的示例路径，清空它，让配置文件中的默认值生效
            unset OHOS_NDK
        else
            OHOS_NDK=$(normalize_path "$OHOS_NDK")
            export OHOS_NDK
        fi
    fi
else
    # 如果用户配置文件不存在，提示用户
    if [[ -f "${CONFIG_SCRIPT_DIR}/user_config.sh.example" ]]; then
        echo "ℹ️  提示: 未找到用户配置文件 user_config.sh"
        echo "   可以复制 user_config.sh.example 为 user_config.sh 并修改配置"
        echo "   cp user_config.sh.example user_config.sh"
    fi
fi

# ============================================
# 项目基本信息
# ============================================
export PROJECT_NAME="tdlib-harmonyos"
export PROJECT_VERSION="1.8.0-harmonyos"
export BUILD_DATE=$(date +%Y%m%d)

# ============================================
# 路径配置（统一解析为绝对路径，避免移动项目或不同 CWD 导致路径错乱）
# ============================================
export PROJECT_ROOT="${CONFIG_SCRIPT_DIR}"

# 源码目录（可被 user_config 覆盖），解析为绝对路径
_source_dir="${SOURCE_DIR:-${PROJECT_ROOT}/src}"
export SOURCE_DIR=$(to_absolute_path "$_source_dir" "$PROJECT_ROOT")
_download_dir="${DOWNLOAD_DIR:-${SOURCE_DIR}/downloads}"
export DOWNLOAD_DIR=$(to_absolute_path "$_download_dir" "$PROJECT_ROOT")
_extract_dir="${EXTRACT_DIR:-${SOURCE_DIR}/extracted}"
export EXTRACT_DIR=$(to_absolute_path "$_extract_dir" "$PROJECT_ROOT")

# 构建目录（可被 user_config 覆盖），解析为绝对路径
_build_dir="${BUILD_DIR:-${PROJECT_ROOT}/build}"
export BUILD_DIR=$(to_absolute_path "$_build_dir" "$PROJECT_ROOT")
_install_dir="${INSTALL_DIR:-${PROJECT_ROOT}/install}"
export INSTALL_DIR=$(to_absolute_path "$_install_dir" "$PROJECT_ROOT")
_dist_dir="${DIST_DIR:-${PROJECT_ROOT}/dist}"
export DIST_DIR=$(to_absolute_path "$_dist_dir" "$PROJECT_ROOT")

# 脚本和补丁目录（可被 user_config 覆盖），解析为绝对路径
export SCRIPTS_DIR=$(to_absolute_path "${SCRIPTS_DIR:-${PROJECT_ROOT}/scripts}" "$PROJECT_ROOT")
export PATCHES_DIR=$(to_absolute_path "${PATCHES_DIR:-${PROJECT_ROOT}/patches}" "$PROJECT_ROOT")
export LOGS_DIR=$(to_absolute_path "${LOGS_DIR:-${PROJECT_ROOT}/logs}" "$PROJECT_ROOT")
export CMAKE_DIR=$(to_absolute_path "${CMAKE_DIR:-${PROJECT_ROOT}/cmake}" "$PROJECT_ROOT")

# 创建必要的目录
mkdir -p "${DOWNLOAD_DIR}" "${EXTRACT_DIR}" "${BUILD_DIR}" \
         "${INSTALL_DIR}" "${DIST_DIR}" "${LOGS_DIR}" "${CMAKE_DIR}"

# 如果启用自动获取最新版本，在加载时更新（延迟到需要时）
# 注意：版本更新会在 download_sources.sh 中执行，避免每次加载配置都查询网络

# 验证配置（如果直接运行 config.sh，会进行验证）
# 如果从其他脚本加载，可以通过 validate_config() 函数手动验证
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 直接运行 config.sh 时，进行验证
    validate_config
fi

# ============================================
# HarmonyOS 工具链配置
# ============================================
# HarmonyOS NDK 路径（优先使用用户配置，否则使用默认值）
# 如果用户配置文件中未设置，尝试从环境变量获取，最后使用默认路径
# 注意：如果环境变量包含示例路径（YourName），则忽略它
if [[ -z "$OHOS_NDK" ]] || [[ "$OHOS_NDK" == *"YourName"* ]]; then
    # 如果环境变量是示例路径，清空它
    if [[ "$OHOS_NDK" == *"YourName"* ]]; then
        unset OHOS_NDK
    fi
    export OHOS_NDK="${OHOS_NDK:-${HOME}/harmony/ndk}"
fi

# 规范化 Windows 路径（将反斜杠转换为正斜杠）
if [[ -n "$OHOS_NDK" ]]; then
    OHOS_NDK=$(normalize_path "$OHOS_NDK")
    export OHOS_NDK
fi

if [[ -z "$OHOS_SDK" ]]; then
    export OHOS_SDK="${OHOS_SDK:-${HOME}/harmony/sdk}"
fi

if [[ -z "$OHOS_API_LEVEL" ]]; then
    export OHOS_API_LEVEL="${OHOS_API_LEVEL:-9}"
fi

# 工具链路径（根据实际NDK结构调整）
# 支持多种路径结构：
# 1. OpenHarmony SDK 结构: SDK/native/llvm
# 2. 标准 NDK 结构: NDK/native/llvm
# 3. 旧版本结构: NDK/toolchains/llvm

# 首先尝试 OpenHarmony SDK 结构（如果 NDK 路径已经包含 native）
# 规范化路径以确保正确匹配
OHOS_NDK_NORMALIZED=$(normalize_path "$OHOS_NDK")
if [[ "$OHOS_NDK_NORMALIZED" == *"/native" ]] || [[ "$OHOS_NDK_NORMALIZED" == *"/native/" ]]; then
    # NDK 路径已经指向 native 目录
    export TOOLCHAIN_DIR="${OHOS_NDK_NORMALIZED}/llvm"
    export SYSROOT="${OHOS_NDK_NORMALIZED}/sysroot"
else
    # 标准结构：NDK/native/llvm
    export TOOLCHAIN_DIR="${OHOS_NDK_NORMALIZED}/native/llvm"
    export SYSROOT="${OHOS_NDK_NORMALIZED}/native/sysroot"
fi

# 规范化工具链目录路径
TOOLCHAIN_DIR=$(normalize_path "$TOOLCHAIN_DIR")
export TOOLCHAIN_DIR
SYSROOT=$(normalize_path "$SYSROOT")
export SYSROOT

# 如果上述路径不存在，尝试其他可能的结构
if [[ ! -d "$TOOLCHAIN_DIR" ]]; then
    # 尝试旧版本结构
    export TOOLCHAIN_DIR="${OHOS_NDK}/toolchains/llvm"
    export SYSROOT="${TOOLCHAIN_DIR}/sysroot"
    
    # 如果还是不存在，尝试直接使用 NDK 路径下的 llvm
    if [[ ! -d "$TOOLCHAIN_DIR" ]]; then
        export TOOLCHAIN_DIR="${OHOS_NDK}/llvm"
        export SYSROOT="${OHOS_NDK}/sysroot"
    fi
fi

# ============================================
# 构建选项
# ============================================
# 构建模式（优先使用用户配置）
if [[ -z "$BUILD_MODE" ]]; then
    export BUILD_MODE="${BUILD_MODE:-Release}"  # Release, Debug, Profile
fi

# 并行任务数（优先使用用户配置）
if [[ -z "$PARALLEL_JOBS" ]]; then
    export PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
fi

# 目标架构（优先使用用户配置）
if [[ -z "$ARCHITECTURES" ]] || [[ "$ARCHITECTURES" == "arm64-v8a" ]]; then
    # 如果用户配置是字符串，转换为数组
    if [[ "$ARCHITECTURES" == "arm64-v8a" ]] || [[ -z "$ARCHITECTURES" ]]; then
        export ARCHITECTURES=("arm64-v8a" "armeabi-v7a" "x86_64")
    else
        # 将空格分隔的字符串转换为数组
        IFS=' ' read -ra ARCH_ARRAY <<< "$ARCHITECTURES"
        export ARCHITECTURES=("${ARCH_ARRAY[@]}")
    fi
fi

# ============================================
# 库版本配置
# ============================================
# 是否使用最新版本（在 user_config.sh 中可配置）
# 如果设置为 "auto" 或 "latest"，将自动获取最新版本
# 如果设置为具体版本号，将使用该版本
# 默认: 使用固定版本（稳定）
export USE_LATEST_VERSION="${USE_LATEST_VERSION:-false}"

# 默认版本（如果无法获取最新版本或 USE_LATEST_VERSION=false 时使用）
export OPENSSL_VERSION_DEFAULT="1.1.1w"
export ZLIB_VERSION_DEFAULT="1.2.13"
export SQLITE_VERSION_DEFAULT="3420000"
export ICU_VERSION_DEFAULT="72.1"
export PROTOBUF_VERSION_DEFAULT="3.21.12"
export LIBPHONENUMBER_VERSION_DEFAULT="8.13.14"
export CRC32C_VERSION_DEFAULT="1.1.2"
export XXHASH_VERSION_DEFAULT="0.8.2"
export ABSEIL_VERSION_DEFAULT="20240116.2"
export RE2_VERSION_DEFAULT="2023-06-01"
export LIBEVENT_VERSION_DEFAULT="2.1.12"
export LZ4_VERSION_DEFAULT="1.9.4"
export SNAPPY_VERSION_DEFAULT="1.1.9"
export DOUBLE_CONVERSION_VERSION_DEFAULT="3.2.1"
export TDLIB_VERSION_DEFAULT="1.8.0"

# 初始化版本变量（将在获取最新版本后更新）
export OPENSSL_VERSION="${OPENSSL_VERSION:-$OPENSSL_VERSION_DEFAULT}"
export ZLIB_VERSION="${ZLIB_VERSION:-$ZLIB_VERSION_DEFAULT}"
export SQLITE_VERSION="${SQLITE_VERSION:-$SQLITE_VERSION_DEFAULT}"
export ICU_VERSION="${ICU_VERSION:-$ICU_VERSION_DEFAULT}"
export PROTOBUF_VERSION="${PROTOBUF_VERSION:-$PROTOBUF_VERSION_DEFAULT}"
export LIBPHONENUMBER_VERSION="${LIBPHONENUMBER_VERSION:-$LIBPHONENUMBER_VERSION_DEFAULT}"
export CRC32C_VERSION="${CRC32C_VERSION:-$CRC32C_VERSION_DEFAULT}"
export XXHASH_VERSION="${XXHASH_VERSION:-$XXHASH_VERSION_DEFAULT}"
export ABSEIL_VERSION="${ABSEIL_VERSION:-$ABSEIL_VERSION_DEFAULT}"
export RE2_VERSION="${RE2_VERSION:-$RE2_VERSION_DEFAULT}"
export LIBEVENT_VERSION="${LIBEVENT_VERSION:-$LIBEVENT_VERSION_DEFAULT}"
export LZ4_VERSION="${LZ4_VERSION:-$LZ4_VERSION_DEFAULT}"
export SNAPPY_VERSION="${SNAPPY_VERSION:-$SNAPPY_VERSION_DEFAULT}"
export DOUBLE_CONVERSION_VERSION="${DOUBLE_CONVERSION_VERSION:-$DOUBLE_CONVERSION_VERSION_DEFAULT}"
export TDLIB_VERSION="${TDLIB_VERSION:-$TDLIB_VERSION_DEFAULT}"

# ============================================
# 获取最新版本函数
# ============================================
update_to_latest_versions() {
    if [[ "$USE_LATEST_VERSION" != "true" ]] && \
       [[ "$USE_LATEST_VERSION" != "auto" ]] && \
       [[ "$USE_LATEST_VERSION" != "latest" ]]; then
        return 0  # 不使用最新版本，跳过
    fi
    
    # 简单的日志函数（如果 common.sh 未加载）
    if ! command -v log_info &> /dev/null; then
        log_info() { echo "ℹ️  $1"; }
        log_success() { echo "✅ $1"; }
        log_warning() { echo "⚠️  $1"; }
        log_error() { echo "❌ $1" >&2; }
    fi
    
    log_info "正在获取最新版本..."
    
    # 加载版本获取函数
    if [[ -f "$SCRIPTS_DIR/get_latest_version.sh" ]]; then
        source "$SCRIPTS_DIR/get_latest_version.sh"
    else
        log_warning "版本获取脚本不存在，使用默认版本"
        return 1
    fi
    
    # 需要检查的库
    # 注意：RE2 新版本对 Abseil 依赖较重，且需要完整的 C++17 标准库支持，
    # 在 HarmonyOS NDK 上存在兼容性问题，因此这里**刻意不对 RE2 使用最新版本**，
    # 而是固定在 RE2_VERSION_DEFAULT（例如 2023-06-01）这一已验证可用的版本。
    # 如需升级 RE2，请手动在 config.sh 中调整 RE2_VERSION_DEFAULT，并自行验证兼容性。
    local libraries=(
        "openssl:OPENSSL_VERSION"
        "zlib:ZLIB_VERSION"
        "sqlite:SQLITE_VERSION"
        "icu:ICU_VERSION"
        "protobuf:PROTOBUF_VERSION"
        "libphonenumber:LIBPHONENUMBER_VERSION"
        "crc32c:CRC32C_VERSION"
        "xxhash:XXHASH_VERSION"
        "abseil:ABSEIL_VERSION"
        "libevent:LIBEVENT_VERSION"
        "lz4:LZ4_VERSION"
        "snappy:SNAPPY_VERSION"
        "double-conversion:DOUBLE_CONVERSION_VERSION"
        "tdlib:TDLIB_VERSION"
    )
    
    local updated=0
    local failed=0
    
    for lib_info in "${libraries[@]}"; do
        IFS=':' read -r lib_name var_name <<< "$lib_info"
        
        log_info "检查 $lib_name 最新版本..."
        local latest_version=$(get_latest_version "$lib_name" 2>/dev/null)
        
        if [[ -n "$latest_version" ]]; then
            export "$var_name"="$latest_version"
            log_success "$lib_name: $latest_version"
            updated=$((updated + 1))
        else
            log_warning "$lib_name: 无法获取最新版本，使用默认版本"
            failed=$((failed + 1))
        fi
    done
    
    if [[ $updated -gt 0 ]]; then
        log_success "已更新 $updated 个库到最新版本"
    fi
    
    if [[ $failed -gt 0 ]]; then
        log_warning "$failed 个库使用默认版本"
    fi
    
    return 0
}

# ============================================
# 下载URL配置
# ============================================
get_download_url() {
    local lib=$1
    local version=$2
    
    case $lib in
        openssl)
            echo "https://www.openssl.org/source/openssl-${version}.tar.gz"
            ;;
        zlib)
            echo "https://zlib.net/zlib-${version}.tar.gz"
            ;;
        sqlite)
            local year=$(echo $version | cut -c1-4)
            local month=$(echo $version | cut -c5-6 | sed 's/^0//')
            echo "https://sqlite.org/${year}/sqlite-autoconf-${version}.tar.gz"
            ;;
        icu)
            local version_underscore=$(echo $version | tr '.' '_')
            echo "https://github.com/unicode-org/icu/releases/download/release-${version//./-}/icu4c-${version_underscore}-src.tgz"
            ;;
        protobuf)
            echo "https://github.com/protocolbuffers/protobuf/releases/download/v${version}/protobuf-cpp-${version}.tar.gz"
            ;;
        libphonenumber)
            echo "https://github.com/google/libphonenumber/archive/refs/tags/v${version}.tar.gz"
            ;;
        crc32c)
            echo "https://github.com/google/crc32c/archive/refs/tags/${version}.tar.gz"
            ;;
        xxhash)
            echo "https://github.com/Cyan4973/xxHash/archive/refs/tags/v${version}.tar.gz"
            ;;
        abseil)
            # Abseil 使用 LTS 版本标签格式：lts-20240116.2
            local lts_version="lts-${version}"
            echo "https://github.com/abseil/abseil-cpp/archive/refs/tags/${lts_version}.tar.gz"
            ;;
        re2)
            echo "https://github.com/google/re2/archive/refs/tags/${version}.tar.gz"
            ;;
        libevent)
            echo "https://github.com/libevent/libevent/releases/download/release-${version}/libevent-${version}-stable.tar.gz"
            ;;
        lz4)
            echo "https://github.com/lz4/lz4/archive/refs/tags/v${version}.tar.gz"
            ;;
        snappy)
            echo "https://github.com/google/snappy/archive/refs/tags/${version}.tar.gz"
            ;;
        double-conversion)
            echo "https://github.com/google/double-conversion/archive/refs/tags/v${version}.tar.gz"
            ;;
        tdlib)
            echo "https://github.com/tdlib/td/archive/refs/tags/v${version}.tar.gz"
            ;;
        *)
            echo "❌ 未知的库: $lib" >&2
            return 1
            ;;
    esac
}

# ============================================
# 工具链设置函数
# ============================================
set_toolchain() {
    local arch=$1
    
    # 检查 NDK 是否存在
    if [[ ! -d "$OHOS_NDK" ]]; then
        echo "❌ HarmonyOS NDK 未找到: $OHOS_NDK" >&2
        echo "请设置正确的 OHOS_NDK 环境变量" >&2
        echo "或者运行: ./setup_env.sh" >&2
        return 1
    fi
    
    # 检查工具链目录
    if [[ ! -d "$TOOLCHAIN_DIR" ]]; then
        echo "❌ 工具链目录不存在: $TOOLCHAIN_DIR" >&2
        echo "请检查 HarmonyOS NDK 安装" >&2
        return 1
    fi
    
    # 根据架构设置工具链
    # 参考华为开发者文档：https://developer.huawei.com/consumer/cn/blog/topic/03203338118552006
    case $arch in
        arm64-v8a)
            export TARGET_HOST="aarch64-linux-ohos"
            export TOOLCHAIN="aarch64-linux-ohos"
            
            # 在 Windows 上，优先使用 clang.exe（通过 -target 指定目标）
            # 在 Linux/macOS 上，优先使用目标前缀的编译器
            local is_windows=false
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
                is_windows=true
            fi
            
            if [[ "$is_windows" == "true" ]]; then
                # Windows: 优先使用 clang.exe/clang++.exe
                local cc_paths=(
                    "${TOOLCHAIN_DIR}/bin/clang.exe"
                    "${TOOLCHAIN_DIR}/bin/clang"
                    "${TOOLCHAIN_DIR}/bin/aarch64-unknown-linux-ohos-clang.exe"
                    "${TOOLCHAIN_DIR}/bin/aarch64-unknown-linux-ohos-clang"
                )
                local cxx_paths=(
                    "${TOOLCHAIN_DIR}/bin/clang++.exe"
                    "${TOOLCHAIN_DIR}/bin/clang++"
                    "${TOOLCHAIN_DIR}/bin/aarch64-unknown-linux-ohos-clang++.exe"
                    "${TOOLCHAIN_DIR}/bin/aarch64-unknown-linux-ohos-clang++"
                )
            else
                # Linux/macOS: 优先使用目标前缀的编译器
                local cc_paths=(
                    "${TOOLCHAIN_DIR}/bin/aarch64-unknown-linux-ohos-clang"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}-clang"
                    "${TOOLCHAIN_DIR}/bin/clang"
                )
                local cxx_paths=(
                    "${TOOLCHAIN_DIR}/bin/aarch64-unknown-linux-ohos-clang++"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang++"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}-clang++"
                    "${TOOLCHAIN_DIR}/bin/clang++"
                )
            fi
            
            # 查找存在的编译器
            local cc_path=""
            local cxx_path=""
            for path in "${cc_paths[@]}"; do
                if [[ -f "$path" ]]; then
                    cc_path="$path"
                    break
                fi
            done
            for path in "${cxx_paths[@]}"; do
                if [[ -f "$path" ]]; then
                    cxx_path="$path"
                    break
                fi
            done
            
            # 如果都没找到，使用第一个作为默认值
            if [[ -z "$cc_path" ]]; then
                cc_path="${cc_paths[0]}"
            fi
            if [[ -z "$cxx_path" ]]; then
                cxx_path="${cxx_paths[0]}"
            fi

            # 注意：为兼容 CMake / Autotools，两者都更偏好 CC/CXX 为“纯可执行文件路径”
            # 目标三元组统一通过 CFLAGS/CXXFLAGS/LDFLAGS 的 -target 传递
            export CC="$cc_path"
            export CXX="$cxx_path"
            # 工具路径（支持 Windows .exe）
            local ar_path="${TOOLCHAIN_DIR}/bin/llvm-ar"
            local ranlib_path="${TOOLCHAIN_DIR}/bin/llvm-ranlib"
            local strip_path="${TOOLCHAIN_DIR}/bin/llvm-strip"
            local readelf_path="${TOOLCHAIN_DIR}/bin/llvm-readelf"
            local ld_path="${TOOLCHAIN_DIR}/bin/ld.lld"
            
            # 检查并添加 .exe 扩展名（如果需要）
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
                [[ ! -f "$ar_path" ]] && [[ -f "${ar_path}.exe" ]] && ar_path="${ar_path}.exe"
                [[ ! -f "$ranlib_path" ]] && [[ -f "${ranlib_path}.exe" ]] && ranlib_path="${ranlib_path}.exe"
                [[ ! -f "$strip_path" ]] && [[ -f "${strip_path}.exe" ]] && strip_path="${strip_path}.exe"
                [[ ! -f "$readelf_path" ]] && [[ -f "${readelf_path}.exe" ]] && readelf_path="${readelf_path}.exe"
                [[ ! -f "$ld_path" ]] && [[ -f "${ld_path}.exe" ]] && ld_path="${ld_path}.exe"
            fi
            
            export AR="$ar_path"
            export RANLIB="$ranlib_path"
            export STRIP="$strip_path"
            export READELF="$readelf_path"
            export LD="$ld_path"
            
            # 编译标志（根据华为文档：-fPIC -D__MUSL__=1）
            export CFLAGS="-target ${TARGET_HOST} -fPIC -D__MUSL__=1 -march=armv8-a+crc+crypto -mtune=cortex-a75"
            export CXXFLAGS="${CFLAGS} -stdlib=libc++"
            export LDFLAGS="-target ${TARGET_HOST} -lc++ -lc++abi -fuse-ld=lld"
            ;;
            
        armeabi-v7a)
            export TARGET_HOST="arm-linux-ohos"
            export TOOLCHAIN="arm-linux-ohos"
            
            # 在 Windows 上，优先使用 clang.exe（通过 -target 指定目标）
            # 在 Linux/macOS 上，优先使用目标前缀的编译器
            local is_windows=false
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
                is_windows=true
            fi
            
            if [[ "$is_windows" == "true" ]]; then
                # Windows: 优先使用 clang.exe/clang++.exe
                local cc_paths=(
                    "${TOOLCHAIN_DIR}/bin/clang.exe"
                    "${TOOLCHAIN_DIR}/bin/clang"
                    "${TOOLCHAIN_DIR}/bin/arm-unknown-linux-ohos-clang.exe"
                    "${TOOLCHAIN_DIR}/bin/arm-unknown-linux-ohos-clang"
                )
                local cxx_paths=(
                    "${TOOLCHAIN_DIR}/bin/clang++.exe"
                    "${TOOLCHAIN_DIR}/bin/clang++"
                    "${TOOLCHAIN_DIR}/bin/arm-unknown-linux-ohos-clang++.exe"
                    "${TOOLCHAIN_DIR}/bin/arm-unknown-linux-ohos-clang++"
                )
            else
                # Linux/macOS: 优先使用目标前缀的编译器
                local cc_paths=(
                    "${TOOLCHAIN_DIR}/bin/arm-unknown-linux-ohos-clang"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}-clang"
                    "${TOOLCHAIN_DIR}/bin/clang"
                )
                local cxx_paths=(
                    "${TOOLCHAIN_DIR}/bin/arm-unknown-linux-ohos-clang++"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang++"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}-clang++"
                    "${TOOLCHAIN_DIR}/bin/clang++"
                )
            fi
            
            # 查找存在的编译器
            local cc_path=""
            local cxx_path=""
            for path in "${cc_paths[@]}"; do
                if [[ -f "$path" ]]; then
                    cc_path="$path"
                    break
                fi
            done
            for path in "${cxx_paths[@]}"; do
                if [[ -f "$path" ]]; then
                    cxx_path="$path"
                    break
                fi
            done
            
            # 如果都没找到，使用第一个作为默认值
            if [[ -z "$cc_path" ]]; then
                cc_path="${cc_paths[0]}"
            fi
            if [[ -z "$cxx_path" ]]; then
                cxx_path="${cxx_paths[0]}"
            fi

            export CC="$cc_path"
            export CXX="$cxx_path"
            # 工具路径（支持 Windows .exe）
            local ar_path="${TOOLCHAIN_DIR}/bin/llvm-ar"
            local ranlib_path="${TOOLCHAIN_DIR}/bin/llvm-ranlib"
            local strip_path="${TOOLCHAIN_DIR}/bin/llvm-strip"
            local readelf_path="${TOOLCHAIN_DIR}/bin/llvm-readelf"
            local ld_path="${TOOLCHAIN_DIR}/bin/ld.lld"
            
            # 检查并添加 .exe 扩展名（如果需要）
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
                [[ ! -f "$ar_path" ]] && [[ -f "${ar_path}.exe" ]] && ar_path="${ar_path}.exe"
                [[ ! -f "$ranlib_path" ]] && [[ -f "${ranlib_path}.exe" ]] && ranlib_path="${ranlib_path}.exe"
                [[ ! -f "$strip_path" ]] && [[ -f "${strip_path}.exe" ]] && strip_path="${strip_path}.exe"
                [[ ! -f "$readelf_path" ]] && [[ -f "${readelf_path}.exe" ]] && readelf_path="${readelf_path}.exe"
                [[ ! -f "$ld_path" ]] && [[ -f "${ld_path}.exe" ]] && ld_path="${ld_path}.exe"
            fi
            
            export AR="$ar_path"
            export RANLIB="$ranlib_path"
            export STRIP="$strip_path"
            export READELF="$readelf_path"
            export LD="$ld_path"
            
            # 编译标志（根据华为文档：-fPIC -D__MUSL__=1，32bit需要增加配置 -march=armv7a）
            export CFLAGS="-target ${TARGET_HOST} -fPIC -D__MUSL__=1 -march=armv7-a -mfpu=neon -mfloat-abi=hard"
            export CXXFLAGS="${CFLAGS} -stdlib=libc++"
            # 注意：不在全局 LDFLAGS 中添加 -latomic，因为 HarmonyOS NDK 可能没有 libatomic
            # 现代编译器（clang）通常内置支持原子操作，不需要单独的 libatomic 库
            # 如果特定库（如 OpenSSL）需要 libatomic，会在其构建脚本中单独处理
            export LDFLAGS="-target ${TARGET_HOST} -lc++ -lc++abi -fuse-ld=lld"
            ;;
            
        x86_64)
            export TARGET_HOST="x86_64-linux-ohos"
            export TOOLCHAIN="x86_64-linux-ohos"
            
            # 在 Windows 上，优先使用 clang.exe（通过 -target 指定目标）
            # 在 Linux/macOS 上，优先使用目标前缀的编译器
            local is_windows=false
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
                is_windows=true
            fi
            
            if [[ "$is_windows" == "true" ]]; then
                # Windows: 优先使用 clang.exe/clang++.exe
                local cc_paths=(
                    "${TOOLCHAIN_DIR}/bin/clang.exe"
                    "${TOOLCHAIN_DIR}/bin/clang"
                    "${TOOLCHAIN_DIR}/bin/x86_64-unknown-linux-ohos-clang.exe"
                    "${TOOLCHAIN_DIR}/bin/x86_64-unknown-linux-ohos-clang"
                )
                local cxx_paths=(
                    "${TOOLCHAIN_DIR}/bin/clang++.exe"
                    "${TOOLCHAIN_DIR}/bin/clang++"
                    "${TOOLCHAIN_DIR}/bin/x86_64-unknown-linux-ohos-clang++.exe"
                    "${TOOLCHAIN_DIR}/bin/x86_64-unknown-linux-ohos-clang++"
                )
            else
                # Linux/macOS: 优先使用目标前缀的编译器
                local cc_paths=(
                    "${TOOLCHAIN_DIR}/bin/x86_64-unknown-linux-ohos-clang"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}-clang"
                    "${TOOLCHAIN_DIR}/bin/clang"
                )
                local cxx_paths=(
                    "${TOOLCHAIN_DIR}/bin/x86_64-unknown-linux-ohos-clang++"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang++"
                    "${TOOLCHAIN_DIR}/bin/${TARGET_HOST}-clang++"
                    "${TOOLCHAIN_DIR}/bin/clang++"
                )
            fi
            
            # 查找存在的编译器
            local cc_path=""
            local cxx_path=""
            for path in "${cc_paths[@]}"; do
                if [[ -f "$path" ]]; then
                    cc_path="$path"
                    break
                fi
            done
            for path in "${cxx_paths[@]}"; do
                if [[ -f "$path" ]]; then
                    cxx_path="$path"
                    break
                fi
            done
            
            # 如果都没找到，使用第一个作为默认值
            if [[ -z "$cc_path" ]]; then
                cc_path="${cc_paths[0]}"
            fi
            if [[ -z "$cxx_path" ]]; then
                cxx_path="${cxx_paths[0]}"
            fi

            export CC="$cc_path"
            export CXX="$cxx_path"
            # 工具路径（支持 Windows .exe）
            local ar_path="${TOOLCHAIN_DIR}/bin/llvm-ar"
            local ranlib_path="${TOOLCHAIN_DIR}/bin/llvm-ranlib"
            local strip_path="${TOOLCHAIN_DIR}/bin/llvm-strip"
            local readelf_path="${TOOLCHAIN_DIR}/bin/llvm-readelf"
            local ld_path="${TOOLCHAIN_DIR}/bin/ld.lld"
            
            # 检查并添加 .exe 扩展名（如果需要）
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
                [[ ! -f "$ar_path" ]] && [[ -f "${ar_path}.exe" ]] && ar_path="${ar_path}.exe"
                [[ ! -f "$ranlib_path" ]] && [[ -f "${ranlib_path}.exe" ]] && ranlib_path="${ranlib_path}.exe"
                [[ ! -f "$strip_path" ]] && [[ -f "${strip_path}.exe" ]] && strip_path="${strip_path}.exe"
                [[ ! -f "$readelf_path" ]] && [[ -f "${readelf_path}.exe" ]] && readelf_path="${readelf_path}.exe"
                [[ ! -f "$ld_path" ]] && [[ -f "${ld_path}.exe" ]] && ld_path="${ld_path}.exe"
            fi
            
            export AR="$ar_path"
            export RANLIB="$ranlib_path"
            export STRIP="$strip_path"
            export READELF="$readelf_path"
            export LD="$ld_path"
            
            # 编译标志（根据华为文档：-fPIC -D__MUSL__=1）
            export CFLAGS="-target ${TARGET_HOST} -fPIC -D__MUSL__=1 -march=x86-64 -msse4.2"
            export CXXFLAGS="${CFLAGS} -stdlib=libc++"
            export LDFLAGS="-target ${TARGET_HOST} -lc++ -lc++abi -fuse-ld=lld"
            ;;
            
        *)
            echo "❌ 不支持的架构: $arch" >&2
            return 1
            ;;
    esac
    
    # 通用标志（根据华为文档，-D__MUSL__=1 已在架构特定标志中设置）
    # 避免重复添加 -D__MUSL__=1
    if [[ "$CFLAGS" != *"-D__MUSL__=1"* ]]; then
        export CFLAGS="${CFLAGS} -D__MUSL__=1"
    fi
    export CFLAGS="${CFLAGS} -D__OHOS__ -DNDEBUG -O3 -I${SYSROOT}/usr/include"
    export CXXFLAGS="${CXXFLAGS} -D__OHOS__ -DNDEBUG -O3 -I${SYSROOT}/usr/include"
    export LDFLAGS="${LDFLAGS} -L${SYSROOT}/usr/lib --sysroot=${SYSROOT}"
    
    # 构建和安装目录（使用绝对路径，避免 CMake 等工具因路径不一致报错）
    export ARCH_BUILD_DIR=$(to_absolute_path "${BUILD_DIR}/${arch}" "$PROJECT_ROOT")
    export ARCH_INSTALL_DIR=$(to_absolute_path "${INSTALL_DIR}/${arch}" "$PROJECT_ROOT")
    
    mkdir -p "${ARCH_BUILD_DIR}"
    mkdir -p "${ARCH_INSTALL_DIR}"
    
    # 验证编译器（支持 Windows .exe 扩展名）
    local cc_exists=false
    if [[ -f "$CC" ]]; then
        cc_exists=true
    elif [[ -f "${CC}.exe" ]]; then
        export CC="${CC}.exe"
        export CXX="${CXX}.exe"
        cc_exists=true
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
        # Windows 环境，尝试添加 .exe
        if [[ -f "${CC}.exe" ]]; then
            export CC="${CC}.exe"
            export CXX="${CXX}.exe"
            cc_exists=true
        fi
    fi
    
    if [[ "$cc_exists" == false ]]; then
        echo "❌ 编译器不存在: $CC" >&2
        echo "   尝试的路径:" >&2
        echo "     - $CC" >&2
        echo "     - ${CC}.exe" >&2
        echo "请检查 HarmonyOS NDK 安装" >&2
        return 1
    fi
    
    return 0
}

# ============================================
# 配置验证函数
# ============================================
validate_config() {
    local errors=0
    local warnings=0
    
    echo ""
    echo "🔍 验证配置..."
    echo ""
    
    # 规范化 Windows 路径（将反斜杠转换为正斜杠）
    if [[ -n "$OHOS_NDK" ]]; then
        OHOS_NDK=$(normalize_path "$OHOS_NDK")
        export OHOS_NDK
    fi
    
    # 检查 NDK 路径
    if [[ -z "$OHOS_NDK" ]]; then
        echo "❌ 错误: OHOS_NDK 未设置"
        echo "   请在 user_config.sh 中设置 OHOS_NDK 路径"
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
            echo "   Windows 示例: export OHOS_NDK=\"C:/Users/YourName/AppData/Local/OpenHarmony/Sdk/20/native\""
        else
            echo "   示例: export OHOS_NDK=\"/path/to/harmony/ndk\""
        fi
        errors=$((errors + 1))
    else
        # 规范化路径后再次检查
        local normalized_path=$(normalize_path "$OHOS_NDK")
        if [[ "$normalized_path" != "$OHOS_NDK" ]]; then
            OHOS_NDK="$normalized_path"
            export OHOS_NDK
        fi
        
        if [[ ! -d "$OHOS_NDK" ]]; then
            echo "⚠️  警告: OHOS_NDK 路径不存在: $OHOS_NDK"
            echo "   请检查路径是否正确"
            # 在 Windows 环境下，提供路径格式建议
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
                echo ""
                echo "   Windows 路径格式建议（推荐使用正斜杠）:"
                echo "   export OHOS_NDK=\"C:/Users/YourName/AppData/Local/OpenHarmony/Sdk/20/native\""
                echo ""
                echo "   如果使用反斜杠，需要转义:"
                echo "   export OHOS_NDK=\"C:\\\\Users\\\\YourName\\\\AppData\\\\Local\\\\OpenHarmony\\\\Sdk\\\\20\\\\native\""
                echo ""
                echo "   当前路径（规范化后）: $OHOS_NDK"
            else
                echo "   路径格式示例:"
                echo "   export OHOS_NDK=\"/path/to/harmony/ndk\""
            fi
            warnings=$((warnings + 1))
        else
            echo "✅ OHOS_NDK: $OHOS_NDK"
        fi
    fi
    
    # 检查工具链文件
    if [[ -n "$OHOS_NDK" ]] && [[ -d "$OHOS_NDK" ]]; then
        # 使用 get_toolchain_file 函数查找工具链文件
        if command -v get_toolchain_file &> /dev/null; then
            local toolchain_file=$(get_toolchain_file "$OHOS_NDK")
        else
            # 回退到直接检查
            local ndk_path=$(echo "$OHOS_NDK" | sed 's|\\|/|g')
            local toolchain_file=""
            
            if [[ "$ndk_path" == *"/native" ]] || [[ "$ndk_path" == *"\\native" ]]; then
                toolchain_file="${ndk_path}/build/cmake/ohos.toolchain.cmake"
            else
                toolchain_file="${ndk_path}/native/build/cmake/ohos.toolchain.cmake"
            fi
            
            if [[ ! -f "$toolchain_file" ]]; then
                toolchain_file="${ndk_path}/build/cmake/ohos.toolchain.cmake"
            fi
        fi
        
        if [[ -n "$toolchain_file" ]] && [[ -f "$toolchain_file" ]]; then
            echo "✅ 工具链文件: $toolchain_file"
            export OHOS_TOOLCHAIN_FILE="$toolchain_file"
        else
            echo "⚠️  警告: 工具链文件未找到"
            echo "   尝试的路径:"
            local ndk_path=$(echo "$OHOS_NDK" | sed 's|\\|/|g')
            echo "     - ${ndk_path}/build/cmake/ohos.toolchain.cmake"
            echo "     - ${ndk_path}/native/build/cmake/ohos.toolchain.cmake"
            warnings=$((warnings + 1))
        fi
        
        # 检查编译器（支持 Windows .exe 扩展名和通用 clang）
        if [[ -d "$TOOLCHAIN_DIR" ]]; then
            local compiler_found=false
            local compiler_paths=(
                "${TOOLCHAIN_DIR}/bin/aarch64-linux-ohos${OHOS_API_LEVEL}-clang"
                "${TOOLCHAIN_DIR}/bin/clang"
                "${TOOLCHAIN_DIR}/bin/clang.exe"
            )
            
            for compiler in "${compiler_paths[@]}"; do
                # 转换 Windows 路径格式
                compiler=$(echo "$compiler" | sed 's|\\|/|g')
                
                if [[ -f "$compiler" ]]; then
                    echo "✅ 编译器: 找到 ($compiler)"
                    compiler_found=true
                    break
                elif [[ -f "${compiler}.exe" ]]; then
                    echo "✅ 编译器: 找到 (${compiler}.exe)"
                    compiler_found=true
                    break
                fi
            done
            
            if [[ "$compiler_found" == false ]]; then
                echo "⚠️  警告: 编译器未找到"
                echo "   尝试的路径:"
                for compiler in "${compiler_paths[@]}"; do
                    compiler=$(echo "$compiler" | sed 's|\\|/|g')
                    echo "     - $compiler"
                    echo "     - ${compiler}.exe"
                done
                warnings=$((warnings + 1))
            fi
        fi
    fi
    
    # 检查 API 级别
    if [[ -z "$OHOS_API_LEVEL" ]] || ! [[ "$OHOS_API_LEVEL" =~ ^[0-9]+$ ]]; then
        echo "❌ 错误: OHOS_API_LEVEL 无效: $OHOS_API_LEVEL"
        echo "   请设置为有效的数字（如 9, 10, 11）"
        errors=$((errors + 1))
    else
        echo "✅ OHOS_API_LEVEL: $OHOS_API_LEVEL"
    fi
    
    # 检查并行任务数
    if [[ -z "$PARALLEL_JOBS" ]] || ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ "$PARALLEL_JOBS" -lt 1 ]]; then
        echo "⚠️  警告: PARALLEL_JOBS 无效，使用默认值 4"
        export PARALLEL_JOBS=4
        warnings=$((warnings + 1))
    else
        echo "✅ PARALLEL_JOBS: $PARALLEL_JOBS"
    fi
    
    # 检查架构配置
    if [[ ${#ARCHITECTURES[@]} -eq 0 ]]; then
        echo "⚠️  警告: 未配置目标架构，使用默认值"
        export ARCHITECTURES=("arm64-v8a")
        warnings=$((warnings + 1))
    else
        echo "✅ 目标架构: ${ARCHITECTURES[*]}"
    fi
    
    # 检查构建模式
    if [[ -z "$BUILD_MODE" ]]; then
        echo "⚠️  警告: BUILD_MODE 未设置，使用默认值 Release"
        export BUILD_MODE="Release"
        warnings=$((warnings + 1))
    else
        echo "✅ BUILD_MODE: $BUILD_MODE"
    fi
    
    echo ""
    if [[ $errors -gt 0 ]]; then
        echo "❌ 配置验证失败: 发现 $errors 个错误"
        return 1
    elif [[ $warnings -gt 0 ]]; then
        echo "⚠️  配置验证完成: 发现 $warnings 个警告"
        return 0
    else
        echo "✅ 配置验证通过"
        return 0
    fi
}

# ============================================
# 环境检查函数
# ============================================
check_environment() {
    local arch=$1
    
    # 检查必要工具
    local required_tools=("wget" "tar" "cmake" "make")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "❌ 缺少必要工具: $tool" >&2
            return 1
        fi
    done
    
    # 检查HarmonyOS NDK
    if [[ ! -d "$OHOS_NDK" ]]; then
        echo "❌ HarmonyOS NDK未找到: $OHOS_NDK" >&2
        return 1
    fi
    
    # 检查工具链文件
    local toolchain_file=""
    if command -v get_toolchain_file &> /dev/null; then
        toolchain_file=$(get_toolchain_file "$OHOS_NDK")
    else
        local ndk_path=$(echo "$OHOS_NDK" | sed 's|\\|/|g')
        if [[ "$ndk_path" == *"/native" ]] || [[ "$ndk_path" == *"\\native" ]]; then
            toolchain_file="${ndk_path}/build/cmake/ohos.toolchain.cmake"
        else
            toolchain_file="${ndk_path}/native/build/cmake/ohos.toolchain.cmake"
        fi
        
        if [[ ! -f "$toolchain_file" ]]; then
            toolchain_file="${ndk_path}/build/cmake/ohos.toolchain.cmake"
        fi
    fi
    
    if [[ -z "$toolchain_file" ]] || [[ ! -f "$toolchain_file" ]]; then
        echo "⚠️  工具链文件未找到，某些CMake构建可能失败" >&2
        echo "   请检查路径: $OHOS_NDK" >&2
    else
        export OHOS_TOOLCHAIN_FILE="$toolchain_file"
    fi
    
    return 0
}
