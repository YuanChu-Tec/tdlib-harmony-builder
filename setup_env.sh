#!/bin/bash
# TDLib for HarmonyOS 环境设置脚本

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# ============================================
# 打印函数
# ============================================

print_env_header() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                TDLib for HarmonyOS 环境设置                     ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_env_step() {
    echo "▶ $1"
}

print_env_success() {
    echo "✅ $1"
}

print_env_warning() {
    echo "⚠  $1"
}

print_env_error() {
    echo "❌ $1"
}

# ============================================
# 环境检查函数
# ============================================

check_os_compatibility() {
    print_env_step "检查操作系统兼容性..."
    
    local os_name=$(uname -s)
    local os_arch=$(uname -m)
    
    case $os_name in
        Linux)
            print_env_success "操作系统: Linux"
            ;;
        Darwin)
            print_env_success "操作系统: macOS"
            ;;
        *)
            print_env_error "不支持的操作系统: $os_name"
            echo "仅支持 Linux 和 macOS 系统"
            return 1
            ;;
    esac
    
    case $os_arch in
        x86_64)
            print_env_success "系统架构: x86_64"
            ;;
        aarch64|arm64)
            print_env_success "系统架构: $os_arch"
            ;;
        *)
            print_env_warning "未充分测试的架构: $os_arch"
            ;;
    esac
    
    return 0
}

check_system_resources() {
    print_env_step "检查系统资源..."
    
    # 检查内存
    local total_mem=0
    if [[ "$(uname -s)" == "Linux" ]]; then
        total_mem=$(free -m | awk '/^Mem:/{print $2}')
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        total_mem=$(sysctl -n hw.memsize | awk '{print $1/1024/1024}')
    fi
    
    if [[ $total_mem -lt 4096 ]]; then
        print_env_warning "内存较低: ${total_mem}MB (建议 8GB+)"
    else
        print_env_success "内存: ${total_mem}MB"
    fi
    
    # 检查磁盘空间
    local available_space=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt 20 ]]; then
        print_env_warning "磁盘空间较少: ${available_space}GB (建议 50GB+)"
    else
        print_env_success "可用磁盘空间: ${available_space}GB"
    fi
    
    # 检查CPU核心数
    local cpu_cores=0
    if [[ "$(uname -s)" == "Linux" ]]; then
        cpu_cores=$(nproc)
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        cpu_cores=$(sysctl -n hw.ncpu)
    fi
    
    print_env_success "CPU 核心数: $cpu_cores"
    
    return 0
}

check_required_tools() {
    print_env_step "检查必要工具..."
    
    local required_tools=(
        "curl" "wget" "tar" "git"
        "cmake" "make" "ninja" "pkg-config"
        "autoconf" "automake" "libtool"
        "python3" "patch"
    )
    
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        print_env_success "所有必要工具已安装"
        return 0
    else
        print_env_warning "缺少以下工具: ${missing_tools[*]}"
        return 1
    fi
}

# ============================================
# 依赖安装函数
# ============================================

install_system_dependencies() {
    print_env_step "安装系统依赖包..."
    
    if [[ "$(uname -s)" == "Linux" ]]; then
        # 检测Linux发行版
        if command -v apt-get &> /dev/null; then
            # Ubuntu/Debian
            echo "检测到 Debian/Ubuntu 系统"
            sudo apt-get update
            sudo apt-get install -y \
                build-essential \
                curl wget tar unzip \
                git cmake ninja-build pkg-config \
                autoconf automake libtool \
                python3 python3-pip \
                gperf bison flex \
                texinfo help2man gawk \
                libncurses5-dev \
                libgmp-dev libmpfr-dev libmpc-dev \
                gettext
            
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL/Fedora
            echo "检测到 RHEL/CentOS/Fedora 系统"
            sudo yum install -y \
                gcc-c++ make \
                curl wget tar unzip \
                git cmake ninja-build pkg-config \
                autoconf automake libtool \
                python3 python3-pip \
                gperf bison flex \
                texinfo help2man gawk \
                ncurses-devel \
                gmp-devel mpfr-devel libmpc-devel \
                gettext
        else
            print_env_error "不支持的Linux发行版"
            return 1
        fi
        
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS
        echo "检测到 macOS 系统"
        
        # 检查Homebrew
        if ! command -v brew &> /dev/null; then
            print_env_error "请先安装 Homebrew (https://brew.sh/)"
            return 1
        fi
        
        brew install \
            cmake ninja pkg-config \
            autoconf automake libtool \
            python gperf bison flex \
            gawk gmp mpfr libmpc \
            gettext
        
    else
        print_env_error "不支持的操作系统"
        return 1
    fi
    
    print_env_success "系统依赖安装完成"
    return 0
}

