#!/bin/bash
# 编译所有依赖库的脚本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"

# 解析参数
ARCH=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --arch|-a)
            ARCH="$2"
            shift 2
            ;;
        --force|-f)
            FORCE=true
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

log_step "开始编译所有依赖库 (架构: $ARCH)"

# 编译顺序（根据依赖关系）
# protobuf 35.x 依赖 Abseil，因此 abseil 必须在 protobuf 之前编译
LIBRARIES=(
    "zlib"
    "openssl"
    "sqlite"
    "icu"
    "crc32c"
    "xxhash"
    "abseil"      # Abseil 供 protobuf 和 RE2 使用
    "protobuf"    # protobuf 35.x 依赖 Abseil
    "re2"         # RE2 依赖 Abseil
    "libevent"
    "lz4"
    "snappy"
    "double-conversion"
    "libphonenumber"
    "tdlib"
)

FAILED_LIBS=()
SUCCESS_LIBS=()

for lib in "${LIBRARIES[@]}"; do
    log_step "========================================"
    log_step "开始编译: $lib"
    
    # 构建脚本路径（处理连字符和下划线）
    # 注意：在 Git Bash 中，local 只能在函数内使用，所以这里使用普通变量
    script_name="${lib}"
    # double-conversion 使用下划线
    if [[ "$lib" == "double-conversion" ]]; then
        script_name="double_conversion"
    fi
    SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")/build/build_${script_name}.sh"
    
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_warning "编译脚本不存在: $SCRIPT_PATH，跳过"
        FAILED_LIBS+=("$lib (脚本缺失)")
        continue
    fi
    
    # 执行编译
    if bash "$SCRIPT_PATH" "$ARCH"; then
        log_success "$lib 编译成功"
        SUCCESS_LIBS+=("$lib")
    else
        log_error "$lib 编译失败"
        FAILED_LIBS+=("$lib")
        
        # 询问是否继续
        echo ""
        read -p "❌ $lib 编译失败，是否继续编译其他库？ [Y/n]: " response
        if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
            log_info "用户选择停止编译"
            break
        fi
    fi
done

# 输出编译结果
log_step "========================================"
log_step "编译完成总结:"
echo ""

if [[ ${#SUCCESS_LIBS[@]} -gt 0 ]]; then
    echo -e "${GREEN}✅ 成功编译的库 (${#SUCCESS_LIBS[@]}个):${NC}"
    for lib in "${SUCCESS_LIBS[@]}"; do
        echo "  • $lib"
    done
    echo ""
fi

if [[ ${#FAILED_LIBS[@]} -gt 0 ]]; then
    echo -e "${RED}❌ 编译失败的库 (${#FAILED_LIBS[@]}个):${NC}"
    for lib in "${FAILED_LIBS[@]}"; do
        echo "  • $lib"
    done
    echo ""
    
    echo -e "${YELLOW}💡 修复建议:${NC}"
    echo "  1. 查看详细日志: ${LOGS_DIR}/build/"
    echo "  2. 尝试单独编译失败的库: ./scripts/build/build_<库名>.sh $ARCH"
    echo "  3. 检查依赖关系和环境变量"
    echo ""
fi

log_info "所有库的安装位置: ${INSTALL_DIR}/${ARCH}"

if [[ ${#FAILED_LIBS[@]} -eq 0 ]]; then
    exit 0
else
    exit 1
fi
