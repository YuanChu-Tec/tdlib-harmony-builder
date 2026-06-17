# TDLib for HarmonyOS 完整编译指南

> **版本**: 1.8.0-harmonyos  
> **最后更新**: 2026-01-24  
> **适用平台**: Windows (MSYS2), Linux, macOS

本指南提供 TDLib for HarmonyOS 的完整编译流程，包括环境配置、编译步骤、错误处理和使用方法。

---

## 📋 目录

1. [环境要求](#环境要求)
2. [环境配置](#环境配置)
3. [项目结构](#项目结构)
4. [完整编译流程](#完整编译流程)
5. [分别编译](#分别编译)
6. [清理缓存](#清理缓存)
7. [编译路径说明](#编译路径说明)
8. [编译结果位置](#编译结果位置)
9. [使用编译好的 TDLib](#使用编译好的-tdlib)
10. [常见错误与解决方案](#常见错误与解决方案)
11. [诊断工具](#诊断工具)
12. [项目完整性检查](#项目完整性检查)

---

## 🔧 环境要求

### 硬件要求
- **CPU**: 至少 4 核心（推荐 8 核心以上）
- **内存**: 至少 8GB RAM（推荐 16GB）
- **磁盘空间**: 至少 50GB 可用空间

### 软件要求
- **操作系统**: 
  - Windows 10/11 (使用 MSYS2)
  - Linux (Ubuntu 20.04+, CentOS 8+)
  - macOS (10.15+)
- **必要工具**:
  - Git
  - CMake 3.15+（或使用 OHOS NDK 自带的 CMake）
  - Ninja 或 Make
  - Python 3.6+（用于修复脚本）
- **HarmonyOS NDK**: 
  - 版本: 支持 API Level 9+
  - 路径: 需要包含 `native/llvm/bin/clang` 和 `native/build/cmake/ohos.toolchain.cmake`

---

## ⚙️ 环境配置

### 步骤 1: 获取项目

```bash
# 如果从 Git 克隆
git clone <repository-url>
cd tdlib-harmony-builder

# 或直接使用已有项目目录
cd tdlib-harmony-builder
```

### 步骤 2: 创建用户配置文件

```bash
# 方式 1: 使用初始化脚本（推荐）
./scripts/init_config.sh

# 方式 2: 手动创建
cp user_config.sh.example user_config.sh
```

### 步骤 3: 配置 HarmonyOS NDK 路径

编辑 `user_config.sh`，设置以下**必需**配置：

```bash
# HarmonyOS NDK 路径（必需）
# Windows 示例:
export OHOS_NDK="C:/Users/YourName/AppData/Local/OpenHarmony/Sdk/20/native"
# Linux/macOS 示例:
export OHOS_NDK="/home/user/harmony/ndk"

# HarmonyOS API 级别（必需）
export OHOS_API_LEVEL=20  # 根据你的 SDK 版本设置

# 并行编译任务数（推荐: CPU核心数 - 1）
export PARALLEL_JOBS=7  # 8核CPU示例

# 目标架构（可选，默认: arm64-v8a）
export ARCHITECTURES="arm64-v8a"  # 或 "arm64-v8a armeabi-v7a x86_64"
```

**Windows 路径格式说明**：
- ✅ **推荐**: `C:/Users/YourName/AppData/Local/OpenHarmony/Sdk/20/native`（正斜杠）
- ✅ **也可**: `C:\\Users\\YourName\\AppData\\Local\\OpenHarmony\\Sdk\\20\\native`（转义反斜杠）
- ❌ **错误**: `C:\Users\YourName\...`（未转义的反斜杠在 bash 中会被解释）

### 步骤 4: 验证配置

```bash
source config.sh && validate_config
```

**预期输出**：
```
✅ 已加载用户配置文件: /path/to/user_config.sh
🔍 验证配置...
✅ OHOS_NDK: /path/to/ndk
✅ OHOS_API_LEVEL: 20
✅ PARALLEL_JOBS: 7
✅ 目标架构: arm64-v8a
✅ BUILD_MODE: Release
✅ 配置验证完成: 无错误
```

**如果出现警告**：
- ⚠️ `OHOS_NDK 路径不存在`: 检查路径是否正确，使用正斜杠格式
- ⚠️ `工具链文件不存在`: 确认 NDK 目录结构，检查 `native/build/cmake/ohos.toolchain.cmake` 是否存在

---

## 📁 项目结构

```
tdlib-harmony-builder/
├── config.sh                    # 主配置文件
├── user_config.sh               # 用户配置文件（需创建）
├── user_config.sh.example      # 配置模板
├── builder.sh                   # 主构建脚本
│
├── scripts/                     # 脚本目录
│   ├── common.sh               # 公共函数库
│   ├── download_sources.sh     # 下载源码
│   ├── extract_sources.sh      # 解压源码
│   ├── apply_patches.sh        # 应用补丁
│   ├── build_all.sh            # 编译所有库
│   ├── verify_build.sh         # 验证编译结果
│   ├── cleanup.sh              # 清理构建文件
│   │
│   └── build/                  # 各库编译脚本
│       ├── build_zlib.sh
│       ├── build_openssl.sh
│       ├── build_sqlite.sh
│       ├── build_icu.sh
│       ├── build_protobuf.sh
│       ├── build_crc32c.sh
│       ├── build_xxhash.sh
│       ├── build_abseil.sh
│       ├── build_re2.sh
│       ├── build_libevent.sh
│       ├── build_lz4.sh
│       ├── build_snappy.sh
│       ├── build_double_conversion.sh
│       ├── build_libphonenumber.sh
│       ├── build_tdlib.sh        # TDLib 主编译脚本
│       ├── build_tdlib_manual.sh  # 手动流程脚本
│       ├── generate_tdlib_api.sh  # API 生成脚本
│       └── ensure_manual_api_placeholders.sh  # 占位符脚本
│
├── src/                         # 源码目录
│   ├── downloads/              # 下载的源码包（手动放置）
│   │   ├── openssl.tar.gz
│   │   ├── zlib.tar.gz
│   │   └── ...
│   └── extracted/              # 解压后的源码（自动解压，固定名称）
│       ├── td/                 # TDLib 源码
│       ├── openssl/            # OpenSSL 源码
│       ├── zlib/               # zlib 源码
│       └── ...                 # 其他依赖库
│
├── build/                       # 构建目录
│   └── <arch>/                 # 按架构分类
│       ├── zlib/               # zlib 构建目录
│       ├── openssl/            # OpenSSL 构建目录
│       ├── tdlib/              # TDLib 构建目录
│       └── tdlib-api-generator/  # API 生成器构建目录
│
├── install/                     # 安装目录
│   └── <arch>/                 # 按架构分类
│       ├── lib/                # 编译好的库文件
│       │   ├── libtdclient.a
│       │   ├── libtdcore.a
│       │   ├── libtdapi.a
│       │   ├── libssl.a
│       │   ├── libcrypto.a
│       │   └── ...
│       └── include/             # 头文件
│           ├── td/
│           ├── openssl/
│           └── ...
│
├── logs/                        # 日志目录
│   └── build/                   # 编译日志
│       ├── tdlib_<arch>_configure.log
│       ├── tdlib_<arch>_build.log
│       └── ...
│
├── patches/                     # HarmonyOS 适配补丁
│   ├── openssl-harmony.patch
│   ├── sqlite-harmony.patch
│   ├── icu-harmony.patch
│   └── tdlib-tl-parser-wgetopt-windows.patch
│
└── dist/                        # 发布包目录
    └── tdlib-harmonyos-*.tar.gz
```

---

## 🚀 完整编译流程

### 前置准备

**手动下载源码**：本项目已移除自动下载功能，请自行下载所有依赖库的源码压缩包，并重命名为**固定名称**（不带版本号）。

**文件名要求**：
```
openssl.tar.gz
zlib.tar.gz
sqlite.tar.gz
icu.tar.gz
protobuf.tar.gz
libphonenumber.tar.gz
crc32c.tar.gz
xxhash.tar.gz
abseil.tar.gz
re2.tar.gz
libevent.tar.gz
lz4.tar.gz
snappy.tar.gz
double-conversion.tar.gz
tdlib.tar.gz
```

**操作步骤**：
1. 从各库官方网站下载源码压缩包
2. 重命名为上述固定名称（不带版本号）
3. 将所有压缩包放到 `src/downloads/` 目录

### 方式 1: 一键完整构建（推荐）

```bash
# 完整流程：解压 → 补丁 → 编译 → 验证 → 打包
./builder.sh --full
```

**执行内容**：
1. 解压所有源码包（自动重命名为固定名称）
2. 应用 HarmonyOS 适配补丁
3. 编译所有依赖库（按依赖顺序）
4. 验证编译结果
5. 打包发布

### 方式 2: 分步执行（更多控制）

```bash
# 步骤 1: 解压源码（自动重命名为固定名称）
./scripts/extract_sources.sh

# 步骤 2: 应用补丁
./scripts/apply_patches.sh

# 步骤 3: 编译所有库（指定架构）
./scripts/build_all.sh --arch arm64-v8a

# 步骤 4: 验证编译结果
./scripts/verify_build.sh --arch arm64-v8a

# 步骤 5: 打包（可选）
./scripts/package_dist.sh
```

### 编译流程详解

#### 1. 准备源码（手动）

**功能**: 手动下载并放置源码压缩包

**放置位置**: `src/downloads/`

**需要的库**:
- openssl.tar.gz
- zlib.tar.gz
- sqlite.tar.gz
- icu.tar.gz
- protobuf.tar.gz
- crc32c.tar.gz
- xxhash.tar.gz
- abseil.tar.gz
- re2.tar.gz
- libevent.tar.gz
- lz4.tar.gz
- snappy.tar.gz
- double-conversion.tar.gz
- libphonenumber.tar.gz
- tdlib.tar.gz

**支持的压缩格式**: `.tar.gz`, `.tgz`, `.tar.bz2`, `.tar.xz`, `.zip`, `.tar`

#### 2. 解压源码 (`extract_sources.sh`)

**功能**: 解压所有下载的源码包，并自动重命名为固定名称

**解压位置**: `src/extracted/`

**解压后的目录结构**:
```
src/extracted/
├── td/
├── openssl/
├── zlib/
├── sqlite/
├── icu/
│   └── source/
└── ...
```

**日志**: `logs/extract.log`

**常见错误**:
- ❌ **解压失败**: 检查下载的文件是否完整
- ❌ **磁盘空间不足**: 清理磁盘空间
- ❌ **文件不存在**: 确认已将压缩包放到 `src/downloads/` 目录

#### 3. 应用补丁 (`apply_patches.sh`)

**功能**: 应用 HarmonyOS 适配补丁

**补丁位置**: `patches/`

**应用的补丁**:
- `openssl-harmony.patch` - OpenSSL HarmonyOS 适配
- `sqlite-harmony.patch` - SQLite HarmonyOS 适配
- `icu-harmony.patch` - ICU HarmonyOS 适配
- `tdlib-tl-parser-wgetopt-windows.patch` - Windows 下 wgetopt 修复

**日志**: `logs/patch.log`

**常见错误**:
- ⚠️ **补丁应用失败**: 
  - 如果补丁内容已存在于源码中，可以忽略
  - 如果补丁确实失败，检查源码版本是否匹配
  - 查看 `logs/patch.log` 了解详情

#### 4. 编译所有库 (`build_all.sh`)

**功能**: 按依赖顺序编译所有库

**编译顺序**:
1. zlib
2. openssl
3. sqlite
4. icu
5. protobuf
6. crc32c
7. xxhash
8. abseil
9. re2
10. libevent
11. lz4
12. snappy
13. double-conversion
14. libphonenumber
15. tdlib

**构建目录**: `build/<arch>/<库名>/`

**安装目录**: `install/<arch>/`

**日志**: `logs/build/<库名>_<arch>_*.log`

**编译流程**（以 TDLib 为例）:

```
1. 环境设置 (setup_build_env)
   ├─ 加载配置文件
   ├─ 设置工具链路径
   ├─ 设置编译器 (CC, CXX)
   └─ 设置编译标志 (CFLAGS, CXXFLAGS, LDFLAGS)

2. API 文件生成 (generate_tdlib_api.sh)
   ├─ 检查 API 文件是否存在
   ├─ 如果缺失，构建主机工具生成 API
   │   ├─ 修复 Windows wgetopt 问题
   │   ├─ 配置主机 CMake（无工具链）
   │   ├─ 构建 tl-parser
   │   ├─ 构建 generate_common
   │   ├─ 生成 tl_generate_common（生成 td_api.cpp/h/hpp）
   │   └─ 生成 tl_generate_json（生成 td_api_json.cpp/h）
   └─ 创建 mtproto_api.h 包装文件

3. CMake 配置
   ├─ 设置工具链文件
   ├─ 设置依赖库路径
   ├─ 设置编译选项
   └─ 生成构建文件

4. 编译
   └─ 使用 Ninja 或 Make 编译

5. 安装
   └─ 复制库文件和头文件到 install/<arch>/

6. 验证
   ├─ 检查库文件是否存在
   ├─ 检查头文件是否存在
   └─ 验证库文件有效性
```

---

## 🔨 分别编译

### 编译单个库

```bash
# 编译 zlib
./scripts/build/build_zlib.sh arm64-v8a

# 编译 OpenSSL
./scripts/build/build_openssl.sh arm64-v8a

# 编译 TDLib（会自动生成 API 文件）
./scripts/build/build_tdlib.sh arm64-v8a
```

### 编译多个架构

```bash
# 编译 arm64-v8a
./scripts/build_all.sh --arch arm64-v8a

# 编译 armeabi-v7a
./scripts/build_all.sh --arch armeabi-v7a

# 编译 x86_64
./scripts/build_all.sh --arch x86_64
```

### 跳过已编译的库

```bash
# 编译脚本会自动检测已编译的库并跳过
# 如果强制重新编译，先清理构建目录：
rm -rf build/arm64-v8a/<库名>
./scripts/build/build_<库名>.sh arm64-v8a
```

---

## 🧹 清理缓存

### 清理单个库的构建缓存

```bash
# 清理 TDLib 构建缓存
rm -rf build/arm64-v8a/tdlib

# 清理 OpenSSL 构建缓存
rm -rf build/arm64-v8a/openssl
```

### 仅清理编译产物（保留 src）⭐ 常用

清空 `build/`、`install/`、`dist/`、`logs/`，**保留** `src/downloads/` 和 `src/extracted/`：

```bash
# 使用清理脚本（推荐，有交互确认）
./scripts/cleanup.sh --keep-src
# 或简写
./scripts/cleanup.sh -k

# 手动清理（不删 src）
rm -rf build/ install/ dist/ logs/
```

### 清理所有构建缓存（含 src）

```bash
# 使用清理脚本（会清空 src/downloads、src/extracted）
./scripts/cleanup.sh

# 手动清理
rm -rf build/ install/ dist/ logs/
rm -rf src/downloads/* src/extracted/*
```

### 清理源码（重新下载）

```bash
# 仅清空下载的源码包
rm -rf src/downloads/*

# 仅清理解压的源码
rm -rf src/extracted/*
```

### 完全清理（重新开始）

```bash
# 仅清理编译产物，保留 src
./scripts/cleanup.sh --keep-src

# 或清理全部（含 src）
./scripts/cleanup.sh
```

---

## 📂 编译路径说明

### 源码路径

```
src/extracted/
├── td/                          # TDLib 源码（固定名称）
│   ├── td/                      # TDLib 核心代码
│   │   ├── mtproto/            # MTProto 协议
│   │   ├── telegram/           # Telegram API
│   │   └── generate/           # 代码生成器
│   │       ├── auto/           # 生成的 API 文件
│   │       │   └── td/
│   │       │       ├── mtproto/
│   │       │       │   └── mtproto_api.h
│   │       │       └── telegram/
│   │       │           ├── td_api.cpp/h/hpp
│   │       │           └── td_api_json.cpp/h
│   │       └── tl-parser/      # TL 解析器
│   └── CMakeLists.txt
├── openssl/                     # OpenSSL 源码（固定名称）
├── zlib/                        # zlib 源码（固定名称）
└── ...
```

### 构建路径

```
build/
└── <arch>/                      # 架构目录（如 arm64-v8a）
    ├── tdlib/                   # TDLib 构建目录
    │   ├── CMakeCache.txt      # CMake 缓存
    │   ├── build.ninja         # Ninja 构建文件
    │   └── CMakeFiles/         # CMake 生成文件
    ├── openssl/                 # OpenSSL 构建目录
    ├── zlib/                    # zlib 构建目录
    └── tdlib-api-generator/    # API 生成器构建目录（主机端）
```

### 安装路径

```
install/
└── <arch>/                      # 架构目录
    ├── lib/                     # 库文件目录
    │   ├── libtdclient.a       # TDLib 客户端库
    │   ├── libtdcore.a          # TDLib 核心库
    │   ├── libtdapi.a           # TDLib API 库
    │   ├── libssl.a             # OpenSSL SSL 库
    │   ├── libcrypto.a          # OpenSSL 加密库
    │   ├── libz.a               # zlib 库
    │   └── ...                  # 其他依赖库
    └── include/                 # 头文件目录
        ├── td/                  # TDLib 头文件
        │   ├── telegram/
        │   │   ├── td_api.h
        │   │   ├── td_api.hpp
        │   │   └── Client.h
        │   └── mtproto/
        │       └── mtproto_api.h
        ├── openssl/             # OpenSSL 头文件
        ├── zlib.h               # zlib 头文件
        └── ...                  # 其他依赖库头文件
```

### 日志路径

```
logs/
└── build/                       # 编译日志目录
    ├── tdlib_<arch>_configure.log    # TDLib 配置日志
    ├── tdlib_<arch>_build.log         # TDLib 编译日志
    ├── tdlib_<arch>_install.log      # TDLib 安装日志
    ├── openssl_<arch>_build.log      # OpenSSL 编译日志
    └── ...
```

---

## 📦 编译结果位置

### 库文件位置

所有编译好的库文件位于：

```
install/<arch>/lib/
```

**主要库文件**:
- `libtdclient.a` - TDLib 客户端库（静态）
- `libtdcore.a` - TDLib 核心库（静态）
- `libtdapi.a` - TDLib API 库（静态）
- `libssl.a` - OpenSSL SSL 库（静态）
- `libcrypto.a` - OpenSSL 加密库（静态）
- `libz.a` - zlib 压缩库（静态）
- `libsqlite3.a` - SQLite 数据库库（静态）
- `libprotobuf.a` - Protocol Buffers 库（静态）
- `libphonenumber.a` - libphonenumber 库（静态）
- `libevent.a` - libevent 库（静态）
- `libre2.a` - RE2 正则表达式库（静态）
- `libabsl_*.a` - Abseil 库集合（静态）
- 其他依赖库...

### 头文件位置

所有头文件位于：

```
install/<arch>/include/
```

**主要头文件目录**:
- `td/` - TDLib 头文件
  - `telegram/td_api.h` - C API 头文件
  - `telegram/td_api.hpp` - C++ API 头文件
  - `telegram/Client.h` - 客户端头文件
  - `mtproto/mtproto_api.h` - MTProto API 头文件
- `openssl/` - OpenSSL 头文件
- `google/protobuf/` - Protocol Buffers 头文件
- `phonenumbers/` - libphonenumber 头文件
- 其他依赖库头文件...

### 验证编译结果

```bash
# 验证特定架构的编译结果
./scripts/verify_build.sh --arch arm64-v8a

# 详细输出
./scripts/verify_build.sh --arch arm64-v8a --verbose
```

**验证内容**:
- ✅ 检查库文件是否存在
- ✅ 检查库文件是否有效（非空、格式正确）
- ✅ 检查头文件目录是否存在
- ✅ 检查关键头文件是否存在

---

## 💻 使用编译好的 TDLib

### 在 HarmonyOS 项目中使用

#### 1. 复制库文件和头文件

```bash
# 方式 1: 手动复制
cp -r install/arm64-v8a/lib/* /path/to/your/project/libs/
cp -r install/arm64-v8a/include/* /path/to/your/project/include/

# 方式 2: 使用发布包
tar -xzf dist/tdlib-harmonyos-*.tar.gz -C /path/to/your/project/
```

#### 2. 配置 CMakeLists.txt

在你的 HarmonyOS 项目的 `CMakeLists.txt` 中添加：

```cmake
# 设置 TDLib 路径
set(TDLIB_ROOT "/path/to/tdlib/install/arm64-v8a")
set(TDLIB_LIB_DIR "${TDLIB_ROOT}/lib")
set(TDLIB_INCLUDE_DIR "${TDLIB_ROOT}/include")

# 添加头文件目录
include_directories(${TDLIB_INCLUDE_DIR})

# 链接库
target_link_libraries(your_target
    ${TDLIB_LIB_DIR}/libtdclient.a
    ${TDLIB_LIB_DIR}/libtdcore.a
    ${TDLIB_LIB_DIR}/libtdapi.a
    ${TDLIB_LIB_DIR}/libssl.a
    ${TDLIB_LIB_DIR}/libcrypto.a
    ${TDLIB_LIB_DIR}/libz.a
    ${TDLIB_LIB_DIR}/libsqlite3.a
    ${TDLIB_LIB_DIR}/libprotobuf.a
    ${TDLIB_LIB_DIR}/libphonenumber.a
    ${TDLIB_LIB_DIR}/libevent.a
    ${TDLIB_LIB_DIR}/libre2.a
    # ... 其他依赖库
)
```

#### 3. 使用 TDLib API

```cpp
#include "td/telegram/Client.h"
#include "td/telegram/td_api.h"

using namespace td;

int main() {
    // 创建 TDLib 客户端
    Client client;
    
    // 使用 TDLib API
    // ...
    
    return 0;
}
```

### 在 DevEco Studio 中使用

1. **添加库文件**:
   - 将 `install/<arch>/lib/` 下的所有 `.a` 文件复制到项目的 `libs/<arch>/` 目录

2. **添加头文件**:
   - 将 `install/<arch>/include/` 目录复制到项目的 `cpp/include/` 目录

3. **配置 build-profile.json5**:
   ```json5
   {
     "apiType": "stageMode",
     "buildOption": {
       "externalNativeOptions": {
         "path": "./src/main/cpp/CMakeLists.txt",
         "arguments": "",
         "cppFlags": "-std=c++14",
         "abiFilters": ["arm64-v8a"]
       }
     }
   }
   ```

4. **配置 CMakeLists.txt**:
   ```cmake
   cmake_minimum_required(VERSION 3.4.1)
   project("your_project")
   
   set(TDLIB_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../libs/tdlib")
   
   include_directories(${TDLIB_ROOT}/include)
   
   add_library(your_lib SHARED
       your_source.cpp
   )
   
   target_link_libraries(your_lib
       ${TDLIB_ROOT}/lib/arm64-v8a/libtdclient.a
       ${TDLIB_ROOT}/lib/arm64-v8a/libtdcore.a
       ${TDLIB_ROOT}/lib/arm64-v8a/libtdapi.a
       # ... 其他依赖库
   )
   ```

---

## ❌ 常见错误与解决方案

### 1. 配置错误

#### 错误: `OHOS_NDK 路径不存在`

**错误信息**:
```
⚠️  警告: OHOS_NDK 路径不存在: C:Users28483AppDataLocalOpenHarmonySdk20native
```

**原因**: Windows 路径格式错误，反斜杠被错误解析

**解决方案**:
```bash
# 使用正斜杠（推荐）
export OHOS_NDK="C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20/native"

# 或使用转义反斜杠
export OHOS_NDK="C:\\Users\\28483\\AppData\\Local\\OpenHarmony\\Sdk\\20\\native"
```

#### 错误: `工具链文件不存在`

**错误信息**:
```
❌ 未找到工具链文件: /path/to/ndk/build/cmake/ohos.toolchain.cmake
```

**原因**: NDK 路径不正确或 NDK 版本不支持

**解决方案**:
```bash
# 检查 NDK 目录结构
ls -la "$OHOS_NDK/native/build/cmake/"

# 确认工具链文件位置
find "$OHOS_NDK" -name "ohos.toolchain.cmake"

# 如果路径不同，手动设置
export OHOS_TOOLCHAIN_FILE="/correct/path/to/ohos.toolchain.cmake"
```

### 2. 编译错误

#### 错误: `CreateProcess: %1 is not a valid Win32 application`

**错误信息**:
```
ninja: fatal: CreateProcess: %1 is not a valid Win32 application.
```

**原因**: 在 Windows 上，脚本强制指定了 `aarch64-unknown-linux-ohos-clang++`，但该文件不存在或不是 Windows 可执行文件

**解决方案**: 
- ✅ **已修复**: 脚本已更新，不再强制指定编译器，由工具链文件自动选择 `clang/clang++.exe`
- 如果仍出现，清理构建目录：
  ```bash
  rm -rf build/arm64-v8a/tdlib
  ./scripts/build/build_tdlib.sh arm64-v8a
  ```

#### 错误: `fatal error: 'td/mtproto/mtproto_api.h' file not found`

**错误信息**:
```
fatal error: 'td/mtproto/mtproto_api.h' file not found
```

**原因**: API 文件未生成或缺失

**解决方案**:
```bash
# 手动生成 API 文件
./scripts/build/generate_tdlib_api.sh arm64-v8a

# 然后重新编译
rm -rf build/arm64-v8a/tdlib
./scripts/build/build_tdlib.sh arm64-v8a
```

#### 错误: `error: redefinition of 'make_object'`

**错误信息**:
```
error: redefinition of 'make_object'
note: previous definition is here
```

**原因**: `td/mtproto/mtproto_api.h` 和 `td/generate/auto/td/mtproto/mtproto_api.h` 同时被包含，导致重复定义

**解决方案**: 
- ✅ **已修复**: `td/mtproto/mtproto_api.h` 现在是包装文件，包含 `td/generate/auto/td/mtproto/mtproto_api.h`
- 如果仍出现，检查文件内容：
  ```bash
  head -5 src/extracted/td-1.8.0/td/mtproto/mtproto_api.h
  # 应该看到: #pragma once 和 #include "../generate/auto/td/mtproto/mtproto_api.h"
  ```

#### 错误: `clang++: error: no such file or directory: 'td_api_json.cpp'`

**错误信息**:
```
clang++: error: no such file or directory: 'td_api_json.cpp'
```

**原因**: JSON API 文件未生成

**解决方案**:
```bash
# 重新生成 API 文件（包含 JSON）
./scripts/build/generate_tdlib_api.sh arm64-v8a

# 验证文件是否存在
ls -la src/extracted/td-1.8.0/td/generate/auto/td/telegram/td_api_json.*

# 然后重新编译
rm -rf build/arm64-v8a/tdlib
./scripts/build/build_tdlib.sh arm64-v8a
```

#### 错误: `undefined reference to 'SSL_*'` 或 `undefined reference to 'sqlite3_*'`

**错误信息**:
```
undefined reference to `SSL_*`
undefined reference to `sqlite3_*`
```

**原因**: 依赖库未编译或链接顺序错误

**解决方案**:
```bash
# 1. 检查依赖库是否已编译
./scripts/check_dependencies.sh arm64-v8a

# 2. 重新编译缺失的库
./scripts/build/build_openssl.sh arm64-v8a
./scripts/build/build_sqlite.sh arm64-v8a

# 3. 检查库文件
ls -la install/arm64-v8a/lib/libssl.a
ls -la install/arm64-v8a/lib/libsqlite3.a
```

#### 错误: `CMake Error: Could not find OpenSSL`

**错误信息**:
```
CMake Error: Could not find OpenSSL
```

**原因**: CMake 找不到 OpenSSL，即使已编译

**解决方案**:
- ✅ **已修复**: `build_tdlib.sh` 已手动指定所有依赖库路径
- 如果仍出现，检查 `build_tdlib.sh` 中的 `-DOPENSSL_ROOT_DIR` 等参数

### 3. API 生成错误

#### 错误: `构建 tl-parser 失败`

**错误信息**:
```
[ERROR] 构建 tl-parser 失败，查看日志: logs/build/generate_tdlib_api_*.log
```

**原因**: Windows 下 `wgetopt` 兼容性问题

**解决方案**:
- ✅ **已修复**: 脚本会自动应用 `wgetopt` 修复
- 如果仍失败，检查日志：
  ```bash
  cat logs/build/generate_tdlib_api_wgetopt_patch.log
  cat logs/build/generate_tdlib_api_wgetopt_fix.log
  ```
- 手动应用修复：
  ```bash
  # 应用补丁
  cd src/extracted/td-1.8.0
  patch -p1 < ../../patches/tdlib-tl-parser-wgetopt-windows.patch
  
  # 运行修复脚本
  python3 scripts/fix_wgetopt_c_windows.py src/extracted/td-1.8.0/td/generate/tl-parser/wgetopt.c
  ```

#### 错误: `generate_common 运行失败`

**错误信息**:
```
[WARNING] generate_common 运行失败
```

**原因**: 生成的工具无法运行或缺少依赖

**解决方案**:
- 检查主机编译器是否可用：
  ```bash
  g++ --version  # 或 clang++ --version
  ```
- 检查生成的工具是否存在：
  ```bash
  ls -la build/tdlib-api-generator/td/generate/generate_common*
  ```
- 手动运行生成器：
  ```bash
  cd build/tdlib-api-generator
  ./td/generate/generate_common
  ```

### 4. 补丁应用错误

#### 错误: `补丁应用失败，尝试了所有 patch level`

**错误信息**:
```
[WARNING] 补丁应用失败，尝试了所有 patch level (-p0, -p1, -p2)
```

**原因**: 源码版本不匹配或补丁已应用

**解决方案**:
- 如果补丁内容已存在于源码中，可以忽略此警告
- 检查源码版本是否匹配：
  ```bash
  grep -r "VERSION\|version" src/extracted/openssl-*/VERSION
  ```
- 手动检查补丁是否需要：
  ```bash
  ./scripts/check_patch_status.sh
  ```

### 5. 内存不足

#### 错误: `make: *** [all] Error 137`

**错误信息**:
```
make: *** [all] Error 137
```

**原因**: 内存不足（OOM）

**解决方案**:
```bash
# 减少并行任务数
export PARALLEL_JOBS=2
./scripts/build_all.sh --arch arm64-v8a

# 或单独编译大库
./scripts/build/build_icu.sh arm64-v8a
./scripts/build/build_tdlib.sh arm64-v8a
```

### 6. 磁盘空间不足

#### 错误: `No space left on device`

**错误信息**:
```
No space left on device
```

**解决方案**:
```bash
# 检查磁盘空间
df -h

# 清理不需要的文件
./scripts/cleanup.sh

# 或手动清理
rm -rf build/ install/ logs/
```

---

## 🔍 诊断工具

### 检查依赖状态

```bash
# 检查所有依赖库的编译状态
./scripts/check_dependencies.sh arm64-v8a

# 检查特定库
./scripts/check_libphonenumber.sh arm64-v8a
./scripts/check_mtproto_api.sh
```

### 检查编译器

```bash
# 检查编译器路径和版本
./scripts/check_compiler.sh arm64-v8a

# 验证编译器路径
./scripts/verify_compiler_paths.sh
```

### 测试构建系统

```bash
# 测试构建系统配置
./scripts/test_build.sh

# 测试源码查找
./scripts/test_find_source.sh

# 测试路径规范化
./scripts/test_path_normalize.sh
```

### 查看日志

```bash
# 查看所有编译日志
ls -lh logs/build/

# 查看特定库的日志
cat logs/build/tdlib_arm64-v8a_build.log

# 实时查看日志
tail -f logs/build/tdlib_arm64-v8a_build.log

# 搜索错误
grep -i error logs/build/tdlib_arm64-v8a_build.log
```

---

## ✅ 项目完整性检查

### 必需文件检查

```bash
# 检查所有必需脚本是否存在
for script in \
    scripts/common.sh \
    scripts/download_sources.sh \
    scripts/extract_sources.sh \
    scripts/apply_patches.sh \
    scripts/build_all.sh \
    scripts/build/build_tdlib.sh \
    scripts/build/generate_tdlib_api.sh; do
    if [[ -f "$script" ]]; then
        echo "✅ $script"
    else
        echo "❌ $script 缺失"
    fi
done
```

### 编译流程验证

```bash
# 1. 验证配置
source config.sh && validate_config

# 2. 检查依赖库编译状态
./scripts/check_dependencies.sh arm64-v8a

# 3. 验证编译结果
./scripts/verify_build.sh --arch arm64-v8a

# 4. 检查库文件
find install/arm64-v8a/lib -name "*.a" | wc -l
# 应该看到至少 15 个库文件

# 5. 检查头文件
find install/arm64-v8a/include -name "*.h" | wc -l
# 应该看到大量头文件
```

### 功能完整性验证

**TDLib 核心功能**:
- ✅ MTProto 协议支持
- ✅ Telegram API 支持
- ✅ JSON API 支持
- ✅ 电话号码解析（libphonenumber）
- ✅ 加密通信（OpenSSL）
- ✅ 数据库支持（SQLite）
- ✅ 网络库（libevent）
- ✅ 正则表达式（RE2）

**验证方法**:
```bash
# 检查关键库文件
ls -lh install/arm64-v8a/lib/libtd*.a

# 检查关键头文件
ls -lh install/arm64-v8a/include/td/telegram/td_api.h
ls -lh install/arm64-v8a/include/td/telegram/td_api.hpp
ls -lh install/arm64-v8a/include/td/mtproto/mtproto_api.h

# 检查 API 文件不是占位符
grep -q "Wrapper to include" src/extracted/td-1.8.0/td/mtproto/mtproto_api.h && echo "✅ 包装文件正确" || echo "❌ 不是包装文件"
grep -q "Auto-generated placeholder" src/extracted/td-1.8.0/td/generate/auto/td/telegram/td_api.h && echo "❌ 仍是占位符" || echo "✅ 真实 API 文件"
```

---

## 📚 快速参考

### 常用命令

```bash
# 完整构建
./builder.sh --full

# 编译单个架构
./scripts/build_all.sh --arch arm64-v8a

# 编译单个库
./scripts/build/build_tdlib.sh arm64-v8a

# 生成 API 文件
./scripts/build/generate_tdlib_api.sh arm64-v8a

# 验证编译结果
./scripts/verify_build.sh --arch arm64-v8a

# 清理构建缓存
rm -rf build/arm64-v8a/tdlib

# 完全清理
./scripts/cleanup.sh
```

### 关键路径

```bash
# 源码路径
src/extracted/td-1.8.0/

# 构建路径
build/arm64-v8a/tdlib/

# 安装路径
install/arm64-v8a/

# 日志路径
logs/build/

# 库文件
install/arm64-v8a/lib/libtd*.a

# 头文件
install/arm64-v8a/include/td/
```

---

## 🎯 总结

### 编译流程总结

```
1. 环境配置
   └─ 设置 OHOS_NDK, OHOS_API_LEVEL 等

2. 下载源码
   └─ src/downloads/

3. 解压源码
   └─ src/extracted/

4. 应用补丁
   └─ patches/

5. 编译依赖库（按顺序）
   ├─ zlib → openssl → sqlite → icu → protobuf
   ├─ crc32c → xxhash → abseil → re2
   └─ libevent → lz4 → snappy → double-conversion → libphonenumber

6. 生成 TDLib API 文件
   └─ generate_tdlib_api.sh

7. 编译 TDLib
   └─ build_tdlib.sh

8. 验证结果
   └─ verify_build.sh

9. 使用编译结果
   └─ install/<arch>/lib/ 和 include/
```

### 下一步

1. ✅ 验证编译结果
2. ✅ 集成到 HarmonyOS 项目
3. ✅ 测试 TDLib 功能
4. ✅ 根据需要调整编译选项

---

## 📞 获取帮助

如果遇到问题：

1. **查看日志**: `logs/build/` 目录
2. **运行诊断**: `./scripts/check_compiler.sh`, `./scripts/check_dependencies.sh`
3. **检查配置**: `source config.sh && validate_config`
4. **查看本文档**: 常见错误与解决方案章节

---

**祝编译顺利！** 🎉
