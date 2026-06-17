#!/bin/bash
# 通用函数和变量定义
# 用于所有构建脚本的公共功能

# 使用绝对路径加载工具链文件查找函数
COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [[ -n "$COMMON_SCRIPT_DIR" ]] && [[ -f "${COMMON_SCRIPT_DIR}/get_toolchain_file.sh" ]]; then
    source "${COMMON_SCRIPT_DIR}/get_toolchain_file.sh"
fi

# 获取工具链文件路径的辅助函数（如果 get_toolchain_file.sh 未加载）
if ! command -v get_toolchain_file &> /dev/null; then
    get_toolchain_file() {
        local ndk_path="${1:-$OHOS_NDK}"
        
        if [[ -z "$ndk_path" ]] || [[ ! -d "$ndk_path" ]]; then
            return 1
        fi
        
        # 转换 Windows 路径格式（统一使用正斜杠）
        ndk_path=$(echo "$ndk_path" | sed 's|\\|/|g')
        
        # 尝试多种可能的工具链文件路径
        local toolchain_files=(
            "${ndk_path}/build/cmake/ohos.toolchain.cmake"  # OpenHarmony SDK 结构（如果 NDK 指向 native 目录）
            "${ndk_path}/native/build/cmake/ohos.toolchain.cmake"  # 标准结构（如果 NDK 指向 SDK 根目录）
        )
        
        # 如果 NDK 路径包含 "native"，优先尝试直接使用 build/cmake 路径
        if [[ "$ndk_path" == *"/native" ]] || [[ "$ndk_path" == *"\\native" ]]; then
            toolchain_files=(
                "${ndk_path}/build/cmake/ohos.toolchain.cmake"
                "${toolchain_files[@]}"
            )
        fi
        
        # 查找存在的工具链文件
        for toolchain_file in "${toolchain_files[@]}"; do
            toolchain_file=$(echo "$toolchain_file" | sed 's|\\|/|g')
            if [[ -f "$toolchain_file" ]]; then
                echo "$toolchain_file"
                return 0
            fi
        done
        
        return 1
    }
fi

# ============================================
# 颜色定义
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================
# 日志函数
# ============================================
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_step() {
    echo -e "${CYAN}▶${NC} ${BOLD}$1${NC}"
}

# ============================================
# 工具函数
# ============================================

# 清理 CMake 缓存（统一函数，避免重复代码）
clean_cmake_cache() {
    local build_dir="${1:-.}"
    
    if [[ ! -d "$build_dir" ]]; then
        return 0
    fi
    
    log_info "清理 CMake 缓存: $build_dir"
    cd "$build_dir" || return 1
    
    # 清理 CMake 缓存文件
    rm -rf CMakeCache.txt CMakeFiles/ 2>/dev/null || true
    
    # 清理 Ninja 构建文件（如果使用 Ninja）
    rm -f build.ninja .ninja_deps .ninja_log *.ninja 2>/dev/null || true
    
    return 0
}

