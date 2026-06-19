#!/bin/bash
# 打包发布脚本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ABS="$(cd "$SCRIPTS_ABS/.." && pwd)"
source "${SCRIPTS_ABS}/common.sh"
source "${PROJECT_ABS}/config.sh"

log_step "开始打包发布文件"

# 检查安装目录
if [[ ! -d "$INSTALL_DIR" ]] || [[ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]]; then
    log_error "安装目录为空，请先编译库"
    exit 1
fi

# 如果没有设置 ARCHITECTURES，自动检测已编译的架构
if [[ ${#ARCHITECTURES[@]} -eq 0 ]]; then
    log_info "未设置 ARCHITECTURES，自动检测已编译的架构..."
    ARCHITECTURES=()
    for arch_dir in "$INSTALL_DIR"/*; do
        if [[ -d "$arch_dir" ]]; then
            arch_name=$(basename "$arch_dir")
            if [[ "$arch_name" =~ ^(arm64-v8a|armeabi-v7a|x86_64)$ ]]; then
                ARCHITECTURES+=("$arch_name")
                log_info "检测到已编译架构: $arch_name"
            fi
        fi
    done
    
    if [[ ${#ARCHITECTURES[@]} -eq 0 ]]; then
        log_error "未找到已编译的架构，请先编译库"
        exit 1
    fi
fi

# 创建发布包目录
PACKAGE_NAME="${PROJECT_NAME}-${PROJECT_VERSION}-${BUILD_DATE}"
PACKAGE_DIR="${DIST_DIR}/${PACKAGE_NAME}"

log_info "创建发布包: $PACKAGE_NAME"
log_info "打包架构: ${ARCHITECTURES[*]}"

# 清理旧包
rm -rf "$PACKAGE_DIR"
ensure_dir "$PACKAGE_DIR"

# 复制所有架构的文件
for arch in "${ARCHITECTURES[@]}"; do
    arch_install_dir="${INSTALL_DIR}/${arch}"
    
    if [[ ! -d "$arch_install_dir" ]]; then
        log_warning "架构 $arch 未编译，跳过"
        continue
    fi
    
    log_info "打包架构: $arch"
    
    arch_dir="${PACKAGE_DIR}/libs/${arch}"
    ensure_dir "$arch_dir"
    
    # 复制库文件
    if [[ -d "${arch_install_dir}/lib" ]]; then
        cp -r "${arch_install_dir}/lib/"* "$arch_dir/" 2>/dev/null || true
    fi
    if [[ -d "${arch_install_dir}/usr/lib" ]]; then
        cp -r "${arch_install_dir}/usr/lib/"* "$arch_dir/" 2>/dev/null || true
    fi
    
    # 清理不必要的文件
    find "$arch_dir" -name "*.la" -delete 2>/dev/null || true
    find "$arch_dir" -name "*.pc" -delete 2>/dev/null || true
    
    log_success "架构 $arch 打包完成"
done

# 复制头文件（使用第一个可用架构）
for arch in "${ARCHITECTURES[@]}"; do
    arch_install_dir="${INSTALL_DIR}/${arch}"
    if [[ -d "${arch_install_dir}/include" ]]; then
        log_info "复制头文件 (来自 $arch)"
        cp -r "${arch_install_dir}/include" "$PACKAGE_DIR/" 2>/dev/null || true
        break
    fi
done

# 复制 CMake 配置文件
if [[ -d "$CMAKE_DIR" ]]; then
    cp -r "$CMAKE_DIR" "$PACKAGE_DIR/" 2>/dev/null || true
fi

# 创建 CMake 配置文件
log_info "创建 CMake 配置文件..."
cat > "$PACKAGE_DIR/tdlib-config.cmake" << EOF
# TDLib for HarmonyOS 配置文件
# 自动生成于: $(date)

# TDLib 源版本（实际 TDLib 源码版本）
set(TDLIB_SOURCE_VERSION "${TDLIB_VERSION}")
# TDLib HarmonyOS 打包版本（包含 HarmonyOS 适配标记）
set(TDLIB_PACKAGE_VERSION "${PROJECT_VERSION}")
# 向后兼容
set(TDLIB_VERSION "${PROJECT_VERSION}")
set(TDLIB_HARMONYOS_API_LEVEL "${OHOS_API_LEVEL}")

# 根据架构设置路径
if(NOT DEFINED OHOS_ARCH_ABI)
    set(OHOS_ARCH_ABI "arm64-v8a")
endif()

set(TDLIB_INCLUDE_DIRS "\${CMAKE_CURRENT_LIST_DIR}/include")
set(TDLIB_LIBRARY_DIRS "\${CMAKE_CURRENT_LIST_DIR}/libs/\${OHOS_ARCH_ABI}")

# 导出变量
set(TDLIB_FOUND TRUE)
message(STATUS "Found TDLib for HarmonyOS: v\${TDLIB_PACKAGE_VERSION} (TDLib source v\${TDLIB_SOURCE_VERSION})")

# TDLib 内部库（按依赖顺序）
set(_TDLIB_LIBS
    tdjson
    tdjson_static
    tdjson_private
    tdclient
    tdcore
    tdapi
    tdactor
    tdnet
    tdutils
    tdmtproto
    tddb
    tdsqlite
    tde2e
    ssl
    crypto
    z
    sqlite3
    icuuc
    icudata
    icui18n
    protobuf
    protobuf-lite
    re2
    crc32c
    xxhash
    event
    event_core
    event_extra
    event_pthreads
    lz4
    snappy
    double-conversion
    phonenumber
)

# 创建导入目标（与 FindTDLib.cmake 一致）
if(NOT TARGET TDLib::TDLib)
    add_library(TDLib::TDLib INTERFACE IMPORTED)
    set_target_properties(TDLib::TDLib PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "\${TDLIB_INCLUDE_DIRS}"
        INTERFACE_LINK_DIRECTORIES "\${TDLIB_LIBRARY_DIRS}"
        INTERFACE_LINK_LIBRARIES "\${_TDLIB_LIBS}"
    )
endif()

# 兼容旧的函数调用方式
function(tdlib_target_link_libraries TARGET)
    target_link_libraries(\${TARGET} TDLib::TDLib)
endfunction()
EOF

# 创建 README
log_info "创建 README..."
cat > "$PACKAGE_DIR/README.md" << EOF
# TDLib for HarmonyOS

## 版本信息
- TDLib源版本: ${TDLIB_VERSION}
- HarmonyOS适配版本: ${PROJECT_VERSION}
- HarmonyOS API级别: ${OHOS_API_LEVEL}
- 构建日期: ${BUILD_DATE}
- 包含架构: ${ARCHITECTURES[*]}

## 包含的库
- OpenSSL ${OPENSSL_VERSION}
- zlib ${ZLIB_VERSION}
- SQLite ${SQLITE_VERSION}
- ICU ${ICU_VERSION}
- Protocol Buffers ${PROTOBUF_VERSION}
- libphonenumber ${LIBPHONENUMBER_VERSION}
- RE2 ${RE2_VERSION}
- libevent ${LIBEVENT_VERSION}
- 以及其他必要的依赖库

## 使用方法

### CMake项目
\`\`\`cmake
# 方法1: 使用 find_package(tdlib)（配置模式）
list(APPEND CMAKE_PREFIX_PATH "\${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/tdlib-harmonyos")

# 方法2: 使用 find_package(TDLib)（模块模式）
list(APPEND CMAKE_MODULE_PATH "\${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/tdlib-harmonyos/cmake")

# 设置目标架构（必须）
set(OHOS_ARCH_ABI "arm64-v8a")  # 可选: arm64-v8a, armeabi-v7a, x86_64

find_package(tdlib REQUIRED)

# 链接到你的目标（两种方式任选）
target_link_libraries(your_target TDLib::TDLib)        # 推荐方式
# tdlib_target_link_libraries(your_target)              # 兼容方式
\`\`\`

### 手动使用
\`\`\`bash
# 设置环境变量
export OHOS_ARCH_ABI=arm64-v8a  # 可选: arm64-v8a, armeabi-v7a, x86_64
export C_INCLUDE_PATH="\${TDLIB_PATH}/include:\${C_INCLUDE_PATH}"
export CPLUS_INCLUDE_PATH="\${TDLIB_PATH}/include:\${CPLUS_INCLUDE_PATH}"
export LIBRARY_PATH="\${TDLIB_PATH}/libs/\${OHOS_ARCH_ABI}:\${LIBRARY_PATH}"

# 编译
clang++ -std=c++17 -I\${TDLIB_PATH}/include -L\${TDLIB_PATH}/libs/\${OHOS_ARCH_ABI} \\
    your_app.cpp -o your_app \\
    -ltdjson -ltdclient -ltdcore -ltdapi \\
    -lssl -lcrypto -lsqlite3 -lprotobuf \\
    -licuuc -licudata -licui18n \\
    -levent -levent_pthreads \\
    -lre2 -lcrc32c -lxxhash -llz4 -lsnappy \\
    -ldouble-conversion -lphonenumber
\`\`\`

## 许可证
各库有其自己的许可证，请参考各库的LICENSE文件。
EOF

# 创建压缩包
log_info "创建压缩包..."
cd "$DIST_DIR" || exit 1

if command -v tar &> /dev/null; then
    tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log_success "压缩包创建成功"
        
        # 生成SHA256校验和
        if command -v sha256sum &> /dev/null; then
            sha256sum "${PACKAGE_NAME}.tar.gz" > "${PACKAGE_NAME}.tar.gz.sha256"
            log_info "SHA256 校验和: $(cat "${PACKAGE_NAME}.tar.gz.sha256" | cut -d' ' -f1)"
        fi
        
        # 显示打包信息
        echo ""
        log_step "打包信息:"
        echo "  文件: ${PACKAGE_NAME}.tar.gz"
        echo "  大小: $(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)"
        echo "  位置: $DIST_DIR"
        echo ""
    else
        log_error "压缩包创建失败"
        exit 1
    fi
else
    log_warning "tar 命令不可用，跳过压缩包创建"
    log_info "发布包目录: $PACKAGE_DIR"
fi

log_success "打包完成"
