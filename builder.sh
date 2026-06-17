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
    echo "║                TDLib for HarmonyOS 构建系统                      ║"
    echo "║                        版本 ${PROJECT_VERSION}                    ║"
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
    
    # 1. 解压源码
    if ! extract_sources; then
        return 1
    fi
    
    # 补丁将在编译时自动应用（build_tdlib.sh 中处理）
    
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

# ============================================
# 单个架构的分步执行功能
# ============================================

build_single_arch_only() {
    print_header
    echo "编译单个架构（使用现有源码）"
    echo ""
    
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
}

package_single_arch() {
    print_header
    echo "打包单个架构"
    echo ""
    
    echo "选择要打包的架构:"
    echo "  1) arm64-v8a"
    echo "  2) armeabi-v7a"
    echo "  3) x86_64"
    echo ""
    read -p "请输入选项 [1-3]: " arch_choice
    
    local arch=""
    case $arch_choice in
        1) arch="arm64-v8a" ;;
        2) arch="armeabi-v7a" ;;
        3) arch="x86_64" ;;
        *) print_error "无效的选项"; return 1 ;;
    esac
    
    package_single_arch_direct "$arch"
}

package_single_arch_direct() {
    local arch=$1
    
    print_header
    echo "打包架构: $arch"
    echo ""
    
    # 检查该架构是否已编译
    if [[ ! -d "${INSTALL_DIR}/${arch}" ]]; then
        print_error "架构 $arch 尚未编译，请先编译"
        return 1
    fi
    
    # 创建单个架构的发布包
    local package_name="${PROJECT_NAME}-${PROJECT_VERSION}-${arch}-${BUILD_DATE}"
    local package_path="${DIST_DIR}/${package_name}.tar.gz"
    
    print_step "创建架构 ${arch} 的发布包..."
    
    # 创建临时目录结构
    local temp_dir=$(mktemp -d)
    mkdir -p "${temp_dir}/lib/${arch}"
    mkdir -p "${temp_dir}/include"
    
    # 复制库文件
    cp -r "${INSTALL_DIR}/${arch}/lib"/* "${temp_dir}/lib/${arch}/" 2>/dev/null || true
    
    # 复制头文件（只复制一次，因为所有架构头文件相同）
    if [[ -d "${INSTALL_DIR}/${arch}/include" ]]; then
        cp -r "${INSTALL_DIR}/${arch}/include"/* "${temp_dir}/include/" 2>/dev/null || true
    fi
    
    # 创建打包
    cd "$temp_dir"
    tar -czf "$package_path" lib include
    
    if [[ -f "$package_path" ]]; then
        print_success "架构 ${arch} 的发布包创建成功"
        echo "  文件: $(basename "$package_path")"
        echo "  大小: $(du -h "$package_path" | cut -f1)"
        echo "  位置: $package_path"
    else
        print_error "架构 ${arch} 的发布包创建失败"
    fi
    
    # 清理临时目录
    rm -rf "$temp_dir"
    cd "$PROJECT_ROOT"
}

build_only() {
    print_header
    echo "开始编译流程（使用现有源码）"
    echo ""
    
    # 检查源码是否存在
    if [[ ! -d "$EXTRACT_DIR" ]] || [[ -z "$(ls -A "$EXTRACT_DIR" 2>/dev/null)" ]]; then
        print_error "源码不存在，请按以下步骤操作："
        echo "  1. 从官方网站下载所需源码压缩包（支持任意文件名）"
        echo "  2. 需要的库：openssl, zlib, sqlite, icu, protobuf, libphonenumber"
        echo "             crc32c, xxhash, abseil, re2, libevent, lz4, snappy"
        echo "             double-conversion, tdlib"
        echo "  3. 将压缩包放到目录: $DOWNLOAD_DIR"
        echo "  4. 运行 ./builder.sh --full 自动解压并编译"
        echo ""
        echo "  支持的压缩格式：.tar.gz, .tgz, .tar.bz2, .tar.xz, .zip, .tar"
        echo "  解压后直接使用原目录名，无需重命名"
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
# 仅解压功能
# ============================================

extract_only() {
    print_header
    echo "仅解压源码"
    echo ""
    
    if extract_sources; then
        print_success "源码解压完成"
    else
        print_error "源码解压失败"
    fi
}

# ============================================
# 精确清理功能
# ============================================

clean_build_only() {
    print_header
    echo "清理构建目录"
    echo ""
    
    echo "将删除目录: $BUILD_DIR"
    echo ""
    
    read -p "确定要清理吗？(y/N): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        echo "取消清理"
        return 0
    fi
    
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
        print_success "构建目录已清理"
    else
        echo "构建目录不存在，无需清理"
    fi
}

clean_install_only() {
    print_header
    echo "清理安装目录"
    echo ""
    
    echo "将删除目录: $INSTALL_DIR"
    echo ""
    
    read -p "确定要清理吗？(y/N): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        echo "取消清理"
        return 0
    fi
    
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        print_success "安装目录已清理"
    else
        echo "安装目录不存在，无需清理"
    fi
}

clean_extract_only() {
    print_header
    echo "清理解压目录"
    echo ""
    
    echo "将删除目录: $EXTRACT_DIR"
    echo ""
    
    read -p "确定要清理吗？(y/N): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        echo "取消清理"
        return 0
    fi
    
    if [[ -d "$EXTRACT_DIR" ]]; then
        rm -rf "$EXTRACT_DIR"
        print_success "解压目录已清理"
    else
        echo "解压目录不存在，无需清理"
    fi
}

clean_dist_only() {
    print_header
    echo "清理发布包目录"
    echo ""
    
    echo "将删除目录: $DIST_DIR"
    echo ""
    
    read -p "确定要清理吗？(y/N): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        echo "取消清理"
        return 0
    fi
    
    if [[ -d "$DIST_DIR" ]]; then
        rm -rf "$DIST_DIR"
        print_success "发布包目录已清理"
    else
        echo "发布包目录不存在，无需清理"
    fi
}

clean_logs_only() {
    print_header
    echo "清理日志目录"
    echo ""
    
    echo "将删除目录: $LOGS_DIR"
    echo ""
    
    read -p "确定要清理吗？(y/N): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        echo "取消清理"
        return 0
    fi
    
    if [[ -d "$LOGS_DIR" ]]; then
        rm -rf "$LOGS_DIR"
        print_success "日志目录已清理"
    else
        echo "日志目录不存在，无需清理"
    fi
}

clean_selected() {
    print_header
    echo "精确清理 - 选择要清理的内容:"
    echo ""
    echo -e "  ${GREEN}1.${NC} 清理构建目录 ($BUILD_DIR)"
    echo -e "  ${GREEN}2.${NC} 清理安装目录 ($INSTALL_DIR)"
    echo -e "  ${GREEN}3.${NC} 清理解压目录 ($EXTRACT_DIR)"
    echo -e "  ${GREEN}4.${NC} 清理发布包目录 ($DIST_DIR)"
    echo -e "  ${GREEN}5.${NC} 清理日志目录 ($LOGS_DIR)"
    echo -e "  ${GREEN}6.${NC} 清理所有内容（以上全部）"
    echo -e "  ${GREEN}0.${NC} 返回"
    echo ""
    
    read -p "请输入选项 [0-6]: " choice
    echo ""
    
    case $choice in
        1)
            clean_build_only
            ;;
        2)
            clean_install_only
            ;;
        3)
            clean_extract_only
            ;;
        4)
            clean_dist_only
            ;;
        5)
            clean_logs_only
            ;;
        6)
            clean_only
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效的选项"
            sleep 2
            clean_selected
            ;;
    esac
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
    while true; do
        clear
        print_header
        
        echo "主菜单 - 请选择操作类型:"
        echo ""
        echo -e "  ${GREEN}1.${NC} 构建操作"
        echo -e "  ${GREEN}2.${NC} 清理操作"
        echo -e "  ${GREEN}3.${NC} 测试操作"
        echo -e "  ${GREEN}4.${NC} 系统信息"
        echo -e "  ${GREEN}0.${NC} 退出"
        echo ""
        
        read -p "请输入选项 [0-4]: " choice
        echo ""
        
        case $choice in
            1)
                show_build_menu
                ;;
            2)
                show_clean_menu
                ;;
            3)
                show_test_menu
                ;;
            4)
                show_system_info
                read -p "按回车键返回主菜单..."
                ;;
            0)
                echo "再见！"
                exit 0
                ;;
            *)
                print_error "无效的选项"
                sleep 2
                ;;
        esac
    done
}

# ============================================
# 构建操作子菜单
# ============================================

show_build_menu() {
    while true; do
        clear
        print_header
        
        echo "构建操作 - 请选择:"
        echo ""
        echo -e "${CYAN}完整流程:${NC}"
        echo -e "  ${GREEN}1.${NC} 完整构建（所有架构）"
        echo -e "  ${GREEN}2.${NC} 完整构建（单个架构）"
        echo ""
        echo -e "${CYAN}分步执行（所有架构）:${NC}"
        echo -e "  ${GREEN}3.${NC} 仅解压源码"
        echo -e "  ${GREEN}4.${NC} 仅编译（使用现有源码）"
        echo -e "  ${GREEN}5.${NC} 仅打包已编译的库"
        echo ""
        echo -e "${CYAN}分步执行（单个架构）:${NC}"
        echo -e "  ${GREEN}6.${NC} 仅编译单个架构"
        echo -e "  ${GREEN}7.${NC} 仅打包单个架构"
        echo ""
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        read -p "请输入选项 [0-7]: " choice
        echo ""
        
        case $choice in
            1)
                full_build
                read -p "按回车键返回..."
                return
                ;;
            2)
                echo "选择要构建的架构:"
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
                read -p "按回车键返回..."
                return
                ;;
            3)
                extract_only
                read -p "按回车键返回..."
                return
                ;;
            4)
                build_only
                read -p "按回车键返回..."
                return
                ;;
            5)
                package_distribution
                read -p "按回车键返回..."
                return
                ;;
            6)
                build_single_arch_only
                read -p "按回车键返回..."
                return
                ;;
            7)
                package_single_arch
                read -p "按回车键返回..."
                return
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选项"
                sleep 2
                ;;
        esac
    done
}

# ============================================
# 清理操作子菜单
# ============================================

show_clean_menu() {
    while true; do
        clear
        print_header
        
        echo "清理操作 - 请选择:"
        echo ""
        echo -e "${CYAN}精确清理:${NC}"
        echo -e "  ${GREEN}1.${NC} 清理构建目录"
        echo -e "  ${GREEN}2.${NC} 清理安装目录"
        echo -e "  ${GREEN}3.${NC} 清理解压目录"
        echo -e "  ${GREEN}4.${NC} 清理发布包目录"
        echo -e "  ${GREEN}5.${NC} 清理日志目录"
        echo ""
        echo -e "${CYAN}批量清理:${NC}"
        echo -e "  ${GREEN}6.${NC} 清理所有构建产物（构建+安装）"
        echo -e "  ${GREEN}7.${NC} 清理所有内容（全部目录）"
        echo ""
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        read -p "请输入选项 [0-7]: " choice
        echo ""
        
        case $choice in
            1)
                clean_build_only
                read -p "按回车键返回..."
                ;;
            2)
                clean_install_only
                read -p "按回车键返回..."
                ;;
            3)
                clean_extract_only
                read -p "按回车键返回..."
                ;;
            4)
                clean_dist_only
                read -p "按回车键返回..."
                ;;
            5)
                clean_logs_only
                read -p "按回车键返回..."
                ;;
            6)
                echo "这将删除以下目录:"
                echo "  • $BUILD_DIR"
                echo "  • $INSTALL_DIR"
                echo ""
                read -p "确定要清理吗？(y/N): " confirm
                if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
                    if [[ -d "$BUILD_DIR" ]]; then rm -rf "$BUILD_DIR"; fi
                    if [[ -d "$INSTALL_DIR" ]]; then rm -rf "$INSTALL_DIR"; fi
                    print_success "构建产物已清理"
                else
                    echo "取消清理"
                fi
                read -p "按回车键返回..."
                ;;
            7)
                clean_only
                read -p "按回车键返回..."
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选项"
                sleep 2
                ;;
        esac
    done
}

# ============================================
# 测试操作子菜单
# ============================================

show_test_menu() {
    while true; do
        clear
        print_header
        
        echo "测试操作 - 请选择:"
        echo ""
        echo -e "  ${GREEN}1.${NC} 运行所有测试"
        echo -e "  ${GREEN}2.${NC} 运行指定架构测试"
        echo ""
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        read -p "请输入选项 [0-2]: " choice
        echo ""
        
        case $choice in
            1)
                run_tests
                read -p "按回车键返回..."
                return
                ;;
            2)
                echo "选择要测试的架构:"
                echo "  1) arm64-v8a"
                echo "  2) armeabi-v7a"
                echo "  3) x86_64"
                echo ""
                read -p "请输入选项 [1-3]: " arch_choice
                
                case $arch_choice in
                    1) run_single_arch_test "arm64-v8a" ;;
                    2) run_single_arch_test "armeabi-v7a" ;;
                    3) run_single_arch_test "x86_64" ;;
                    *) print_error "无效的选项" ;;
                esac
                read -p "按回车键返回..."
                return
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选项"
                sleep 2
                ;;
        esac
    done
}

run_single_arch_test() {
    local arch=$1
    
    print_header
    echo "运行架构 $arch 的测试"
    echo ""
    
    if [[ -d "${INSTALL_DIR}/${arch}" ]]; then
        echo "测试架构: $arch"
        
        if [[ -f "${TESTS_DIR}/test_tdlib_basic.sh" ]]; then
            bash "${TESTS_DIR}/test_tdlib_basic.sh" "$arch"
        else
            print_warning "测试脚本不存在: ${TESTS_DIR}/test_tdlib_basic.sh"
        fi
    else
        print_error "架构 $arch 尚未编译，请先编译"
    fi
}

# ============================================
# 命令行参数处理
# ============================================

show_help() {
    print_header
    
    echo "用法: $0 [选项]"
    echo ""
    echo "完整构建:"
    echo "  --full            完整构建流程（解压 → 编译 → 打包）"
    echo "  --arch=ARCH       指定构建的架构（编译+打包）"
    echo ""
    echo "分步执行（所有架构）:"
    echo "  --extract         仅解压源码"
    echo "  --build           仅编译现有源码（所有架构）"
    echo "  --package         仅打包已编译的库（所有架构）"
    echo ""
    echo "分步执行（单个架构）:"
    echo "  --build-arch=ARCH 仅编译指定架构"
    echo "  --package-arch=ARCH 仅打包指定架构"
    echo ""
    echo "清理选项:"
    echo "  --clean           清理所有构建文件"
    echo "  --clean-build     仅清理构建目录"
    echo "  --clean-install   仅清理安装目录"
    echo "  --clean-extract   仅清理解压目录"
    echo "  --clean-dist      仅清理发布包目录"
    echo "  --clean-logs      仅清理日志目录"
    echo ""
    echo "测试选项:"
    echo "  --test            运行所有测试"
    echo "  --test-arch=ARCH  运行指定架构测试"
    echo ""
    echo "其他选项:"
    echo "  --info            显示系统信息"
    echo "  --help, -h        显示此帮助信息"
    echo ""
    echo "架构选项:"
    echo "  arm64-v8a, armeabi-v7a, x86_64"
    echo ""
    echo "示例:"
    echo "  $0                            # 启动交互式菜单"
    echo "  $0 --full                     # 完整构建所有架构"
    echo "  $0 --extract                  # 仅解压源码"
    echo "  $0 --build                    # 仅编译所有架构"
    echo "  $0 --arch=arm64-v8a           # 构建单个架构（编译+打包）"
    echo "  $0 --build-arch=arm64-v8a     # 仅编译单个架构"
    echo "  $0 --package-arch=arm64-v8a   # 仅打包单个架构"
    echo "  $0 --clean-build              # 仅清理构建目录"
    echo "  $0 --clean-install            # 仅清理安装目录"
    echo "  $0 --test-arch=arm64-v8a      # 测试指定架构"
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
        --extract)
            extract_only
            exit $?
            ;;
        --build)
            build_only
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
        --clean-build)
            clean_build_only
            exit $?
            ;;
        --clean-install)
            clean_install_only
            exit $?
            ;;
        --clean-extract)
            clean_extract_only
            exit $?
            ;;
        --clean-dist)
            clean_dist_only
            exit $?
            ;;
        --clean-logs)
            clean_logs_only
            exit $?
            ;;
        --clean-select)
            clean_selected
            exit $?
            ;;
        --test)
            run_tests
            exit $?
            ;;
        --test-arch=*)
            run_single_arch_test "${1#*=}"
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
        --build-arch=*)
            build_single_arch "${1#*=}"
            exit $?
            ;;
        --package-arch=*)
            ARCHITECTURES=("${1#*=}")
            package_single_arch_direct "${1#*=}"
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