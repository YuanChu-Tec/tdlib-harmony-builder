#!/bin/bash
# 解压所有下载的源码包（不再限制文件名，直接使用解压后的目录名）

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

log_step "开始解压源码包"

# 确保解压目录存在
ensure_dir "$EXTRACT_DIR"

# 支持的压缩格式
ARCHIVE_EXTENSIONS=(
    ".tar.gz"
    ".tgz"
    ".tar.bz2"
    ".tar.xz"
    ".zip"
    ".tar"
)

# 需要检查的库关键字列表
REQUIRED_LIBS=(
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

# 检查下载目录
if [[ ! -d "$DOWNLOAD_DIR" ]]; then
    log_error "下载目录不存在: $DOWNLOAD_DIR"
    exit 1
fi

# 查找所有压缩文件（不再限制文件名）
ARCHIVE_FILES=()

# 使用正则表达式精确匹配文件名结尾，避免部分匹配
for ext in "${ARCHIVE_EXTENSIONS[@]}"; do
    # 将扩展名中的点转义，用于正则表达式
    escaped_ext="${ext//./\.}"
    while IFS= read -r file; do
        ARCHIVE_FILES+=("$file")
    done < <(find "$DOWNLOAD_DIR" -maxdepth 1 -type f -regex ".*${escaped_ext}$" 2>/dev/null)
done

# 去重（避免同一文件被多个扩展名匹配到，如 .tar.gz 被 .gz 也匹配到）
IFS=$'\n' ARCHIVE_FILES=($(sort -u <<<"${ARCHIVE_FILES[*]}"))
unset IFS

# 解压找到的文件
if [[ ${#ARCHIVE_FILES[@]} -eq 0 ]]; then
    log_error "未找到任何压缩文件"
    log_info "下载目录内容:"
    ls -la "$DOWNLOAD_DIR" 2>/dev/null || echo "  无法列出目录内容"
    log_info "支持的压缩格式: .tar.gz, .tgz, .tar.bz2, .tar.xz, .zip, .tar"
    exit 1
fi

log_info "找到 ${#ARCHIVE_FILES[@]} 个压缩文件"

FAILED_EXTRACTS=()
SUCCESS_EXTRACTS=()
SKIPPED_EXTRACTS=()

# 检查目录是否已包含指定库（通过关键字匹配）
is_lib_extracted() {
    local lib_name=$1
    # 检查解压目录中是否存在包含该关键字的子目录
    local found=$(find "$EXTRACT_DIR" -maxdepth 1 -type d -iname "*${lib_name}*" 2>/dev/null | head -1)
    [[ -n "$found" ]] && [[ -d "$found" ]]
}

# 获取压缩文件对应的库名
get_lib_from_archive() {
    local filename=$1
    for lib in "${REQUIRED_LIBS[@]}"; do
        if [[ "$filename" == *"$lib"* ]]; then
            echo "$lib"
            return 0
        fi
    done
    echo ""
    return 1
}

for archive in "${ARCHIVE_FILES[@]}"; do
    if [[ ! -f "$archive" ]]; then
        continue
    fi

    filename=$(basename "$archive")

    # 获取该压缩文件对应的库名
    lib_name=$(get_lib_from_archive "$filename")

    # 检查是否已解压
    if [[ -n "$lib_name" ]] && is_lib_extracted "$lib_name"; then
        log_info "跳过: $filename（已存在包含 '$lib_name' 的目录）"
        SKIPPED_EXTRACTS+=("$filename")
        continue
    fi

    log_step "解压: $filename"

    # 解压文件（不再自动重命名，直接使用解压后的目录名）
    if extract_file "$archive" "$EXTRACT_DIR"; then
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

if [[ ${#SKIPPED_EXTRACTS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  跳过 (${#SKIPPED_EXTRACTS[@]}个，已解压):${NC}"
    for file in "${SKIPPED_EXTRACTS[@]}"; do
        echo "  • $file"
    done
    echo ""
fi

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

# 列出解压后的目录
echo ""
log_info "解压后的目录结构:"
find "$EXTRACT_DIR" -maxdepth 1 -type d | grep -v "^$EXTRACT_DIR$" | sort | while read -r dir; do
    echo "  • $(basename "$dir")"
done

if [[ ${#FAILED_EXTRACTS[@]} -eq 0 ]]; then
    exit 0
else
    exit 1
fi