#!/bin/bash
# 验证构建结果脚本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

# 解析参数
ARCH=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --arch|-a)
            ARCH="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$ARCH" ]]; then
    log_error "请指定架构: --arch <架构名>"
    exit 1
fi

log_step "验证构建结果: $ARCH"

# 设置工具链以获取安装目录
if ! set_toolchain "$ARCH"; then
    log_error "工具链设置失败"
    exit 1
fi

# 需要验证的库文件
REQUIRED_LIBS=(
    "libz.a:zlib"
    "libssl.a:OpenSSL"
    "libcrypto.a:OpenSSL"
    "libsqlite3.a:SQLite"
    "libicuuc.a:ICU"
    "libicudata.a:ICU"
    "libprotobuf.a:Protocol Buffers"
    "libcrc32c.a:crc32c"
    "libxxhash.a:xxHash"
    "libre2.a:RE2"
    "libevent.a:libevent"
    "liblz4.a:LZ4"
    "libsnappy.a:Snappy"
    "libdouble-conversion.a:double-conversion"
    "libphonenumber.a:libphonenumber"
)

# TDLib 库（可能是 .so 或 .a）
TDLIB_LIBS=(
    "libtdjson.so:TDLib"
    "libtdjson.a:TDLib"
    "libtdclient.a:TDLib"
    "libtdcore.a:TDLib"
)

MISSING_LIBS=()
FOUND_LIBS=()
INVALID_LIBS=()

# 检查库文件
check_library() {
    local lib_file=$1
    local lib_name=$2
    local lib_path="${ARCH_INSTALL_DIR}/lib/${lib_file}"
    
    if [[ ! -f "$lib_path" ]]; then
        # 也检查 usr/lib 目录
        lib_path="${ARCH_INSTALL_DIR}/usr/lib/${lib_file}"
        if [[ ! -f "$lib_path" ]]; then
            MISSING_LIBS+=("$lib_name ($lib_file)")
            return 1
        fi
    fi
    
    # 验证库文件
    if [[ "$lib_file" == *.a ]]; then
        if ! "$AR" t "$lib_path" > /dev/null 2>&1; then
            INVALID_LIBS+=("$lib_name ($lib_file)")
            return 1
        fi
    elif [[ "$lib_file" == *.so ]]; then
        # 在 Windows 环境下，file 命令可能不可用或行为不同
        local is_windows=false
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]] || [[ "$MSYSTEM" == "MINGW"* ]]; then
            is_windows=true
        fi
        
        if [[ "$is_windows" == true ]]; then
            # Windows 环境：只检查文件存在和大小
            local file_size=$(stat -f%z "$lib_path" 2>/dev/null || stat -c%s "$lib_path" 2>/dev/null || echo "0")
            if [[ "$file_size" -le 0 ]]; then
                INVALID_LIBS+=("$lib_name ($lib_file)")
                return 1
            fi
        else
            # 非 Windows 环境：检查 ELF 格式
            if ! file "$lib_path" 2>/dev/null | grep -q "ELF\|shared object\|dynamically linked"; then
                INVALID_LIBS+=("$lib_name ($lib_file)")
                return 1
            fi
        fi
    fi
    
    FOUND_LIBS+=("$lib_name ($lib_file)")
    return 0
}

# 检查所有必需库
log_info "检查必需依赖库..."
for lib_info in "${REQUIRED_LIBS[@]}"; do
    IFS=':' read -r lib_file lib_name <<< "$lib_info"
    check_library "$lib_file" "$lib_name"
done

# 检查 TDLib 库（至少需要一个）
log_info "检查 TDLib 库..."
tdlib_found=false
for lib_info in "${TDLIB_LIBS[@]}"; do
    IFS=':' read -r lib_file lib_name <<< "$lib_info"
    if check_library "$lib_file" "$lib_name"; then
        tdlib_found=true
    fi
done

if [[ "$tdlib_found" == false ]]; then
    MISSING_LIBS+=("TDLib (任何库文件)")
fi

# 输出验证结果
echo ""
log_step "验证结果:"

if [[ ${#FOUND_LIBS[@]} -gt 0 ]]; then
    echo -e "${GREEN}✅ 找到的库 (${#FOUND_LIBS[@]}个):${NC}"
    for lib in "${FOUND_LIBS[@]}"; do
        echo "  • $lib"
    done
    echo ""
fi

if [[ ${#MISSING_LIBS[@]} -gt 0 ]]; then
    echo -e "${RED}❌ 缺失的库 (${#MISSING_LIBS[@]}个):${NC}"
    for lib in "${MISSING_LIBS[@]}"; do
        echo "  • $lib"
    done
    echo ""
fi

if [[ ${#INVALID_LIBS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  无效的库 (${#INVALID_LIBS[@]}个):${NC}"
    for lib in "${INVALID_LIBS[@]}"; do
        echo "  • $lib"
    done
    echo ""
fi

# 检查头文件
log_info "检查头文件..."
HEADER_DIRS=(
    "openssl"
    "zlib.h"
    "sqlite3.h"
    "unicode"
    "google/protobuf"
    "td/telegram"
)

MISSING_HEADERS=()
for header in "${HEADER_DIRS[@]}"; do
    if [[ -d "${ARCH_INSTALL_DIR}/include/${header}" ]] || \
       [[ -f "${ARCH_INSTALL_DIR}/include/${header}" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            log_info "找到头文件: $header"
        fi
    else
        MISSING_HEADERS+=("$header")
    fi
done

if [[ ${#MISSING_HEADERS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  缺失的头文件 (${#MISSING_HEADERS[@]}个):${NC}"
    for header in "${MISSING_HEADERS[@]}"; do
        echo "  • $header"
    done
    echo ""
fi

# 总结
echo ""
if [[ ${#MISSING_LIBS[@]} -eq 0 ]] && [[ ${#INVALID_LIBS[@]} -eq 0 ]]; then
    log_success "构建验证通过: $ARCH"
    echo ""
    echo "安装目录: $ARCH_INSTALL_DIR"
    echo "库文件数量: $(find "${ARCH_INSTALL_DIR}/lib" -name "*.a" -o -name "*.so" 2>/dev/null | wc -l)"
    exit 0
else
    log_error "构建验证失败: $ARCH"
    echo ""
    echo "修复建议:"
    echo "  1. 检查编译日志: ${LOGS_DIR}/build/"
    echo "  2. 重新编译缺失的库: ./scripts/build/build_<库名>.sh $ARCH"
    echo "  3. 检查依赖关系"
    exit 1
fi
