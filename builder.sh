#!/bin/bash
# TDLib for HarmonyOS 主构建脚本

# 使用绝对路径加载配置文件，避免工作目录或脚本位置导致路径错乱
PROJECT_ROOT_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${PROJECT_ROOT_SCRIPT}/config.sh"

# ============================================
# 颜色和样式定义
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# ============================================
# 打印函数
# ============================================

print_header() {
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                TDLib for HarmonyOS 构建系统                     ║"
    echo "║                        版本 ${PROJECT_VERSION}                           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${CYAN}▶${NC} ${BOLD}$1${NC}"
}

print_substep() {
    echo -e "  ${BLUE}↳${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_divider() {
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
}

# ============================================
# 构建流程函数
# ============================================

download_sources() {
    print_step "下载依赖库源码"
    
    local log_file="${LOGS_DIR}/download/download_${BUILD_DATE}.log"
    
    if ! bash "${SCRIPTS_DIR}/download_sources.sh" 2>&1 | tee "$log_file"; then
        print_error "源码下载失败"
        return 1
    fi
    
    print_success "源码下载完成"
    return 0
}

extract_sources() {
    print_step "解压源码包"
    
    if ! bash "${SCRIPTS_DIR}/extract_sources.sh"; then
        print_error "源码解压失败"
        return 1
    fi
    
    print_success "源码解压完成"
    return 0
}

apply_patches() {
    print_step "应用 HarmonyOS 适配补丁"
    
    if ! bash "${SCRIPTS_DIR}/apply_patches.sh"; then
        print_warning "部分补丁应用可能失败，继续构建..."
    fi
    
    print_success "补丁应用完成"
    return 0
}

build_architecture() {
    local arch=$1
    
    print_divider
    echo -e "${BOLD}构建架构: ${CYAN}$arch${NC}"
    print_divider
    
    # 设置工具链
    if ! set_toolchain "$arch"; then
        print_error "工具链设置失败: $arch"
        return 1
    fi
    
    # 检查环境
    if ! check_environment "$arch"; then
        print_error "环境检查失败: $arch"
        return 1
    fi
    
    # 编译所有依赖库
    print_step "编译依赖库"
    
    if ! bash "${SCRIPTS_DIR}/build_all.sh" --arch "$arch"; then
        print_error "依赖库编译失败: $arch"
        return 1
    fi
    
    # 编译TDLib
    print_step "编译 TDLib"
    
    if ! bash "${SCRIPTS_DIR}/build/build_tdlib.sh" "$arch"; then
        print_error "TDLib 编译失败: $arch"
        return 1
    fi
    
    print_success "架构 $arch 构建完成"
    return 0
}

verify_build() {
    local arch=$1
    
    print_step "验证构建结果: $arch"
    
    if ! bash "${SCRIPTS_DIR}/verify_build.sh" --arch "$arch"; then
        print_warning "构建验证发现警告: $arch"
        return 1
    fi
    
    print_success "构建验证通过: $arch"
    return 0
}

package_distribution() {
    print_step "打包发布文件"
    
    if ! bash "${SCRIPTS_DIR}/package_dist.sh"; then
        print_error "打包失败"
        return 1
    fi
    
    print_success "打包完成"
    return 0
}

clean_build() {
    print_step "清理构建文件"
    
    if ! bash "${SCRIPTS_DIR}/cleanup.sh"; then
        print_error "清理失败"
        return 1
    fi
    
    print_success "清理完成"
    return 0
}

# ============================================
# 完整构建流程
# ============================================

