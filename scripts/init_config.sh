#!/bin/bash
# 初始化用户配置文件脚本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"

CONFIG_EXAMPLE="user_config.sh.example"
USER_CONFIG="user_config.sh"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_step "初始化用户配置文件"

# 检查示例文件是否存在
if [[ ! -f "$PROJECT_ROOT/$CONFIG_EXAMPLE" ]]; then
    log_error "示例配置文件不存在: $CONFIG_EXAMPLE"
    exit 1
fi

# 检查用户配置文件是否已存在
if [[ -f "$PROJECT_ROOT/$USER_CONFIG" ]]; then
    echo ""
    log_warning "用户配置文件已存在: $USER_CONFIG"
    read -p "是否覆盖现有配置文件？ [y/N]: " overwrite
    
    if [[ ! "$overwrite" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        log_info "取消操作"
        exit 0
    fi
    
    # 备份现有配置
    BACKUP_FILE="${USER_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$PROJECT_ROOT/$USER_CONFIG" "$PROJECT_ROOT/$BACKUP_FILE"
    log_info "已备份现有配置到: $BACKUP_FILE"
fi

# 复制示例文件
log_info "创建用户配置文件..."
cp "$PROJECT_ROOT/$CONFIG_EXAMPLE" "$PROJECT_ROOT/$USER_CONFIG"

if [[ $? -eq 0 ]]; then
    log_success "用户配置文件已创建: $USER_CONFIG"
    echo ""
    echo "📝 下一步操作:"
    echo ""
    echo "1. 编辑配置文件:"
    echo "   $EDITOR $USER_CONFIG"
    echo "   或使用你喜欢的编辑器打开 $USER_CONFIG"
    echo ""
    echo "2. 至少需要设置以下路径:"
    echo "   - OHOS_NDK: HarmonyOS NDK 安装路径"
    echo "   - OHOS_API_LEVEL: HarmonyOS API 级别（如 9, 10, 11）"
    echo ""
    echo "3. 可选配置:"
    echo "   - PARALLEL_JOBS: 并行编译任务数（建议: CPU核心数-1）"
    echo "   - ARCHITECTURES: 目标架构（如 arm64-v8a）"
    echo "   - BUILD_MODE: 构建模式（Release 或 Debug）"
    echo ""
    echo "4. 验证配置:"
    echo "   source config.sh && validate_config"
    echo ""
    
    # 尝试自动检测 NDK 路径
    log_info "尝试自动检测 HarmonyOS NDK..."
    
    POSSIBLE_PATHS=(
        "$HOME/harmony/ndk"
        "$HOME/HarmonyOS/ndk"
        "/opt/harmony/ndk"
        "/usr/local/harmony/ndk"
        "$HOME/.harmony/ndk"
    )
    
    FOUND_NDK=""
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [[ -d "$path" ]] && [[ -f "$path/native/build/cmake/ohos.toolchain.cmake" ]] || \
           [[ -f "$path/build/cmake/ohos.toolchain.cmake" ]]; then
            FOUND_NDK="$path"
            break
        fi
    done
    
    if [[ -n "$FOUND_NDK" ]]; then
        log_success "检测到可能的 NDK 路径: $FOUND_NDK"
        echo ""
        read -p "是否使用此路径？ [Y/n]: " use_detected
        
        if [[ ! "$use_detected" =~ ^([nN][oO]|[nN])$ ]]; then
            # 更新配置文件
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s|export OHOS_NDK=.*|export OHOS_NDK=\"$FOUND_NDK\"|" "$PROJECT_ROOT/$USER_CONFIG"
            else
                # Linux
                sed -i "s|export OHOS_NDK=.*|export OHOS_NDK=\"$FOUND_NDK\"|" "$PROJECT_ROOT/$USER_CONFIG"
            fi
            log_success "已自动设置 OHOS_NDK: $FOUND_NDK"
        fi
    else
        log_info "未自动检测到 NDK 路径，请手动设置"
    fi
    
    # 检测 CPU 核心数
    if command -v nproc &> /dev/null; then
        CPU_CORES=$(nproc)
        SUGGESTED_JOBS=$((CPU_CORES - 1))
        if [[ $SUGGESTED_JOBS -lt 1 ]]; then
            SUGGESTED_JOBS=1
        fi
        
        log_info "检测到 CPU 核心数: $CPU_CORES"
        log_info "建议的并行任务数: $SUGGESTED_JOBS"
        
        read -p "是否设置 PARALLEL_JOBS=$SUGGESTED_JOBS？ [Y/n]: " set_jobs
        
        if [[ ! "$set_jobs" =~ ^([nN][oO]|[nN])$ ]]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|export PARALLEL_JOBS=.*|export PARALLEL_JOBS=$SUGGESTED_JOBS|" "$PROJECT_ROOT/$USER_CONFIG"
            else
                sed -i "s|export PARALLEL_JOBS=.*|export PARALLEL_JOBS=$SUGGESTED_JOBS|" "$PROJECT_ROOT/$USER_CONFIG"
            fi
            log_success "已设置 PARALLEL_JOBS: $SUGGESTED_JOBS"
        fi
    fi
    
    echo ""
    log_success "配置文件初始化完成！"
    echo ""
    echo "现在可以编辑 $USER_CONFIG 并根据需要调整配置"
    
else
    log_error "创建配置文件失败"
    exit 1
fi
