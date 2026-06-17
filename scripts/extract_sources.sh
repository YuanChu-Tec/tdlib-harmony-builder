#!/bin/bash
# 解压所有下载的源码包

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

log_step "开始解压源码包"

# 确保解压目录存在
ensure_dir "$EXTRACT_DIR"

# 定义允许的库名称（固定名称，无版本号）
ALLOWED_LIBS=(
    "openssl"
    "zlib"
    "sqlite"
    "icu"
    "protobuf"
    "libphonenumber"
    "crc32c"
    "xxhash"
    "abseil"
    "re2"
    "libevent"
    "lz4"
    "snappy"
    "double-conversion"
    "tdlib"
)

# 支持的压缩格式
ARCHIVE_EXTENSIONS=(
    ".tar.gz"
    ".tgz"
    ".tar.bz2"
    ".tar.xz"
    ".zip"
    ".tar"
)

# 查找所有允许的压缩文件
find_allowed_archives() {
    local lib_name=$1
    for ext in "${ARCHIVE_EXTENSIONS[@]}"; do
        local archive_path="${DOWNLOAD_DIR}/${lib_name}${ext}"
        if [[ -f "$archive_path" ]]; then
            echo "$archive_path"
            return 0
        fi
    done
    return 1
}

# 检查下载目录
if [[ ! -d "$DOWNLOAD_DIR" ]]; then
    log_error "下载目录不存在: $DOWNLOAD_DIR"
    exit 1
fi

# 查找所有允许的压缩文件
ARCHIVE_FILES=()
for lib in "${ALLOWED_LIBS[@]}"; do
    archive=$(find_allowed_archives "$lib")
    if [[ -n "$archive" ]]; then
        ARCHIVE_FILES+=("$archive")
        log_info "找到: $(basename "$archive")"
    fi
done

# 解压找到的文件
if [[ ${#ARCHIVE_FILES[@]} -eq 0 ]]; then
    log_error "未找到任何允许的压缩文件"
    log_info "允许的文件名称:"
    for lib in "${ALLOWED_LIBS[@]}"; do
        echo "  • ${lib}.tar.gz (或其他压缩格式)"
    done
    log_info "下载目录内容:"
    ls -la "$DOWNLOAD_DIR" 2>/dev/null || echo "  无法列出目录内容"
    exit 1
fi

log_info "找到 ${#ARCHIVE_FILES[@]} 个允许的压缩文件"

FAILED_EXTRACTS=()
SUCCESS_EXTRACTS=()

for archive in "${ARCHIVE_FILES[@]}"; do
    if [[ ! -f "$archive" ]]; then
        continue
    fi
    
    filename=$(basename "$archive")
    log_step "解压: $filename"
    
    # 解压文件
    if extract_file "$archive" "$EXTRACT_DIR"; then
        # 获取库名称（去掉扩展名）
        lib_name=$(echo "$filename" | sed 's/\.[^.]*$//' | sed 's/\.[^.]*$//')
        
        # 检查解压后的目录是否需要重命名
        # 解压后可能是 openssl-1.1.1w 这样的目录，需要重命名为 openssl
        
        # 方法：查找以 lib_name 开头的目录（处理 openssl-3.6.0, sqlite-autoconf-3510200 等情况）
        local extracted_dir=""
        
        # 首先检查是否已经是固定名称
        local fixed_name_dir="${EXTRACT_DIR}/${lib_name}"
        if [[ -d "$fixed_name_dir" ]]; then
            log_info "目录已为固定名称: $lib_name"
            extracted_dir="$fixed_name_dir"
        else
            # 查找以 lib_name 开头的目录
            # 处理各种格式：openssl-3.6.0, sqlite-autoconf-3510200, abseil-cpp-lts-20240116.2, td-1.8.0 等
            local found_dirs=()
            while IFS= read -r dir; do
                found_dirs+=("$dir")
            done < <(find "$EXTRACT_DIR" -maxdepth 1 -type d -name "${lib_name}*" 2>/dev/null)
            
            # 如果找到多个匹配，选择最可能的一个
            if [[ ${#found_dirs[@]} -eq 1 ]]; then
                extracted_dir="${found_dirs[0]}"
            elif [[ ${#found_dirs[@]} -gt 1 ]]; then
                # 优先选择版本号格式的目录
                for dir in "${found_dirs[@]}"; do
                    if [[ "$dir" =~ ${lib_name}-[0-9] ]]; then
                        extracted_dir="$dir"
                        break
                    fi
                done
                # 如果没有找到版本号格式的，选择第一个
                if [[ -z "$extracted_dir" ]]; then
                    extracted_dir="${found_dirs[0]}"
                fi
            fi
            
            # 特殊处理：TDLib 通常解压为 td-xxx
            if [[ -z "$extracted_dir" ]] && [[ "$lib_name" == "tdlib" ]]; then
                local td_dir=$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name "td*" 2>/dev/null | head -1)
                if [[ -d "$td_dir" ]]; then
                    extracted_dir="$td_dir"
                fi
            fi
        fi
        
        # 如果找到解压目录且不是固定名称，则重命名
        if [[ -n "$extracted_dir" ]] && [[ -d "$extracted_dir" ]]; then
            local final_dir="${EXTRACT_DIR}/${lib_name}"
            if [[ "$extracted_dir" != "$final_dir" ]]; then
                log_info "重命名目录: $(basename "$extracted_dir") -> $lib_name"
                rm -rf "$final_dir" 2>/dev/null
                mv "$extracted_dir" "$final_dir"
            fi
        fi
        
        log_success "$filename 解压完成"
        SUCCESS_EXTRACTS+=("$filename")
    else
        log_error "$filename 解压失败"
        log_info "文件路径: $archive"
        FAILED_EXTRACTS+=("$filename")
    fi
done

# 输出结果
echo ""
log_step "解压完成总结:"

if [[ ${#SUCCESS_EXTRACTS[@]} -gt 0 ]]; then
    echo -e "${GREEN}✅ 成功解压 (${#SUCCESS_EXTRACTS[@]}个):${NC}"
    for file in "${SUCCESS_EXTRACTS[@]}"; do
        echo "  • $file"
    done
    echo ""
fi

if [[ ${#FAILED_EXTRACTS[@]} -gt 0 ]]; then
    echo -e "${RED}❌ 解压失败 (${#FAILED_EXTRACTS[@]}个):${NC}"
    for file in "${FAILED_EXTRACTS[@]}"; do
        echo "  • $file"
    done
    echo ""
fi

log_info "解压后的源码位于: $EXTRACT_DIR"

if [[ ${#FAILED_EXTRACTS[@]} -eq 0 ]]; then
    exit 0
else
    exit 1
fi
