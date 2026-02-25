# 完整路径配置代码文档

本文档包含项目中所有可自定义的路径配置代码。

## 📋 目录

1. [用户配置文件路径](#用户配置文件路径)
2. [主配置文件路径](#主配置文件路径)
3. [工具链路径检测](#工具链路径检测)
4. [编译器路径配置](#编译器路径配置)
5. [构建目录路径](#构建目录路径)
6. [完整配置示例](#完整配置示例)

---

## 1. 用户配置文件路径

### 文件位置: `user_config.sh`

```bash
#!/bin/bash
# ============================================
# HarmonyOS 开发环境路径
# ============================================

# HarmonyOS NDK 路径（必需）
# Windows OpenHarmony SDK 路径示例
export OHOS_NDK="${OHOS_NDK:-C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20/native}"

# Linux/macOS 路径示例
# export OHOS_NDK="${OHOS_NDK:-/home/user/harmony/ndk}"

# HarmonyOS SDK 路径（可选）
export OHOS_SDK="${OHOS_SDK:-C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20}"

# HarmonyOS API 级别
export OHOS_API_LEVEL="${OHOS_API_LEVEL:-20}"

# ============================================
# 路径配置（高级，通常不需要修改）
# ============================================

# 项目根目录（自动检测，通常不需要修改）
# export PROJECT_ROOT=""

# 源码下载目录（相对于项目根目录）
# 默认: src/downloads
# export DOWNLOAD_DIR=""

# 源码解压目录（相对于项目根目录）
# 默认: src/extracted
# export EXTRACT_DIR=""

# 构建目录（相对于项目根目录）
# 默认: build
# export BUILD_DIR=""

# 安装目录（相对于项目根目录）
# 默认: install
# export INSTALL_DIR=""

# 发布包目录（相对于项目根目录）
# 默认: dist
# export DIST_DIR=""

# 日志目录（相对于项目根目录）
# 默认: logs
# export LOGS_DIR=""
```

---

## 2. 主配置文件路径

### 文件位置: `config.sh`

```bash
#!/bin/bash
# ============================================
# 路径配置
# ============================================

# 项目根目录（自动检测）
export PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# 源码目录
export SOURCE_DIR="${PROJECT_ROOT}/src"
export DOWNLOAD_DIR="${SOURCE_DIR}/downloads"
export EXTRACT_DIR="${SOURCE_DIR}/extracted"

# 构建目录
export BUILD_DIR="${PROJECT_ROOT}/build"
export INSTALL_DIR="${PROJECT_ROOT}/install"
export DIST_DIR="${PROJECT_ROOT}/dist"

# 脚本和补丁目录
export SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
export PATCHES_DIR="${PROJECT_ROOT}/patches"
export LOGS_DIR="${PROJECT_ROOT}/logs"
export CMAKE_DIR="${PROJECT_ROOT}/cmake"

# 创建必要的目录
mkdir -p "${DOWNLOAD_DIR}" "${EXTRACT_DIR}" "${BUILD_DIR}" \
         "${INSTALL_DIR}" "${DIST_DIR}" "${LOGS_DIR}" "${CMAKE_DIR}"

# ============================================
# HarmonyOS 工具链配置
# ============================================

# HarmonyOS NDK 路径（优先使用用户配置，否则使用默认值）
if [[ -z "$OHOS_NDK" ]]; then
    export OHOS_NDK="${OHOS_NDK:-${HOME}/harmony/ndk}"
fi

if [[ -z "$OHOS_SDK" ]]; then
    export OHOS_SDK="${OHOS_SDK:-${HOME}/harmony/sdk}"
fi

if [[ -z "$OHOS_API_LEVEL" ]]; then
    export OHOS_API_LEVEL="${OHOS_API_LEVEL:-9}"
fi

# 工具链路径（根据实际NDK结构调整）
# 支持多种路径结构：
# 1. OpenHarmony SDK 结构: SDK/native/llvm
# 2. 标准 NDK 结构: NDK/native/llvm
# 3. 旧版本结构: NDK/toolchains/llvm

# 首先尝试 OpenHarmony SDK 结构（如果 NDK 路径已经包含 native）
if [[ "$OHOS_NDK" == *"/native" ]] || [[ "$OHOS_NDK" == *"\\native" ]]; then
    # NDK 路径已经指向 native 目录
    export TOOLCHAIN_DIR="${OHOS_NDK}/llvm"
    export SYSROOT="${OHOS_NDK}/sysroot"
else
    # 标准结构：NDK/native/llvm
    export TOOLCHAIN_DIR="${OHOS_NDK}/native/llvm"
    export SYSROOT="${OHOS_NDK}/native/sysroot"
fi

# 如果上述路径不存在，尝试其他可能的结构
if [[ ! -d "$TOOLCHAIN_DIR" ]]; then
    # 尝试旧版本结构
    export TOOLCHAIN_DIR="${OHOS_NDK}/toolchains/llvm"
    export SYSROOT="${TOOLCHAIN_DIR}/sysroot"
    
    # 如果还是不存在，尝试直接使用 NDK 路径下的 llvm
    if [[ ! -d "$TOOLCHAIN_DIR" ]]; then
        export TOOLCHAIN_DIR="${OHOS_NDK}/llvm"
        export SYSROOT="${OHOS_NDK}/sysroot"
    fi
fi
```

---

## 3. 工具链路径检测

### 文件位置: `scripts/get_toolchain_file.sh`

```bash
#!/bin/bash
# 获取工具链文件路径的辅助函数

get_toolchain_file() {
    local ndk_path="${1:-$OHOS_NDK}"
    
    if [[ -z "$ndk_path" ]] || [[ ! -d "$ndk_path" ]]; then
        return 1
    fi
    
    # 转换 Windows 路径格式（统一使用正斜杠）
    ndk_path=$(echo "$ndk_path" | sed 's|\\|/|g')
    
    # 尝试多种可能的工具链文件路径
    local toolchain_files=(
        "${ndk_path}/build/cmake/ohos.toolchain.cmake"  # OpenHarmony SDK 结构（如果 NDK 指向 native 目录）
        "${ndk_path}/native/build/cmake/ohos.toolchain.cmake"  # 标准结构（如果 NDK 指向 SDK 根目录）
        "${ndk_path}/../build/cmake/ohos.toolchain.cmake"  # 如果 NDK 指向 native/llvm 等子目录
    )
    
    # 如果 NDK 路径包含 "native"，优先尝试直接使用 build/cmake 路径
    if [[ "$ndk_path" == *"/native" ]] || [[ "$ndk_path" == *"\\native" ]]; then
        toolchain_files=(
            "${ndk_path}/build/cmake/ohos.toolchain.cmake"
            "${toolchain_files[@]}"
        )
    fi
    
    # 查找存在的工具链文件
    for toolchain_file in "${toolchain_files[@]}"; do
        toolchain_file=$(echo "$toolchain_file" | sed 's|\\|/|g')
        if [[ -f "$toolchain_file" ]]; then
            echo "$toolchain_file"
            return 0
        fi
    done
    
    return 1
}
```

### 在 config.sh 中的使用

```bash
# 检查工具链文件
if [[ -n "$OHOS_NDK" ]] && [[ -d "$OHOS_NDK" ]]; then
    # 使用 get_toolchain_file 函数查找工具链文件
    if command -v get_toolchain_file &> /dev/null; then
        local toolchain_file=$(get_toolchain_file "$OHOS_NDK")
    else
        # 回退到直接检查
        local ndk_path=$(echo "$OHOS_NDK" | sed 's|\\|/|g')
        local toolchain_file=""
        
        if [[ "$ndk_path" == *"/native" ]] || [[ "$ndk_path" == *"\\native" ]]; then
            toolchain_file="${ndk_path}/build/cmake/ohos.toolchain.cmake"
        else
            toolchain_file="${ndk_path}/native/build/cmake/ohos.toolchain.cmake"
        fi
        
        if [[ ! -f "$toolchain_file" ]]; then
            toolchain_file="${ndk_path}/build/cmake/ohos.toolchain.cmake"
        fi
    fi
    
    if [[ -n "$toolchain_file" ]] && [[ -f "$toolchain_file" ]]; then
        echo "✅ 工具链文件: $toolchain_file"
        export OHOS_TOOLCHAIN_FILE="$toolchain_file"
    fi
fi
```

---

## 4. 编译器路径配置

### 文件位置: `config.sh` 中的 `set_toolchain()` 函数

```bash
set_toolchain() {
    local arch=$1
    
    # 检查 NDK 是否存在
    if [[ ! -d "$OHOS_NDK" ]]; then
        echo "❌ HarmonyOS NDK 未找到: $OHOS_NDK" >&2
        return 1
    fi
    
    # 检查工具链目录
    if [[ ! -d "$TOOLCHAIN_DIR" ]]; then
        echo "❌ 工具链目录不存在: $TOOLCHAIN_DIR" >&2
        return 1
    fi
    
    # 根据架构设置工具链
    case $arch in
        arm64-v8a)
            export TARGET_HOST="aarch64-linux-ohos"
            export TOOLCHAIN="aarch64-linux-ohos"
            export CC="${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang"
            export CXX="${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang++"
            export AR="${TOOLCHAIN_DIR}/bin/llvm-ar"
            export RANLIB="${TOOLCHAIN_DIR}/bin/llvm-ranlib"
            export STRIP="${TOOLCHAIN_DIR}/bin/llvm-strip"
            export READELF="${TOOLCHAIN_DIR}/bin/llvm-readelf"
            export LD="${TOOLCHAIN_DIR}/bin/ld.lld"
            ;;
            
        armeabi-v7a)
            export TARGET_HOST="arm-linux-ohos"
            export TOOLCHAIN="arm-linux-ohos"
            export CC="${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang"
            export CXX="${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang++"
            export AR="${TOOLCHAIN_DIR}/bin/llvm-ar"
            export RANLIB="${TOOLCHAIN_DIR}/bin/llvm-ranlib"
            export STRIP="${TOOLCHAIN_DIR}/bin/llvm-strip"
            export READELF="${TOOLCHAIN_DIR}/bin/llvm-readelf"
            export LD="${TOOLCHAIN_DIR}/bin/ld.lld"
            ;;
            
        x86_64)
            export TARGET_HOST="x86_64-linux-ohos"
            export TOOLCHAIN="x86_64-linux-ohos"
            export CC="${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang"
            export CXX="${TOOLCHAIN_DIR}/bin/${TARGET_HOST}${OHOS_API_LEVEL}-clang++"
            export AR="${TOOLCHAIN_DIR}/bin/llvm-ar"
            export RANLIB="${TOOLCHAIN_DIR}/bin/llvm-ranlib"
            export STRIP="${TOOLCHAIN_DIR}/bin/llvm-strip"
            export READELF="${TOOLCHAIN_DIR}/bin/llvm-readelf"
            export LD="${TOOLCHAIN_DIR}/bin/ld.lld"
            ;;
    esac
    
    # 通用标志
    export CFLAGS="${CFLAGS} -D__OHOS__ -D__MUSL__=1 -DNDEBUG -O3 -I${SYSROOT}/usr/include"
    export CXXFLAGS="${CXXFLAGS} -D__OHOS__ -D__MUSL__=1 -DNDEBUG -O3 -I${SYSROOT}/usr/include"
    export LDFLAGS="${LDFLAGS} -L${SYSROOT}/usr/lib --sysroot=${SYSROOT}"
    
    # 构建和安装目录（按架构）
    export ARCH_BUILD_DIR="${BUILD_DIR}/${arch}"
    export ARCH_INSTALL_DIR="${INSTALL_DIR}/${arch}"
    
    mkdir -p "${ARCH_BUILD_DIR}"
    mkdir -p "${ARCH_INSTALL_DIR}"
    
    return 0
}
```

---

## 5. 构建目录路径

### 架构特定的构建目录

```bash
# 在 set_toolchain() 函数中设置
export ARCH_BUILD_DIR="${BUILD_DIR}/${arch}"
export ARCH_INSTALL_DIR="${INSTALL_DIR}/${arch}"

# 示例：
# BUILD_DIR/build/arm64-v8a/
# INSTALL_DIR/install/arm64-v8a/
```

### 在编译脚本中的使用

```bash
# 创建构建目录
BUILD_DIR=$(create_build_dir "zlib" "$ARCH")
cd "$BUILD_DIR" || exit 1

# create_build_dir 函数（在 common.sh 中）
create_build_dir() {
    local lib_name=$1
    local arch=$2
    local build_dir="${BUILD_DIR}/${arch}/${lib_name}"
    mkdir -p "$build_dir"
    echo "$build_dir"
}
```

---

## 6. 完整配置示例

### Windows 环境完整配置

```bash
# user_config.sh

# ============================================
# HarmonyOS 开发环境路径
# ============================================
export OHOS_NDK="C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20/native"
export OHOS_SDK="C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20"
export OHOS_API_LEVEL=20

# ============================================
# 构建配置
# ============================================
export PARALLEL_JOBS=23
export BUILD_MODE="Release"
export ARCHITECTURES="arm64-v8a"

# ============================================
# 自定义路径（可选）
# ============================================
# 如果需要自定义项目路径，取消注释并修改
# export PROJECT_ROOT="/custom/path/to/project"
# export DOWNLOAD_DIR="${PROJECT_ROOT}/custom_downloads"
# export BUILD_DIR="${PROJECT_ROOT}/custom_build"
# export INSTALL_DIR="${PROJECT_ROOT}/custom_install"
```

### Linux/macOS 环境完整配置

```bash
# user_config.sh

# ============================================
# HarmonyOS 开发环境路径
# ============================================
export OHOS_NDK="/home/user/harmony/ndk"
export OHOS_SDK="/home/user/harmony/sdk"
export OHOS_API_LEVEL=9

# ============================================
# 构建配置
# ============================================
export PARALLEL_JOBS=8
export BUILD_MODE="Release"
export ARCHITECTURES="arm64-v8a armeabi-v7a"

# ============================================
# 自定义路径（可选）
# ============================================
# export DOWNLOAD_DIR="/tmp/tdlib_downloads"
# export BUILD_DIR="/tmp/tdlib_build"
# export INSTALL_DIR="/opt/tdlib_harmonyos"
```

---

## 7. 路径变量总结

### 必需路径变量

| 变量名 | 说明 | 默认值 | 配置文件 |
|--------|------|--------|----------|
| `OHOS_NDK` | HarmonyOS NDK 路径 | `${HOME}/harmony/ndk` | `user_config.sh` |
| `OHOS_API_LEVEL` | HarmonyOS API 级别 | `9` | `user_config.sh` |

### 可选路径变量

| 变量名 | 说明 | 默认值 | 配置文件 |
|--------|------|--------|----------|
| `OHOS_SDK` | HarmonyOS SDK 路径 | `${HOME}/harmony/sdk` | `user_config.sh` |
| `PROJECT_ROOT` | 项目根目录 | 自动检测 | `config.sh` |
| `DOWNLOAD_DIR` | 源码下载目录 | `${PROJECT_ROOT}/src/downloads` | `user_config.sh` |
| `EXTRACT_DIR` | 源码解压目录 | `${PROJECT_ROOT}/src/extracted` | `user_config.sh` |
| `BUILD_DIR` | 构建目录 | `${PROJECT_ROOT}/build` | `user_config.sh` |
| `INSTALL_DIR` | 安装目录 | `${PROJECT_ROOT}/install` | `user_config.sh` |
| `DIST_DIR` | 发布包目录 | `${PROJECT_ROOT}/dist` | `user_config.sh` |
| `LOGS_DIR` | 日志目录 | `${PROJECT_ROOT}/logs` | `user_config.sh` |

### 自动生成的路径变量

| 变量名 | 说明 | 生成方式 |
|--------|------|----------|
| `TOOLCHAIN_DIR` | 工具链目录 | 根据 `OHOS_NDK` 自动检测 |
| `SYSROOT` | 系统根目录 | 根据 `OHOS_NDK` 自动检测 |
| `OHOS_TOOLCHAIN_FILE` | 工具链文件路径 | 通过 `get_toolchain_file()` 函数检测 |
| `ARCH_BUILD_DIR` | 架构构建目录 | `${BUILD_DIR}/${arch}` |
| `ARCH_INSTALL_DIR` | 架构安装目录 | `${INSTALL_DIR}/${arch}` |
| `CC`, `CXX`, `AR` 等 | 编译器路径 | 根据架构和 `TOOLCHAIN_DIR` 生成 |

---

## 8. 路径优先级

配置的优先级顺序（从高到低）：

1. **用户配置文件** (`user_config.sh`)
2. **环境变量** (命令行设置的 `export`)
3. **默认值** (在 `config.sh` 中定义)

示例：
```bash
# 优先级1: user_config.sh
export OHOS_NDK="/path/in/user_config"

# 优先级2: 环境变量（会覆盖 user_config.sh）
export OHOS_NDK="/path/in/env"
source config.sh

# 最终使用: /path/in/env
```

---

## 9. 路径验证

### 验证所有路径

```bash
# 加载配置并验证
source config.sh && validate_config
```

### 查看所有路径变量

```bash
source config.sh
echo "项目路径:"
echo "  PROJECT_ROOT: $PROJECT_ROOT"
echo "  DOWNLOAD_DIR: $DOWNLOAD_DIR"
echo "  BUILD_DIR: $BUILD_DIR"
echo "  INSTALL_DIR: $INSTALL_DIR"
echo ""
echo "HarmonyOS 路径:"
echo "  OHOS_NDK: $OHOS_NDK"
echo "  OHOS_SDK: $OHOS_SDK"
echo "  TOOLCHAIN_DIR: $TOOLCHAIN_DIR"
echo "  SYSROOT: $SYSROOT"
echo "  OHOS_TOOLCHAIN_FILE: $OHOS_TOOLCHAIN_FILE"
```

---

## 10. 常见路径问题

### 问题1: Windows 路径格式

**解决方案：** 使用正斜杠或双反斜杠
```bash
# ✅ 正确
export OHOS_NDK="C:/Users/Name/path"
export OHOS_NDK="C:\\Users\\Name\\path"

# ❌ 错误（单反斜杠会被转义）
export OHOS_NDK="C:\Users\Name\path"
```

### 问题2: 路径包含空格

**解决方案：** 使用引号包裹
```bash
export OHOS_NDK="C:/Program Files/Harmony/ndk"
```

### 问题3: 相对路径 vs 绝对路径

**建议：** 使用绝对路径
```bash
# ✅ 推荐（绝对路径）
export OHOS_NDK="/home/user/harmony/ndk"

# ⚠️  可以（相对路径，但可能有问题）
export OHOS_NDK="./harmony/ndk"
```

---

## 📚 相关文档

- [用户配置使用指南](USER_CONFIG.md)
- [工具链路径配置](TOOLCHAIN_PATH.md)
- [配置系统总结](CONFIG_SUMMARY.md)
