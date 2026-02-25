#!/bin/bash
# 下载所有依赖库源码

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

# 如果启用自动获取最新版本，先更新版本
if [[ "$USE_LATEST_VERSION" == "true" ]] || \
   [[ "$USE_LATEST_VERSION" == "auto" ]] || \
   [[ "$USE_LATEST_VERSION" == "latest" ]]; then
    log_step "自动获取最新版本..."
    update_to_latest_versions
    echo ""
fi

log_step "开始下载依赖库源码"

# 确保下载目录存在
ensure_dir "$DOWNLOAD_DIR"

# 需要下载的库列表
LIBRARIES=(
    "openssl:$OPENSSL_VERSION"
    "zlib:$ZLIB_VERSION"
    "sqlite:$SQLITE_VERSION"
    "icu:$ICU_VERSION"
    "protobuf:$PROTOBUF_VERSION"
    "libphonenumber:$LIBPHONENUMBER_VERSION"
    "crc32c:$CRC32C_VERSION"
    "xxhash:$XXHASH_VERSION"
    "abseil:$ABSEIL_VERSION"
    "re2:$RE2_VERSION"
    "libevent:$LIBEVENT_VERSION"
    "lz4:$LZ4_VERSION"
    "snappy:$SNAPPY_VERSION"
    "double-conversion:$DOUBLE_CONVERSION_VERSION"
    "tdlib:$TDLIB_VERSION"
)

FAILED_DOWNLOADS=()
SUCCESS_DOWNLOADS=()

for lib_info in "${LIBRARIES[@]}"; do
    IFS=':' read -r lib_name lib_version <<< "$lib_info"
    
    log_step "下载 $lib_name ($lib_version)..."
    
    # 获取下载URL
    url=$(get_download_url "$lib_name" "$lib_version")
    if [[ $? -ne 0 ]]; then
        log_error "无法获取 $lib_name 的下载URL"
        FAILED_DOWNLOADS+=("$lib_name")
        continue
    fi
    
    # 确定文件名
    filename=$(basename "$url")
    dest_path="$DOWNLOAD_DIR/$filename"
    
    # 下载文件
    if download_file "$url" "$dest_path"; then
        log_success "$lib_name 下载完成"
        SUCCESS_DOWNLOADS+=("$lib_name")
    else
        log_error "$lib_name 下载失败"
        FAILED_DOWNLOADS+=("$lib_name")
    fi
done

# 输出结果
echo ""
log_step "下载完成总结:"

if [[ ${#SUCCESS_DOWNLOADS[@]} -gt 0 ]]; then
    echo -e "${GREEN}✅ 成功下载 (${#SUCCESS_DOWNLOADS[@]}个):${NC}"
    for lib in "${SUCCESS_DOWNLOADS[@]}"; do
        echo "  • $lib"
    done
    echo ""
fi

if [[ ${#FAILED_DOWNLOADS[@]} -gt 0 ]]; then
    echo -e "${RED}❌ 下载失败 (${#FAILED_DOWNLOADS[@]}个):${NC}"
    for lib in "${FAILED_DOWNLOADS[@]}"; do
        echo "  • $lib"
    done
    echo ""
fi

if [[ ${#FAILED_DOWNLOADS[@]} -eq 0 ]]; then
    exit 0
else
    exit 1
fi