full_build() {
    print_header
    echo "开始完整构建流程..."
    echo ""
    
    local start_time=$(date +%s)
    
    # 1. 下载源码
    if ! download_sources; then
        return 1
    fi
    
    # 2. 解压源码
    if ! extract_sources; then
        return 1
    fi
    
    # 3. 应用补丁
    if ! apply_patches; then
        print_warning "补丁应用可能不完整"
    fi
    
    # 4. 编译所有架构
    local failed_archs=()
    local success_archs=()
    
    for arch in "${ARCHITECTURES[@]}"; do
        if build_architecture "$arch"; then
            success_archs+=("$arch")
            
            # 验证构建
            if verify_build "$arch"; then
                print_success "架构 $arch 验证通过"
            else
                print_warning "架构 $arch 验证有警告"
            fi
        else
            failed_archs+=("$arch")
            print_error "架构 $arch 构建失败"
        fi
    done
    
    # 5. 打包发布
    if [[ ${#success_archs[@]} -gt 0 ]]; then
        if package_distribution; then
            print_success "发布包创建成功"
        else
            print_error "发布包创建失败"
        fi
    else
        print_error "没有成功构建的架构，跳过打包"
    fi
    
    # 6. 显示构建结果
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_divider
    echo -e "${BOLD}构建结果:${NC}"
    echo ""
    
    if [[ ${#success_archs[@]} -gt 0 ]]; then
        echo -e "${GREEN}✅ 成功构建的架构 (${#success_archs[@]}个):${NC}"
        for arch in "${success_archs[@]}"; do
            echo "  • $arch"
        done
        echo ""
        
        # 显示发布包信息
        local package_name="${PROJECT_NAME}-${PROJECT_VERSION}-${BUILD_DATE}"
        local package_path="${DIST_DIR}/${package_name}.tar.gz"
        
        if [[ -f "$package_path" ]]; then
            echo -e "${GREEN}📦 发布包信息:${NC}"
            echo "  文件: $(basename "$package_path")"
            echo "  大小: $(du -h "$package_path" | cut -f1)"
            echo "  位置: $package_path"
            echo ""
            
            # 显示SHA256校验和
            if command -v sha256sum &> /dev/null; then
                echo -e "${GREEN}🔒 SHA256 校验和:${NC}"
                sha256sum "$package_path" | cut -d' ' -f1
                echo ""
            fi
        fi
    fi
    
    if [[ ${#failed_archs[@]} -gt 0 ]]; then
        echo -e "${RED}❌ 构建失败的架构 (${#failed_archs[@]}个):${NC}"
        for arch in "${failed_archs[@]}"; do
            echo "  • $arch"
        done
        echo ""
        
        echo -e "${YELLOW}💡 修复建议:${NC}"
        echo "  1. 查看详细日志: ${LOGS_DIR}/build_${BUILD_DATE}.log"
        echo "  2. 检查环境变量是否正确设置"
        echo "  3. 尝试单独编译失败的架构: ./builder.sh --arch <架构名>"
        echo ""
    fi
    
    echo -e "${CYAN}⏱️  构建耗时:${NC} $((duration / 60))分$((duration % 60))秒"
    print_divider
    
    if [[ ${#failed_archs[@]} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================
# 其他构建模式
# ============================================

build_single_arch() {
    local arch=$1
    
    print_header
    echo "开始构建架构: $arch"
    echo ""
    
    if build_architecture "$arch"; then
        verify_build "$arch"
        print_success "架构 $arch 构建完成"
        return 0
    else
        print_error "架构 $arch 构建失败"
        return 1
    fi
}

build_only() {
    print_header
    echo "开始编译流程（使用现有源码）"
    echo ""
    
    # 检查源码是否存在
    if [[ ! -d "$EXTRACT_DIR" ]] || [[ -z "$(ls -A "$EXTRACT_DIR" 2>/dev/null)" ]]; then
        print_error "源码不存在，请先下载源码"
        echo "运行: ./builder.sh --download"
        return 1
    fi
    
    local failed_archs=()
    local success_archs=()
    
    for arch in "${ARCHITECTURES[@]}"; do
        if build_architecture "$arch"; then
            success_archs+=("$arch")
        else
            failed_archs+=("$arch")
        fi
    done
    
    # 显示结果
    print_divider
    echo "编译完成"
    echo ""
    
    if [[ ${#success_archs[@]} -gt 0 ]]; then
        echo -e "${GREEN}✅ 成功编译: ${success_archs[*]}${NC}"
    fi
    
    if [[ ${#failed_archs[@]} -gt 0 ]]; then
        echo -e "${RED}❌ 编译失败: ${failed_archs[*]}${NC}"
        return 1
    fi
    
    return 0
}

download_only() {
    print_header
    echo "仅下载源码"
    echo ""
    
    download_sources
    extract_sources
}

clean_only() {
    print_header
    echo "清理构建文件"
    echo ""
    
    echo "这将删除以下目录:"
    echo "  • $BUILD_DIR"
    echo "  • $INSTALL_DIR"
    echo "  • $EXTRACT_DIR"
    echo ""
    
    read -p "确定要清理吗？(y/N): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        echo "取消清理"
        return 0
    fi
    
    clean_build
}

# ============================================
# 测试功能
# ============================================

run_tests() {
    print_header
    echo "运行测试"
    echo ""
    
    # 编译测试程序
    print_step "编译测试程序"
    
    for arch in "${ARCHITECTURES[@]}"; do
        if [[ -d "${INSTALL_DIR}/${arch}" ]]; then
            echo "测试架构: $arch"
            
            # 这里可以添加具体的测试逻辑
            if [[ -f "${TESTS_DIR}/test_tdlib_basic.sh" ]]; then
                bash "${TESTS_DIR}/test_tdlib_basic.sh" "$arch"
            fi
        fi
    done
    
    print_success "测试完成"
}

# ============================================
# 系统信息
# ============================================

show_system_info() {
    print_header
    
    echo -e "${BOLD}系统信息:${NC}"
    echo ""
    
    echo -e "${CYAN}操作系统:${NC}"
    echo "  系统: $(uname -s)"
    echo "  版本: $(uname -r)"
    echo "  架构: $(uname -m)"
    echo ""
    
    echo -e "${CYAN}HarmonyOS 工具链:${NC}"
    echo "  NDK 路径: $OHOS_NDK"
    echo "  SDK 路径: $OHOS_SDK"
    echo "  API 级别: $OHOS_API_LEVEL"
    echo ""
    
    echo -e "${CYAN}构建配置:${NC}"
    echo "  项目版本: $PROJECT_VERSION"
    echo "  目标架构: ${ARCHITECTURES[*]}"
    echo "  构建模式: $BUILD_MODE"
    echo "  并行任务: $PARALLEL_JOBS"
    echo ""
    
    echo -e "${CYAN}磁盘使用:${NC}"
    echo "  项目目录: $(du -sh "$PROJECT_ROOT" | cut -f1)"
    echo "  源码目录: $(du -sh "$SOURCE_DIR" 2>/dev/null | cut -f1 || echo "空")"
    echo "  构建目录: $(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "空")"
    echo "  安装目录: $(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1 || echo "空")"
    echo ""
    
    echo -e "${CYAN}工具版本:${NC}"
    echo "  CMake: $(cmake --version 2>/dev/null | head -n1 || echo "未安装")"
    echo "  Ninja: $(ninja --version 2>/dev/null || echo "未安装")"
    echo "  Clang: $(${TOOLCHAIN_DIR}/bin/clang --version 2>/dev/null | head -n1 || echo "未安装")"
    echo ""
}

# ============================================
# 交互式菜单
# ============================================

show_menu() {
    clear
    print_header
    
    echo "请选择操作:"
    echo ""
    echo "  ${GREEN}1.${NC} 完整构建（下载 → 编译 → 打包）"
    echo "  ${GREEN}2.${NC} 仅编译（使用现有源码）"
    echo "  ${GREEN}3.${NC} 仅下载源码"
    echo "  ${GREEN}4.${NC} 仅打包已编译的库"
    echo "  ${GREEN}5.${NC} 清理所有构建文件"
    echo "  ${GREEN}6.${NC} 运行测试"
    echo "  ${GREEN}7.${NC} 显示系统信息"
    echo "  ${GREEN}8.${NC} 编译单个架构"
    echo "  ${GREEN}0.${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-8]: " choice
    echo ""
    
    case $choice in
        1)
            full_build
            ;;
        2)
            build_only
            ;;
        3)
            download_only
            ;;
        4)
            package_distribution
            ;;
        5)
            clean_only
            ;;
        6)
            run_tests
            ;;
        7)
            show_system_info
            ;;
        8)
            echo "选择要编译的架构:"
            echo "  1) arm64-v8a"
            echo "  2) armeabi-v7a"
            echo "  3) x86_64"
            echo ""
            read -p "请输入选项 [1-3]: " arch_choice
            
            case $arch_choice in
                1) build_single_arch "arm64-v8a" ;;
                2) build_single_arch "armeabi-v7a" ;;
                3) build_single_arch "x86_64" ;;
                *) print_error "无效的选项" ;;
            esac
            ;;
        0)
            echo "再见！"
            exit 0
            ;;
        *)
            print_error "无效的选项"
            sleep 2
            show_menu
            ;;
    esac
    
    echo ""
    read -p "按回车键返回主菜单..."
    show_menu
}

# ============================================
# 命令行参数处理
# ============================================

show_help() {
    print_header
    
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --full            完整构建流程"
    echo "  --build           仅编译现有源码"
    echo "  --download        仅下载源码"
    echo "  --package         仅打包已编译的库"
    echo "  --clean           清理构建文件"
    echo "  --test            运行测试"
    echo "  --info            显示系统信息"
    echo "  --arch=ARCH       指定构建的架构"
    echo "  --help, -h        显示此帮助信息"
    echo ""
    echo "架构选项:"
    echo "  arm64-v8a, armeabi-v7a, x86_64"
    echo ""
    echo "示例:"
    echo "  $0 --full                     # 完整构建所有架构"
    echo "  $0 --arch=arm64-v8a           # 仅构建 arm64-v8a 架构"
    echo "  $0 --build                    # 仅编译现有源码"
    echo "  $0 --clean                    # 清理构建文件"
    echo ""
}

# 处理命令行参数
if [[ $# -gt 0 ]]; then
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --full)
            full_build
            exit $?
            ;;
        --build)
            build_only
            exit $?
            ;;
        --download)
            download_only
            exit $?
            ;;
        --package)
            package_distribution
            exit $?
            ;;
        --clean)
            clean_only
            exit $?
            ;;
        --test)
            run_tests
            exit $?
            ;;
        --info)
            show_system_info
            exit $?
            ;;
        --arch=*)
            ARCHITECTURES=("${1#*=}")
            build_single_arch "${ARCHITECTURES[0]}"
            exit $?
            ;;
        *)
            print_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
else
    # 如果没有参数，显示菜单
    show_menu
fi