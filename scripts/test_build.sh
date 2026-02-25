#!/bin/bash
# 测试构建系统脚本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

log_step "测试构建系统"

# 测试1: 检查配置文件
log_info "测试1: 检查配置文件..."
if [[ -f "config.sh" ]]; then
    source "config.sh"
    log_success "配置文件加载成功"
else
    log_error "配置文件不存在"
    exit 1
fi

# 测试2: 检查工具链
log_info "测试2: 检查工具链..."
if [[ -d "$OHOS_NDK" ]]; then
    log_success "HarmonyOS NDK 路径: $OHOS_NDK"
else
    log_warning "HarmonyOS NDK 未设置或不存在"
fi

# 测试3: 检查脚本文件
log_info "测试3: 检查脚本文件..."
MISSING_SCRIPTS=()

SCRIPTS=(
    "scripts/common.sh"
    "scripts/download_sources.sh"
    "scripts/extract_sources.sh"
    "scripts/apply_patches.sh"
    "scripts/build_all.sh"
    "scripts/verify_build.sh"
    "scripts/package_dist.sh"
    "scripts/build/build_zlib.sh"
    "scripts/build/build_openssl.sh"
    "scripts/build/build_sqlite.sh"
    "scripts/build/build_icu.sh"
    "scripts/build/build_protobuf.sh"
    "scripts/build/build_tdlib.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [[ -f "$script" ]] && [[ -x "$script" ]]; then
        log_success "脚本存在且可执行: $script"
    else
        log_warning "脚本缺失或不可执行: $script"
        MISSING_SCRIPTS+=("$script")
    fi
done

# 测试4: 检查目录结构
log_info "测试4: 检查目录结构..."
DIRS=(
    "$DOWNLOAD_DIR"
    "$EXTRACT_DIR"
    "$BUILD_DIR"
    "$INSTALL_DIR"
    "$DIST_DIR"
    "$PATCHES_DIR"
    "$LOGS_DIR"
    "$SCRIPTS_DIR"
)

for dir in "${DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        log_success "目录存在: $dir"
    else
        log_warning "目录不存在: $dir"
        mkdir -p "$dir"
        log_info "已创建目录: $dir"
    fi
done

# 测试5: 检查补丁文件
log_info "测试5: 检查补丁文件..."
PATCHES=(
    "patches/openssl-harmony.patch"
    "patches/sqlite-harmony.patch"
    "patches/icu-harmony.patch"
)

for patch in "${PATCHES[@]}"; do
    if [[ -f "$patch" ]]; then
        log_success "补丁文件存在: $patch"
    else
        log_warning "补丁文件缺失: $patch"
    fi
done

# 测试6: 测试工具链设置
log_info "测试6: 测试工具链设置..."
if set_toolchain "arm64-v8a" 2>/dev/null; then
    log_success "工具链设置成功"
    log_info "  CC: $CC"
    log_info "  CXX: $CXX"
    log_info "  TARGET_HOST: $TARGET_HOST"
else
    log_warning "工具链设置失败（可能是NDK未配置）"
fi

# 输出测试结果
echo ""
log_step "测试结果:"

if [[ ${#MISSING_SCRIPTS[@]} -eq 0 ]]; then
    log_success "所有测试通过！"
    echo ""
    echo "系统已准备好进行构建。"
    echo ""
    echo "下一步操作:"
    echo "  1. 设置 HarmonyOS NDK: export OHOS_NDK=/path/to/ndk"
    echo "  2. 运行完整构建: ./builder.sh --full"
    echo "  3. 或分步执行: ./scripts/download_sources.sh"
    exit 0
else
    log_warning "部分测试未通过"
    echo ""
    echo "缺失的脚本:"
    for script in "${MISSING_SCRIPTS[@]}"; do
        echo "  • $script"
    done
    exit 1
fi