# ============================================
# HarmonyOS NDK 安装
# ============================================

install_harmony_ndk() {
    print_env_step "安装 HarmonyOS NDK..."
    
    # 检查是否已安装
    if [[ -d "$OHOS_NDK" ]] && [[ -f "$OHOS_NDK/build/cmake/ohos.toolchain.cmake" ]]; then
        print_env_success "HarmonyOS NDK 已安装: $OHOS_NDK"
        return 0
    fi
    
    echo ""
    echo "请选择 HarmonyOS NDK 安装方式:"
    echo "1. 自动下载安装 (推荐)"
    echo "2. 手动指定路径"
    echo "3. 跳过 (稍后手动设置)"
    echo ""
    
    read -p "请输入选项 [1-3]: " choice
    
    case $choice in
        1)
            # 自动下载安装
            local ndk_url=""
            local ndk_filename=""
            
            # 根据系统选择下载文件
            if [[ "$(uname -s)" == "Linux" ]]; then
                ndk_url="https://repo.huaweicloud.com/harmonyos/compiler/clang/12.0.1-11633926/linux/clang-12.0.1-11633926-linux-x86_64.tar.gz"
                ndk_filename="clang-12.0.1-11633926-linux-x86_64.tar.gz"
            elif [[ "$(uname -s)" == "Darwin" ]]; then
                ndk_url="https://repo.huaweicloud.com/harmonyos/compiler/clang/12.0.1-11633926/darwin/clang-12.0.1-11633926-darwin-x86_64.tar.gz"
                ndk_filename="clang-12.0.1-11633926-darwin-x86_64.tar.gz"
            else
                print_env_error "不支持的操作系统"
                return 1
            fi
            
            echo "下载 HarmonyOS NDK..."
            mkdir -p "$(dirname "$OHOS_NDK")"
            
            if wget -O "/tmp/$ndk_filename" "$ndk_url"; then
                echo "解压 NDK..."
                tar -xzf "/tmp/$ndk_filename" -C "$(dirname "$OHOS_NDK")"
                
                # 重命名目录
                local extracted_dir="/tmp/$(tar -tzf "/tmp/$ndk_filename" | head -1 | cut -f1 -d"/")"
                if [[ -d "$extracted_dir" ]]; then
                    mv "$extracted_dir" "$OHOS_NDK"
                fi
                
                rm "/tmp/$ndk_filename"
                
                if [[ -f "$OHOS_NDK/build/cmake/ohos.toolchain.cmake" ]]; then
                    print_env_success "HarmonyOS NDK 安装完成: $OHOS_NDK"
                    return 0
                else
                    print_env_error "NDK 安装不完整"
                    return 1
                fi
            else
                print_env_error "NDK 下载失败"
                return 1
            fi
            ;;
            
        2)
            # 手动指定路径
            read -p "请输入 HarmonyOS NDK 路径: " custom_ndk_path
            
            if [[ -d "$custom_ndk_path" ]] && [[ -f "$custom_ndk_path/build/cmake/ohos.toolchain.cmake" ]]; then
                export OHOS_NDK="$custom_ndk_path"
                print_env_success "设置成功: $OHOS_NDK"
                
                # 更新配置文件
                sed -i.bak "s|export OHOS_NDK=.*|export OHOS_NDK=\"$custom_ndk_path\"|" config.sh
                return 0
            else
                print_env_error "无效的 NDK 路径"
                return 1
            fi
            ;;
            
        3)
            print_env_warning "跳过 NDK 安装，请手动设置 OHOS_NDK 环境变量"
            return 1
            ;;
            
        *)
            print_env_error "无效的选项"
            return 1
            ;;
    esac
    
    return 0
}

