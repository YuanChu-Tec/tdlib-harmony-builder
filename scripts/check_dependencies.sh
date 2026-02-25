#!/bin/bash
# 检查依赖库是否已编译

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ABS="$(cd "$SCRIPTS_ABS/.." && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "${PROJECT_ABS}/config.sh"

ARCH=${1:-"arm64-v8a"}

log_step "检查依赖库编译状态: $ARCH"

# 设置工具链以获取安装目录
if ! set_toolchain "$ARCH"; then
    log_error "工具链设置失败"
    exit 1
fi

# 需要检查的库
REQUIRED_LIBS=(
    "zlib:libz.a"
    "openssl:libssl.a,libcrypto.a"
    "sqlite:libsqlite3.a"
    "icu:libicuuc.a,libicudata.a"
    "protobuf:libprotobuf.a"
    "crc32c:libcrc32c.a"
    "xxhash:libxxhash.a"
    "re2:libre2.a"
    "libevent:libevent.a"
    "lz4:liblz4.a"
    "snappy:libsnappy.a"
    "double-conversion:libdouble-conversion.a"
    "libphonenumber:libphonenumber.a"
)

MISSING_LIBS=()
FOUND_LIBS=()

for lib_info in "${REQUIRED_LIBS[@]}"; do
    IFS=':' read -r lib_name lib_files <<< "$lib_info"
    
    local all_found=true
    IFS=',' read -ra files <<< "$lib_files"
    
    for file in "${files[@]}"; do
        local lib_path="${ARCH_INSTALL_DIR}/lib/${file}"
        if [[ ! -f "$lib_path" ]]; then
            # 也检查 usr/lib
            lib_path="${ARCH_INSTALL_DIR}/usr/lib/${file}"
            if [[ ! -f "$lib_path" ]]; then
                all_found=false
                break
            fi
        fi
    done
    
    if [[ "$all_found" == true ]]; then
        log_success "$lib_name: 已编译"
        FOUND_LIBS+=("$lib_name")
    else
        log_warning "$lib_name: 未找到"
        MISSING_LIBS+=("$lib_name")
    fi
done

# 输出结果
echo ""
log_step "检查结果:"

if [[ ${#FOUND_LIBS[@]} -gt 0 ]]; then
    echo -e "${GREEN}✅ 已编译的库 (${#FOUND_LIBS[@]}个):${NC}"
    for lib in "${FOUND_LIBS[@]}"; do
        echo "  • $lib"
    done
    echo ""
fi

if [[ ${#MISSING_LIBS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  缺失的库 (${#MISSING_LIBS[@]}个):${NC}"
    for lib in "${MISSING_LIBS[@]}"; do
        echo "  • $lib"
    done
    echo ""
    
    echo -e "${CYAN}💡 编译缺失的库:${NC}"
    for lib in "${MISSING_LIBS[@]}"; do
        echo "  ./scripts/build/build_${lib}.sh $ARCH"
    done
    echo ""
fi

if [[ ${#MISSING_LIBS[@]} -eq 0 ]]; then
    log_success "所有依赖库已编译完成"
    exit 0
else
    log_warning "部分依赖库缺失，请先编译缺失的库"
    exit 1
fi
