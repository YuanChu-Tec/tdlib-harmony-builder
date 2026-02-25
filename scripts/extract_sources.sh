#!/bin/bash
# 解压所有下载的源码包

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

log_step "开始解压源码包"

# 确保解压目录存在
ensure_dir "$EXTRACT_DIR"

# 检查下载目录
if [[ ! -d "$DOWNLOAD_DIR" ]] || [[ -z "$(ls -A "$DOWNLOAD_DIR" 2>/dev/null)" ]]; then
    log_error "下载目录为空，请先运行下载脚本"
    exit 1
fi

# 解压所有压缩包
FAILED_EXTRACTS=()
SUCCESS_EXTRACTS=()

# 支持的压缩格式（分别查找，兼容 Git Bash）
ARCHIVE_PATTERNS=(
    "*.tar.gz"
    "*.tgz"
    "*.tar.bz2"
    "*.tar.xz"
    "*.zip"
    "*.tar"
)

# 收集所有压缩文件
ARCHIVE_FILES=()

# 分别查找每种格式的文件（兼容 Git Bash 和 Windows）
for pattern in "${ARCHIVE_PATTERNS[@]}"; do
    # 方法1: 使用 find 命令（推荐，兼容性最好）
    if command -v find &> /dev/null; then
        # 使用 find 查找文件
        find_output=$(find "$DOWNLOAD_DIR" -maxdepth 1 -type f -iname "$pattern" 2>/dev/null)
        
        # 处理 find 的输出（兼容 Git Bash）
        if [[ -n "$find_output" ]]; then
            # 将多行输出转换为数组
            OLD_IFS="$IFS"
            IFS=$'\n'
            for archive in $find_output; do
                if [[ -n "$archive" ]] && [[ -f "$archive" ]]; then
                    # 检查是否已存在（避免重复）
                    exists=false
                    for existing in "${ARCHIVE_FILES[@]}"; do
                        if [[ "$existing" == "$archive" ]]; then
                            exists=true
                            break
                        fi
                    done
                    if [[ "$exists" == false ]]; then
                        ARCHIVE_FILES+=("$archive")
                    fi
                fi
            done
            IFS="$OLD_IFS"
        fi
    fi
    
    # 方法2: 使用通配符（备用，兼容 Git Bash）
    # 注意：在 Git Bash 中，通配符可能不会展开，但可以作为备用
    for archive in "$DOWNLOAD_DIR"/$pattern; do
        # 检查文件是否存在且不是通配符本身
        if [[ -f "$archive" ]] && [[ "$archive" != "$DOWNLOAD_DIR/$pattern" ]]; then
            # 检查是否已存在（避免重复）
            exists=false
            for existing in "${ARCHIVE_FILES[@]}"; do
                if [[ "$existing" == "$archive" ]]; then
                    exists=true
                    break
                fi
            done
            if [[ "$exists" == false ]]; then
                ARCHIVE_FILES+=("$archive")
            fi
        fi
    done
done

# 去重（避免重复）
if [[ ${#ARCHIVE_FILES[@]} -gt 0 ]]; then
    # 使用关联数组去重（如果支持）
    if declare -A seen 2>/dev/null; then
        UNIQUE_FILES=()
        for archive in "${ARCHIVE_FILES[@]}"; do
            if [[ -z "${seen[$archive]}" ]]; then
                seen["$archive"]=1
                UNIQUE_FILES+=("$archive")
            fi
        done
        ARCHIVE_FILES=("${UNIQUE_FILES[@]}")
    else
        # 如果不支持关联数组，使用简单去重
        UNIQUE_FILES=()
        for archive in "${ARCHIVE_FILES[@]}"; do
            exists=false
            for existing in "${UNIQUE_FILES[@]}"; do
                if [[ "$existing" == "$archive" ]]; then
                    exists=true
                    break
                fi
            done
            if [[ "$exists" == false ]]; then
                UNIQUE_FILES+=("$archive")
            fi
        done
        ARCHIVE_FILES=("${UNIQUE_FILES[@]}")
    fi
fi

# 解压找到的文件
if [[ ${#ARCHIVE_FILES[@]} -eq 0 ]]; then
    log_warning "未找到任何压缩文件"
    log_info "请检查下载目录: $DOWNLOAD_DIR"
    log_info "下载目录内容:"
    ls -la "$DOWNLOAD_DIR" 2>/dev/null || echo "  无法列出目录内容"
    exit 1
fi

log_info "找到 ${#ARCHIVE_FILES[@]} 个压缩文件"

for archive in "${ARCHIVE_FILES[@]}"; do
    if [[ ! -f "$archive" ]]; then
        continue
    fi
    
    filename=$(basename "$archive")
    log_step "解压: $filename"
    
    # 解压文件
    if extract_file "$archive" "$EXTRACT_DIR"; then
        log_success "$filename 解压完成"
        SUCCESS_EXTRACTS+=("$filename")
    else
        log_error "$filename 解压失败"
        log_info "文件路径: $archive"
        log_info "尝试手动解压命令:"
        if [[ "$filename" == *.tgz ]] || [[ "$filename" == *.tar.gz ]]; then
            log_info "  tar -xzf \"$archive\" -C \"$EXTRACT_DIR\""
        elif [[ "$filename" == *.tar.bz2 ]]; then
            log_info "  tar -xjf \"$archive\" -C \"$EXTRACT_DIR\""
        elif [[ "$filename" == *.zip ]]; then
            log_info "  unzip \"$archive\" -d \"$EXTRACT_DIR\""
        fi
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