# ============================================
# 环境变量配置
# ============================================

setup_environment_variables() {
    print_env_step "配置环境变量..."
    
    # 检测用户的 shell
    local shell_rc=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi
    
    echo "检测到 shell 配置文件: $shell_rc"
    
    # 准备环境变量配置
    local env_config="# ============================================
# TDLib for HarmonyOS 环境变量
# 自动生成于: $(date)
# ============================================

export OHOS_NDK=\"$OHOS_NDK\"
export OHOS_SDK=\"$OHOS_SDK\"
export OHOS_API_LEVEL=\"$OHOS_API_LEVEL\"
export TDLIB_BUILDER_ROOT=\"$PROJECT_ROOT\"

# 工具链路径
export TOOLCHAIN_DIR=\"\$OHOS_NDK/toolchains/llvm\"
export PATH=\"\$TOOLCHAIN_DIR/bin:\$PATH\"

# 项目脚本路径
export PATH=\"\$TDLIB_BUILDER_ROOT/scripts:\$PATH\"
export PATH=\"\$TDLIB_BUILDER_ROOT/utils:\$PATH\"

# 编译标志
export C_INCLUDE_PATH=\"\$TOOLCHAIN_DIR/sysroot/usr/include:\$C_INCLUDE_PATH\"
export CPLUS_INCLUDE_PATH=\"\$TOOLCHAIN_DIR/sysroot/usr/include:\$CPLUS_INCLUDE_PATH\"
export LIBRARY_PATH=\"\$TOOLCHAIN_DIR/sysroot/usr/lib:\$LIBRARY_PATH\"

# 别名
alias td-build=\"cd \$TDLIB_BUILDER_ROOT && ./builder.sh\"
alias td-clean=\"cd \$TDLIB_BUILDER_ROOT && ./builder.sh --clean\"
alias td-info=\"cd \$TDLIB_BUILDER_ROOT && ./builder.sh --info\"
"
    
    # 检查是否已经配置
    if grep -q "TDLib for HarmonyOS" "$shell_rc" 2>/dev/null; then
        print_env_success "环境变量已配置 (跳过)"
        return 0
    fi
    
    # 备份原配置文件
    cp "$shell_rc" "${shell_rc}.backup.$(date +%Y%m%d)"
    
    # 添加配置
    echo "$env_config" >> "$shell_rc"
    
    print_env_success "环境变量配置完成"
    echo ""
    echo "请运行以下命令使配置生效:"
    echo "  source $shell_rc"
    echo ""
    
    return 0
}

# ============================================
# 项目初始化
# ============================================

