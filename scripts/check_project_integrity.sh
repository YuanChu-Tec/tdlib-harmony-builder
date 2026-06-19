#!/bin/bash
# 项目完整性检查脚本
# 检查项目结构、必需文件、脚本完整性等

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"

log_step "项目完整性检查"

ERRORS=0
WARNINGS=0

# ============================================
# 1. 检查必需文件
# ============================================
log_info "检查必需文件..."

REQUIRED_FILES=(
    "config.sh"
    "builder.sh"
    "scripts/common.sh"
    "scripts/download_sources.sh"
    "scripts/extract_sources.sh"
    "scripts/apply_patches.sh"
    "scripts/build_all.sh"
    "scripts/build/build_tdlib.sh"
    "scripts/build/generate_tdlib_api.sh"
    "COMPLETE_BUILD_GUIDE.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        log_success "✅ $file"
    else
        log_error "❌ $file 缺失"
        ((ERRORS++))
    fi
done

# ============================================
# 2. 检查编译脚本
# ============================================
log_info "检查编译脚本..."

BUILD_SCRIPTS=(
    "build_zlib.sh"
    "build_openssl.sh"
    "build_sqlite.sh"
    "build_icu.sh"
    "build_protobuf.sh"
    "build_crc32c.sh"
    "build_xxhash.sh"
    "build_abseil.sh"
    "build_re2.sh"
    "build_libevent.sh"
    "build_lz4.sh"
    "build_snappy.sh"
    "build_double_conversion.sh"
    "build_libphonenumber.sh"
    "build_tdlib.sh"
)

for script in "${BUILD_SCRIPTS[@]}"; do
    script_path="scripts/build/$script"
    if [[ -f "$script_path" ]]; then
        if [[ -x "$script_path" ]]; then
            log_success "✅ $script_path (可执行)"
        else
            log_warning "⚠️  $script_path (不可执行)"
            ((WARNINGS++))
        fi
    else
        log_error "❌ $script_path 缺失"
        ((ERRORS++))
    fi
done

# ============================================
# 3. 检查补丁文件
# ============================================
log_info "检查补丁文件..."

PATCHES=(
    "patches/openssl-harmony.patch"
    "patches/sqlite-harmony.patch"
    "patches/icu-harmony.patch"
    "patches/tdlib-tl-parser-wgetopt-windows.patch"
    "patches/tdlib-harmony-thread-affinity.patch"
    "patches/tdlib-harmony-eventfd-pipe.patch"
    "patches/tdlib-harmony-asyncfilelog-eventfd.patch"
)

for patch in "${PATCHES[@]}"; do
    if [[ -f "$patch" ]]; then
        log_success "✅ $patch"
    else
        log_warning "⚠️  $patch 缺失（可能不需要）"
        ((WARNINGS++))
    fi
done

# ============================================
# 4. 检查目录结构
# ============================================
log_info "检查目录结构..."

REQUIRED_DIRS=(
    "scripts"
    "scripts/build"
    "patches"
    "docs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        log_success "✅ $dir/"
    else
        log_error "❌ $dir/ 缺失"
        ((ERRORS++))
    fi
done

# ============================================
# 5. 检查脚本语法
# ============================================
log_info "检查主要脚本语法..."

MAIN_SCRIPTS=(
    "scripts/common.sh"
    "scripts/build_all.sh"
    "scripts/build/build_tdlib.sh"
    "scripts/build/generate_tdlib_api.sh"
)

for script in "${MAIN_SCRIPTS[@]}"; do
    if bash -n "$script" 2>/dev/null; then
        log_success "✅ $script (语法正确)"
    else
        log_error "❌ $script (语法错误)"
        bash -n "$script" 2>&1 | head -5
        ((ERRORS++))
    fi
done

# ============================================
# 6. 检查配置文件
# ============================================
log_info "检查配置文件..."

if [[ -f "config.sh" ]]; then
    if bash -n "config.sh" 2>/dev/null; then
        log_success "✅ config.sh (语法正确)"
    else
        log_error "❌ config.sh (语法错误)"
        ((ERRORS++))
    fi
else
    log_error "❌ config.sh 缺失"
    ((ERRORS++))
fi

# ============================================
# 7. 检查文档
# ============================================
log_info "检查主要文档..."

if [[ -f "COMPLETE_BUILD_GUIDE.md" ]]; then
    log_success "✅ COMPLETE_BUILD_GUIDE.md"
else
    log_warning "⚠️  COMPLETE_BUILD_GUIDE.md 缺失"
    ((WARNINGS++))
fi

if [[ -f "README.md" ]]; then
    log_success "✅ README.md"
else
    log_warning "⚠️  README.md 缺失"
    ((WARNINGS++))
fi

# ============================================
# 8. 检查工具脚本
# ============================================
log_info "检查工具脚本..."

TOOL_SCRIPTS=(
    "scripts/verify_build.sh"
    "scripts/check_dependencies.sh"
    "scripts/cleanup.sh"
)

for script in "${TOOL_SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        log_success "✅ $script"
    else
        log_warning "⚠️  $script 缺失（可选）"
        ((WARNINGS++))
    fi
done

# ============================================
# 9. 检查 Python 修复脚本
# ============================================
log_info "检查 Python 修复脚本..."

if [[ -f "scripts/fix_wgetopt_c_windows.py" ]]; then
    if command -v python3 &>/dev/null; then
        if python3 -m py_compile "scripts/fix_wgetopt_c_windows.py" 2>/dev/null; then
            log_success "✅ scripts/fix_wgetopt_c_windows.py (语法正确)"
        else
            log_warning "⚠️  scripts/fix_wgetopt_c_windows.py (语法错误)"
            ((WARNINGS++))
        fi
    else
        log_warning "⚠️  Python3 未安装，无法验证 fix_wgetopt_c_windows.py"
        ((WARNINGS++))
    fi
else
    log_warning "⚠️  scripts/fix_wgetopt_c_windows.py 缺失（Windows 下可能需要）"
    ((WARNINGS++))
fi

# ============================================
# 10. 检查 CMake 文件
# ============================================
log_info "检查 CMake 文件..."

if [[ -f "cmake/FindTDLib.cmake" ]]; then
    log_success "✅ cmake/FindTDLib.cmake"
else
    log_warning "⚠️  cmake/FindTDLib.cmake 缺失（可选）"
    ((WARNINGS++))
fi

# ============================================
# 总结
# ============================================
echo ""
log_step "检查完成"

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    log_success "✅ 项目完整性检查通过：无错误，无警告"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    log_warning "⚠️  项目完整性检查完成：无错误，但有 $WARNINGS 个警告"
    exit 0
else
    log_error "❌ 项目完整性检查失败：发现 $ERRORS 个错误，$WARNINGS 个警告"
    exit 1
fi