# 清理构建目录（统一函数）
clean_build_directory() {
    local build_dir="$1"
    local force="${2:-false}"
    
    if [[ -z "$build_dir" ]] || [[ ! -d "$build_dir" ]]; then
        return 0
    fi
    
    if [[ "$force" == "true" ]]; then
        log_info "完全清理构建目录: $build_dir"
        rm -rf "$build_dir"/* 2>/dev/null || true
    else
        # 只清理 CMake 缓存，保留其他文件
        clean_cmake_cache "$build_dir"
    fi
    
    return 0
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令不存在: $1"
        return 1
    fi
    return 0
}

# 检查文件或目录是否存在
check_path() {
    if [[ ! -e "$1" ]]; then
        log_error "路径不存在: $1"
        return 1
    fi
    return 0
}

# 创建目录（如果不存在）
ensure_dir() {
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1"
        log_info "创建目录: $1" >&2
    fi
}

# ============================================
# 解压函数
# ============================================
extract_file() {
    local file=$1
    local dest=$2
    
    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    log_info "解压: $(basename "$file")"
    
    # 确保目标目录存在
    mkdir -p "$dest" 2>/dev/null || true
    
    # 检测文件类型
    local ext="${file##*.}"
    local filename=$(basename "$file")
    local result=1
    
    # 根据扩展名和文件名判断压缩格式
    if [[ "$filename" == *.tar.gz ]] || [[ "$filename" == *.tgz ]]; then
        # tar.gz 或 tgz 文件
        log_info "使用 tar 解压 tar.gz/tgz 文件..."
        if ! command -v tar &> /dev/null; then
            log_error "tar 命令不可用"
            return 1
        fi
        
        # 尝试解压（捕获错误信息）
        local tar_output
        # 使用 --no-same-owner 和 --no-same-permissions 来避免 Windows 权限问题
        # 对于符号链接错误，我们会在后面特殊处理
        tar_output=$(tar -xzf "$file" -C "$dest" --no-same-owner --no-same-permissions 2>&1)
        result=$?
        
        # 检查是否只是符号链接错误（Windows/Git Bash 常见问题）
        local symlink_error=false
        if echo "$tar_output" | grep -qi "Cannot create symlink\|symlink.*No such file"; then
            symlink_error=true
            log_warning "检测到符号链接错误（Windows 环境常见问题）"
            log_info "符号链接错误信息:"
            echo "$tar_output" | grep -i "symlink\|Cannot create" | head -5
            
            # 检查文件是否实际已解压（即使有符号链接错误）
            # 如果解压目录中有内容，说明解压基本成功
            if [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
                log_info "文件已解压（忽略符号链接错误）"
                result=0
            fi
        fi
        
        if [[ $result -ne 0 ]] && [[ "$symlink_error" == false ]]; then
            # 如果失败且不是符号链接错误，显示错误信息
            log_warning "tar 解压失败，错误信息:"
            echo "$tar_output" | head -10
            
            # 尝试备用方法：先切换到目标目录
            log_info "尝试备用解压方法..."
            local old_pwd=$(pwd)
            if cd "$dest" 2>/dev/null; then
                tar_output=$(tar -xzf "$file" --no-same-owner --no-same-permissions 2>&1)
                result=$?
                cd "$old_pwd" 2>/dev/null || true
                
                # 再次检查符号链接错误
                if [[ $result -ne 0 ]] && echo "$tar_output" | grep -qi "Cannot create symlink\|symlink.*No such file"; then
                    if [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
                        log_info "文件已解压（忽略符号链接错误）"
                        result=0
                    fi
                elif [[ $result -ne 0 ]]; then
                    log_warning "备用方法也失败:"
                    echo "$tar_output" | head -10
                fi
            fi
            
            # 如果还是失败，尝试使用绝对路径
            if [[ $result -ne 0 ]]; then
                log_info "尝试使用绝对路径..."
                local abs_file=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
                local abs_dest=$(cd "$dest" && pwd 2>/dev/null || echo "$dest")
                tar_output=$(tar -xzf "$abs_file" -C "$abs_dest" --no-same-owner --no-same-permissions 2>&1)
                result=$?
                
                # 再次检查符号链接错误
                if [[ $result -ne 0 ]] && echo "$tar_output" | grep -qi "Cannot create symlink\|symlink.*No such file"; then
                    if [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
                        log_info "文件已解压（忽略符号链接错误）"
                        result=0
                    fi
                fi
            fi
        fi
    elif [[ "$ext" == "gz" ]]; then
        # 纯 gzip 文件
        log_info "使用 gunzip 解压..."
        gunzip -c "$file" > "$dest/$(basename "$file" .gz)" 2>&1
        result=$?
    elif [[ "$filename" == *.tar.bz2 ]] || [[ "$ext" == "bz2" ]]; then
        # tar.bz2 文件
        log_info "使用 tar 解压 tar.bz2 文件..."
        local tar_output
        tar_output=$(tar -xjf "$file" -C "$dest" --no-same-owner --no-same-permissions 2>&1)
        result=$?
        # 检查符号链接错误
        if [[ $result -ne 0 ]] && echo "$tar_output" | grep -qi "Cannot create symlink\|symlink.*No such file"; then
            if [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
                log_info "文件已解压（忽略符号链接错误）"
                result=0
            fi
        fi
    elif [[ "$filename" == *.tar.xz ]] || [[ "$ext" == "xz" ]]; then
        # tar.xz 文件
        log_info "使用 tar 解压 tar.xz 文件..."
        local tar_output
        if tar --version 2>/dev/null | grep -q "GNU tar"; then
            tar_output=$(tar -xJf "$file" -C "$dest" --no-same-owner --no-same-permissions 2>&1)
        else
            # 某些系统可能需要 xz 工具
            if command -v xz &> /dev/null; then
                tar_output=$(xz -dc "$file" | tar -xf - -C "$dest" --no-same-owner --no-same-permissions 2>&1)
            else
                tar_output=$(tar -xJf "$file" -C "$dest" --no-same-owner --no-same-permissions 2>&1)
            fi
        fi
        result=$?
        # 检查符号链接错误
        if [[ $result -ne 0 ]] && echo "$tar_output" | grep -qi "Cannot create symlink\|symlink.*No such file"; then
            if [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
                log_info "文件已解压（忽略符号链接错误）"
                result=0
            fi
        fi
    elif [[ "$ext" == "zip" ]]; then
        # zip 文件
        log_info "使用 unzip 解压..."
        if command -v unzip &> /dev/null; then
            # -o 参数：覆盖已存在的文件，不提示
            unzip -o -q "$file" -d "$dest" 2>&1
            result=$?
        else
            log_error "unzip 命令不可用"
            return 1
        fi
    elif [[ "$ext" == "tar" ]]; then
        # 纯 tar 文件
        log_info "使用 tar 解压 tar 文件..."
        local tar_output
        tar_output=$(tar -xf "$file" -C "$dest" --no-same-owner --no-same-permissions 2>&1)
        result=$?
        # 检查符号链接错误
        if [[ $result -ne 0 ]] && echo "$tar_output" | grep -qi "Cannot create symlink\|symlink.*No such file"; then
            if [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
                log_info "文件已解压（忽略符号链接错误）"
                result=0
            fi
        fi
    else
        log_error "不支持的压缩格式: $ext (文件: $filename)"
        return 1
    fi
    
    if [[ $result -eq 0 ]]; then
        log_success "解压成功: $(basename "$file")"
        return 0
    else
        log_error "解压失败: $file (退出码: $result)"
        log_info "尝试手动解压: tar -xzf \"$file\" -C \"$dest\""
        return 1
    fi
}

# ============================================
# 补丁应用函数
# ============================================
apply_patch() {
    local patch_file=$1
    local target_dir=$2
    
    if [[ ! -f "$patch_file" ]]; then
        log_warning "补丁文件不存在: $patch_file"
        return 0
    fi
    
    if [[ ! -d "$target_dir" ]]; then
        log_error "目标目录不存在: $target_dir"
        return 1
    fi
    
    log_info "应用补丁: $(basename "$patch_file")"
    log_info "目标目录: $target_dir"
    
    cd "$target_dir" || return 1
    
    # 尝试不同的 patch level (p0, p1, p2)
    local patch_levels=(1 0 2)
    local patch_success=false
    
    for p_level in "${patch_levels[@]}"; do
        log_info "尝试 patch level -p${p_level}..."
        
        # 尝试应用补丁（捕获输出以便调试）
        local patch_output
        patch_output=$(patch -p${p_level} -i "$patch_file" --forward --dry-run 2>&1)
        local dry_run_result=$?
        
        if [[ $dry_run_result -eq 0 ]]; then
            # 干运行成功，实际应用补丁
            if patch -p${p_level} -i "$patch_file" --forward 2>&1; then
                log_success "补丁应用成功 (使用 -p${p_level})"
                patch_success=true
                break
            fi
        else
            # 检查是否已经应用过
            if patch -p${p_level} -i "$patch_file" --reverse --check --quiet 2>/dev/null; then
                log_info "补丁已经应用 (使用 -p${p_level})"
                patch_success=true
                break
            fi
        fi
    done
    
    if [[ "$patch_success" == false ]]; then
        log_warning "补丁应用失败，尝试了所有 patch level (-p0, -p1, -p2)"
        log_info "补丁文件内容预览:"
        head -20 "$patch_file" | sed 's/^/  /'
        
        # 检查是否有 .rej 文件
        local rej_files=$(find . -name "*.rej" -type f 2>/dev/null | head -5)
        if [[ -n "$rej_files" ]]; then
            log_warning "发现拒绝文件 (.rej):"
            echo "$rej_files" | sed 's/^/  /'
            log_info "可以查看 .rej 文件了解具体失败原因"
        fi
        
        # 清理 .rej 文件（可选，避免影响后续操作）
        # find . -name "*.rej" -type f -delete 2>/dev/null
        
        cd - > /dev/null || true
        return 1
    fi
    
    cd - > /dev/null || true
    return 0
}

# ============================================
# 执行命令并记录日志
# ============================================
run_command() {
    local cmd=$1
    local log_file=${2:-}
    local description=${3:-"执行命令"}
    
    log_info "$description"
    
    if [[ -n "$log_file" ]]; then
        ensure_dir "$(dirname "$log_file")"
        if eval "$cmd" >> "$log_file" 2>&1; then
            log_success "$description 完成"
            return 0
        else
            log_error "$description 失败，查看日志: $log_file"
            return 1
        fi
    else
        if eval "$cmd"; then
            log_success "$description 完成"
            return 0
        else
            log_error "$description 失败"
            return 1
        fi
    fi
}

# ============================================
# 验证库文件
# ============================================
verify_library() {
    local lib_name=$1
    local lib_path=$2
    
    if [[ ! -f "$lib_path" ]]; then
        log_error "库文件不存在: $lib_path"
        return 1
    fi
    
    # 检查静态库
    if [[ "$lib_path" == *.a ]]; then
        if ! "$AR" t "$lib_path" > /dev/null 2>&1; then
            log_error "无效的静态库: $lib_path"
            return 1
        fi
    fi
    
    # 检查动态库
    if [[ "$lib_path" == *.so ]]; then
        # 在 Windows 环境下，file 命令可能不可用或行为不同
        # 检测是否在 Windows 环境
        local is_windows=false
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
            is_windows=true
        fi
        
        # 在 Windows 环境下，放宽验证要求
        if [[ "$is_windows" == true ]]; then
            # 只检查文件是否存在且有一定大小
            local file_size=$(stat -f%z "$lib_path" 2>/dev/null || stat -c%s "$lib_path" 2>/dev/null || echo "0")
            if [[ "$file_size" -gt 0 ]]; then
                log_info "Windows 环境：动态库文件存在（大小: $file_size 字节），验证通过"
                # 在 Windows 环境下，不进行 ELF 格式检查
            else
                log_error "动态库文件为空或不存在: $lib_path"
                return 1
            fi
        else
            # 非 Windows 环境，进行完整的 ELF 格式验证
            local is_valid=false
            
            # 方法1: 使用 file 命令（如果可用）
            if command -v file &> /dev/null; then
                if file "$lib_path" 2>/dev/null | grep -q "ELF\|shared object\|dynamically linked"; then
                    is_valid=true
                fi
            fi
            
            # 方法2: 检查文件头 ELF 魔数
            if [[ "$is_valid" == false ]]; then
                # 读取文件前 4 字节检查 ELF 魔数 (7F 45 4C 46)
                if head -c 4 "$lib_path" 2>/dev/null | od -An -tx1 2>/dev/null | grep -q "7f 45 4c 46" || \
                   hexdump -n 4 -e '4/1 "%02x" "\n"' "$lib_path" 2>/dev/null | grep -q "^7f454c46" || \
                   (dd if="$lib_path" bs=4 count=1 2>/dev/null | od -An -tx1 | grep -q "7f 45 4c 46"); then
                    is_valid=true
                fi
            fi
            
            # 方法3: 检查文件大小（作为最后的验证）
            if [[ "$is_valid" == false ]]; then
                local file_size=$(stat -f%z "$lib_path" 2>/dev/null || stat -c%s "$lib_path" 2>/dev/null || echo "0")
                if [[ "$file_size" -gt 1000 ]]; then
                    log_warning "无法验证 ELF 格式，但文件大小合理（$file_size 字节），假设有效"
                    is_valid=true
                fi
            fi
            
            if [[ "$is_valid" == false ]]; then
                log_error "无效的动态库: $lib_path"
                return 1
            fi
        fi
    fi
    
    log_success "验证成功: $lib_name"
    return 0
}

# ============================================
# 统一的编译后验证函数
# ============================================
verify_build_result() {
    local lib_name=$1
    local arch=$2
    local lib_files=$3  # 逗号分隔的库文件列表，如 "libphonenumber.a,libphonenumber_static.a"
    local header_dirs=$4  # 逗号分隔的头文件目录列表，如 "phonenumbers,google"
    
    log_step "验证 $lib_name 编译结果 (架构: $arch)..."
    
    local all_verified=true
    
    # 验证库文件
    if [[ -n "$lib_files" ]]; then
        IFS=',' read -ra lib_array <<< "$lib_files"
        for lib_file in "${lib_array[@]}"; do
            lib_file=$(echo "$lib_file" | xargs)  # 去除空格
            local lib_path="${ARCH_INSTALL_DIR}/lib/${lib_file}"
            
            # 也检查 lib64、usr/lib 目录（OpenSSL 在 x86_64 上可能安装到 lib64）
            if [[ ! -f "$lib_path" ]]; then
                lib_path="${ARCH_INSTALL_DIR}/lib64/${lib_file}"
            fi
            if [[ ! -f "$lib_path" ]]; then
                lib_path="${ARCH_INSTALL_DIR}/usr/lib/${lib_file}"
            fi
            if [[ ! -f "$lib_path" ]]; then
                lib_path="${ARCH_INSTALL_DIR}/usr/lib64/${lib_file}"
            fi
            
            if verify_library "$lib_name" "$lib_path"; then
                log_info "  ✅ 库文件: $lib_file"
            else
                log_error "  ❌ 库文件缺失或无效: $lib_file"
                all_verified=false
            fi
        done
    fi
    
    # 验证头文件
    if [[ -n "$header_dirs" ]]; then
        IFS=',' read -ra header_array <<< "$header_dirs"
        for header_dir in "${header_array[@]}"; do
            header_dir=$(echo "$header_dir" | xargs)  # 去除空格
            local header_path="${ARCH_INSTALL_DIR}/include/${header_dir}"
            
            if [[ -d "$header_path" ]] || [[ -f "$header_path" ]]; then
                log_info "  ✅ 头文件目录: $header_dir"
            else
                log_warning "  ⚠️  头文件目录缺失: $header_dir"
                # 头文件缺失不阻止验证通过，只记录警告
            fi
        done
    fi
    
    if [[ "$all_verified" == true ]]; then
        log_success "$lib_name 编译验证通过: $arch"
        return 0
    else
        log_error "$lib_name 编译验证失败: $arch"
        return 1
    fi
}

# ============================================
# 设置编译环境
# ============================================
setup_build_env() {
    local arch=$1
    
    # 加载配置文件（使用脚本所在目录解析出的项目根，保证绝对路径）
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "$script_dir/.." && pwd)"
    
    if [[ -f "$project_root/config.sh" ]]; then
        source "$project_root/config.sh"
    elif [[ -f "config.sh" ]]; then
        source "config.sh"
    else
        log_error "配置文件不存在: $project_root/config.sh"
        return 1
    fi
    
    # 确保必要的目录变量为绝对路径（config.sh 已做解析，此处仅兜底）
    if [[ -z "$LOGS_DIR" ]]; then
        export LOGS_DIR="$(cd "${PROJECT_ROOT}/logs" 2>/dev/null && pwd) || ${PROJECT_ROOT}/logs"
    fi
    if [[ -z "$INSTALL_DIR" ]]; then
        export INSTALL_DIR="$(cd "${PROJECT_ROOT}/install" 2>/dev/null && pwd) || ${PROJECT_ROOT}/install"
    fi
    if [[ -z "$PATCHES_DIR" ]]; then
        export PATCHES_DIR="$(cd "${PROJECT_ROOT}/patches" 2>/dev/null && pwd) || ${PROJECT_ROOT}/patches"
    fi
    
    # 设置工具链
    if ! set_toolchain "$arch"; then
        log_error "工具链设置失败: $arch"
        return 1
    fi
    
    # 导出编译环境变量
    # 确保 UTF-8 编码，避免项目路径含中文时 configure/Makefile 产生乱码导致 make 失败
    if [[ -z "$LANG" ]] || [[ "$LANG" != *"UTF-8"* ]] && [[ -z "$LC_ALL" ]]; then
        export LANG="${LANG:-C.UTF-8}"
        export LC_ALL="${LC_ALL:-C.UTF-8}"
    fi
    # 添加 HarmonyOS Command Line Tools 到 PATH（如果存在）
    if [[ -n "$OHOS_COMMAND_LINE_TOOLS" ]] && [[ -d "$OHOS_COMMAND_LINE_TOOLS" ]]; then
        export PATH="${OHOS_COMMAND_LINE_TOOLS}/bin:$PATH"
    fi
    # 添加工具链到 PATH
    export PATH="${TOOLCHAIN_DIR}/bin:$PATH"
    export CC
    export CXX
    export AR
    export RANLIB
    export STRIP
    export CFLAGS
    export CXXFLAGS
    export LDFLAGS
    export PKG_CONFIG_PATH="${ARCH_INSTALL_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"
    export PKG_CONFIG_LIBDIR="${ARCH_INSTALL_DIR}/lib"
    export C_INCLUDE_PATH="${ARCH_INSTALL_DIR}/include:${C_INCLUDE_PATH}"
    export CPLUS_INCLUDE_PATH="${ARCH_INSTALL_DIR}/include:${CPLUS_INCLUDE_PATH}"
    export LIBRARY_PATH="${ARCH_INSTALL_DIR}/lib:${LIBRARY_PATH}"
    
    log_info "编译环境设置完成: $arch"
    log_info "CC: $CC"
    log_info "CXX: $CXX"
    
    return 0
}

# ============================================
# 创建构建目录
# ============================================
create_build_dir() {
    local lib_name=$1
    local arch=$2
    
    local build_dir="${ARCH_BUILD_DIR}/${lib_name}"
    local install_dir="${ARCH_INSTALL_DIR}"
    
    # 确保日志输出到 stderr，不影响返回值
    ensure_dir "$build_dir" >&2
    ensure_dir "$install_dir" >&2
    
    # 返回绝对路径，避免 CMake 等工具因工作目录或项目路径变更报错
    if [[ -d "$build_dir" ]]; then
        (cd "$build_dir" 2>/dev/null && pwd) || echo "$build_dir"
    else
        echo "$build_dir"
    fi
}

# ============================================
# 查找源码目录（灵活匹配，支持任意解压后的目录名）
# ============================================
find_source_dir() {
    local lib_name=$1
    local version=$2
    local extract_dir=${3:-"$EXTRACT_DIR"}
    
    # 1. 优先查找精确匹配的目录名
    # 支持多种常见命名格式
    local patterns=()
    
    # 精确匹配：lib-name（固定名称）
    patterns+=("${lib_name}")
    
    # TDLib 特殊处理：可能是 td 或 tdlib
    if [[ "$lib_name" == "tdlib" ]]; then
        patterns+=("td")
    elif [[ "$lib_name" == "td" ]]; then
        patterns+=("tdlib")
    fi
    
    # 如果有版本号，尝试带版本号的格式
    if [[ -n "$version" ]]; then
        # lib-name-version
        patterns+=("${lib_name}-${version}")
        
        # 特殊格式：sqlite-autoconf-xxx, abseil-cpp-xxx, protobuf-cpp-xxx
        case "$lib_name" in
            sqlite)
                patterns+=("sqlite-autoconf-${version}")
                ;;
            abseil)
                patterns+=("abseil-cpp-lts-${version}")
                patterns+=("abseil-cpp-${version}")
                ;;
            protobuf)
                patterns+=("protobuf-cpp-${version}")
                ;;
        esac
    fi
    
    # 模糊匹配：以库名开头的任意目录
    patterns+=("${lib_name}-*")
    
    # TDLib 额外的模糊匹配
    if [[ "$lib_name" == "tdlib" ]]; then
        patterns+=("td-*")
    fi
    
    # 按模式顺序查找
    for pattern in "${patterns[@]}"; do
        local found=$(find "$extract_dir" -maxdepth 1 -type d -name "$pattern" 2>/dev/null | head -1)
        if [[ -n "$found" ]] && [[ -d "$found" ]]; then
            echo "$found"
            return 0
        fi
    done
    
    # 最后尝试不区分大小写的模糊匹配
    local found=$(find "$extract_dir" -maxdepth 1 -type d -iname "*${lib_name}*" 2>/dev/null | head -1)
    if [[ -n "$found" ]] && [[ -d "$found" ]]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# ============================================
# 检查是否已编译
# ============================================
check_already_built() {
    local lib_name=$1
    local arch=$2
    local install_dir="${INSTALL_DIR}/${arch}"
    
    case "$lib_name" in
        openssl)
            if [[ -f "${install_dir}/lib/libssl.a" ]] && \
               [[ -f "${install_dir}/lib/libcrypto.a" ]]; then
                return 0
            fi
            ;;
        zlib)
            if [[ -f "${install_dir}/lib/libz.a" ]]; then
                return 0
            fi
            ;;
        sqlite)
            if [[ -f "${install_dir}/lib/libsqlite3.a" ]]; then
                return 0
            fi
            ;;
        tdlib)
            if [[ -f "${install_dir}/lib/libtdjson.so" ]] || \
               [[ -f "${install_dir}/lib/libtdjson.a" ]]; then
                return 0
            fi
            ;;
        *)
            # 通用检查
            if ls "${install_dir}/lib/lib${lib_name}"*.a > /dev/null 2>&1 || \
               ls "${install_dir}/lib/lib${lib_name}"*.so > /dev/null 2>&1; then
                return 0
            fi
            ;;
    esac
    
    return 1
}