initialize_project() {
    print_env_step "初始化项目..."
    
    # 设置脚本执行权限
    chmod +x "$PROJECT_ROOT"/*.sh 2>/dev/null
    chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null
    chmod +x "$SCRIPTS_DIR"/build/*.sh 2>/dev/null
    chmod +x "$UTILS_DIR"/*.sh 2>/dev/null
    chmod +x "$TESTS_DIR"/*.sh 2>/dev/null
    
    # 创建符号链接（可选）
    if [[ ! -f "/usr/local/bin/td-build" ]]; then
        sudo ln -sf "$PROJECT_ROOT/builder.sh" /usr/local/bin/td-build 2>/dev/null || true
    fi
    
    print_env_success "项目初始化完成"
    return 0
}

# ============================================
# 验证安装
# ============================================

verify_installation() {
    print_env_step "验证安装..."
    
    local all_checks_passed=true
    
    echo ""
    echo "检查项目结构..."
    
    # 检查目录
    local required_dirs=("$DOWNLOAD_DIR" "$BUILD_DIR" "$INSTALL_DIR")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_env_success "目录: $(basename "$dir")"
        else
            print_env_error "目录: $(basename "$dir")"
            all_checks_passed=false
        fi
    done
    
    echo ""
    echo "检查工具..."
    
    # 检查编译器
    if [[ -f "$OHOS_NDK/toolchains/llvm/bin/aarch64-linux-ohos9-clang" ]]; then
        print_env_success "HarmonyOS 编译器"
    else
        print_env_error "HarmonyOS 编译器"
        all_checks_passed=false
    fi
    
    # 检查构建工具
    local build_tools=("cmake" "ninja" "make")
    for tool in "${build_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_env_success "$tool"
        else
            print_env_error "$tool"
            all_checks_passed=false
        fi
    done
    
    echo ""
    if [[ "$all_checks_passed" == true ]]; then
        print_env_success "所有检查通过！环境设置完成。"
        echo ""
        echo "🎉 现在可以开始构建 TDLib:"
        echo "  ./builder.sh --full"
        return 0
    else
        print_env_error "部分检查未通过，请解决上述问题后重试。"
        return 1
    fi
}

# ============================================
# 主流程
# ============================================

main() {
    print_env_header
    
    echo "欢迎使用 TDLib for HarmonyOS 构建系统环境设置！"
    echo ""
    echo "本脚本将引导您完成以下步骤:"
    echo "1. 系统兼容性检查"
    echo "2. 系统资源检查"
    echo "3. 必要工具检查"
    echo "4. 系统依赖安装"
    echo "5. HarmonyOS NDK 安装"
    echo "6. 环境变量配置"
    echo "7. 项目初始化"
    echo "8. 安装验证"
    echo ""
    
    read -p "按回车键开始，或 Ctrl+C 退出..."
    echo ""
    
    # 1. 检查操作系统兼容性
    if ! check_os_compatibility; then
        exit 1
    fi
    
    # 2. 检查系统资源
    check_system_resources
    
    # 3. 检查必要工具
    if ! check_required_tools; then
        echo ""
        read -p "是否自动安装缺失的工具？ [Y/n]: " install_tools
        if [[ "$install_tools" != "n" ]] && [[ "$install_tools" != "N" ]]; then
            if ! install_system_dependencies; then
                print_env_error "工具安装失败，请手动安装"
            fi
        fi
    fi
    
    # 4. 安装HarmonyOS NDK
    if ! install_harmony_ndk; then
        echo ""
        print_env_warning "NDK 安装可能有问题，请确保 OHOS_NDK 环境变量正确设置"
    fi
    
    # 5. 配置环境变量
    echo ""
    read -p "是否配置环境变量到 shell 配置文件？ [Y/n]: " setup_env
    if [[ "$setup_env" != "n" ]] && [[ "$setup_env" != "N" ]]; then
        setup_environment_variables
    fi
    
    # 6. 项目初始化
    initialize_project
    
    # 7. 验证安装
    echo ""
    verify_installation
    
    # 8. 显示总结
    echo ""
    print_env_step "环境设置总结:"
    echo ""
    echo "项目根目录: $PROJECT_ROOT"
    echo "HarmonyOS NDK: $OHOS_NDK"
    echo "API 级别: $OHOS_API_LEVEL"
    echo ""
    echo "下一步操作:"
    echo "1. 如果配置了环境变量，请重新打开终端或运行:"
    echo "   source ~/.bashrc   # 或 source ~/.zshrc"
    echo ""
    echo "2. 开始构建 TDLib:"
    echo "   ./builder.sh --full"
    echo ""
    echo "3. 查看帮助:"
    echo "   ./builder.sh --help"
    echo ""
    
    echo "环境设置完成！"
    return 0
}

# 运行主流程
main "$@"