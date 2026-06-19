# 用户配置文件使用指南

## 📋 概述

用户配置文件 (`user_config.sh`) 允许你自定义所有构建相关的路径和选项，无需修改主配置文件。

## 🚀 快速开始

### 1. 创建配置文件

运行 `builder.sh` 配置菜单创建配置文件：

```bash
./builder.sh
```

在主菜单中选择 **5** 进入配置菜单，然后：
- **1**: 设置 NDK 路径
- **2**: 设置 API 级别
- **3**: 设置 TDLib 源码版本
- **4**: 设置 HarmonyOS 适配版本
- **5**: 设置目标架构（多选）
- **6**: 设置构建模式
- **7**: 设置并行任务数
- **8**: 查看当前配置
- **9**: 保存配置到 `user_config.sh`
- **0**: 返回（不保存）

配置保存后，`user_config.sh` 会自动生成在项目根目录。你也可以直接编辑 `user_config.sh` 进行手动修改。

### 2. 编辑配置文件

使用你喜欢的编辑器打开 `user_config.sh`：

```bash
# Linux/macOS
nano user_config.sh
# 或
vim user_config.sh
# 或
code user_config.sh  # VS Code

# Windows
notepad user_config.sh
```

### 3. 设置必需路径

至少需要设置以下两个配置：

```bash
# HarmonyOS NDK 路径（必需）
export OHOS_NDK="/path/to/harmony/ndk"

# HarmonyOS API 级别（必需）
export OHOS_API_LEVEL=9
```

## ⚙️ 配置项说明

### 必需配置

#### OHOS_NDK
HarmonyOS Native Development Kit 的安装路径。

**示例：**
```bash
# Linux/macOS
export OHOS_NDK="/home/user/harmony/ndk"
export OHOS_NDK="$HOME/harmony/ndk"

# Windows (Git Bash/WSL)
export OHOS_NDK="/c/Users/YourName/harmony/ndk"
export OHOS_NDK="C:/Users/YourName/harmony/ndk"
```

**如何找到 NDK 路径：**
- 如果通过 DevEco Studio 安装，通常在：
  - macOS: `~/Library/Huawei/Sdk/native`
  - Windows: `C:\Users\YourName\AppData\Local\Huawei\Sdk\native`
  - Linux: `~/HarmonyOS/Sdk/native`
- 如果手动下载，解压后的目录就是 NDK 路径

#### OHOS_API_LEVEL
HarmonyOS API 级别，根据目标设备选择。

**常见值：**
- `9` - HarmonyOS 2.0+
- `10` - HarmonyOS 3.0+
- `11` - HarmonyOS 4.0+

**如何确定：**
- 查看你的 HarmonyOS SDK 版本
- 或查看目标设备的 HarmonyOS 版本

### 推荐配置

#### PARALLEL_JOBS
并行编译任务数，影响编译速度。

**建议值：**
```bash
# 自动检测（推荐）
export PARALLEL_JOBS=$(nproc)  # Linux
export PARALLEL_JOBS=$(sysctl -n hw.ncpu)  # macOS

# 手动设置
export PARALLEL_JOBS=4  # 4核CPU
export PARALLEL_JOBS=8  # 8核CPU
```

**注意：**
- 不要超过 CPU 核心数
- 建议设置为 `CPU核心数 - 1`，保留一个核心给系统
- 如果内存不足，可以减少此值

#### ARCHITECTURES
要编译的目标架构。

**可选值：**
- `arm64-v8a` - 64位 ARM（推荐，现代设备）
- `armeabi-v7a` - 32位 ARM（旧设备）
- `x86_64` - 64位 x86（模拟器）

**示例：**
```bash
# 单个架构
export ARCHITECTURES="arm64-v8a"

# 多个架构（用空格分隔）
export ARCHITECTURES="arm64-v8a armeabi-v7a"

# 所有架构
export ARCHITECTURES="arm64-v8a armeabi-v7a x86_64"
```

#### BUILD_MODE
构建模式。

**可选值：**
- `Release` - 发布版本（优化，体积小，推荐）
- `Debug` - 调试版本（包含调试信息，体积大）

**示例：**
```bash
export BUILD_MODE="Release"  # 推荐
export BUILD_MODE="Debug"     # 开发调试
```

### 可选配置

#### DOWNLOAD_MIRROR
下载镜像源，用于加速下载（特别是在中国大陆）。

**可选值：**
- `""` - 使用官方源（默认）
- `"china"` - 中国镜像源（如果可用）
- `"huawei"` - 华为镜像源（如果可用）

**示例：**
```bash
export DOWNLOAD_MIRROR="china"  # 使用中国镜像
```

#### DOWNLOAD_TIMEOUT
下载超时时间（秒）。

**默认：** `300`（5分钟）

**示例：**
```bash
export DOWNLOAD_TIMEOUT=600  # 10分钟
```

#### DOWNLOAD_RETRIES
下载失败重试次数。

**默认：** `3`

**示例：**
```bash
export DOWNLOAD_RETRIES=5  # 重试5次
```

### 高级配置

以下配置通常不需要修改，除非有特殊需求：

#### 路径配置
```bash
# 源码下载目录
export DOWNLOAD_DIR="src/downloads"

# 源码解压目录
export EXTRACT_DIR="src/extracted"

# 构建目录
export BUILD_DIR="build"

# 安装目录
export INSTALL_DIR="install"

# 发布包目录
export DIST_DIR="dist"

# 日志目录
export LOGS_DIR="logs"
```

#### 编译器标志
```bash
# 额外的 C 编译器标志
export EXTRA_CFLAGS="-Wno-unused-variable"

# 额外的 C++ 编译器标志
export EXTRA_CXXFLAGS="-Wno-unused-variable"

# 额外的链接器标志
export EXTRA_LDFLAGS="-Wl,--as-needed"
```

#### 功能开关
```bash
# 启用 LTO（链接时优化）
export ENABLE_LTO="ON"  # 或 "OFF"

# 编译静态库
export BUILD_STATIC="ON"  # 或 "OFF"

# 编译动态库
export BUILD_SHARED="OFF"  # 或 "ON"
```

## ✅ 验证配置

配置完成后，验证配置是否正确：

```bash
# 方法1: 使用验证函数
source config.sh && validate_config

# 方法2: 使用测试脚本
./scripts/test_build.sh
```

验证会检查：
- ✅ NDK 路径是否存在
- ✅ 工具链文件是否存在
- ✅ 编译器是否可用
- ✅ API 级别是否有效
- ✅ 其他配置项是否合理

## 🔧 配置优先级

配置的优先级顺序（从高到低）：

1. **用户配置文件** (`user_config.sh`)
2. **环境变量** (如 `export OHOS_NDK=...`)
3. **默认值** (在 `config.sh` 中定义)

**示例：**
```bash
# 在 user_config.sh 中设置
export OHOS_NDK="/path/in/user_config"

# 在命令行中设置（会覆盖 user_config.sh）
export OHOS_NDK="/path/in/env"
source config.sh

# 最终使用: /path/in/env
```

## 📝 配置示例

### 最小配置（必需项）

```bash
export OHOS_NDK="/home/user/harmony/ndk"
export OHOS_API_LEVEL=9
```

### 推荐配置

```bash
# HarmonyOS 环境
export OHOS_NDK="/home/user/harmony/ndk"
export OHOS_API_LEVEL=9

# 构建选项
export PARALLEL_JOBS=4
export BUILD_MODE="Release"
export ARCHITECTURES="arm64-v8a"

# 下载选项（可选）
export DOWNLOAD_MIRROR="china"
```

### 完整配置

```bash
# HarmonyOS 环境
export OHOS_NDK="/home/user/harmony/ndk"
export OHOS_SDK="/home/user/harmony/sdk"
export OHOS_API_LEVEL=9

# 构建选项
export PARALLEL_JOBS=8
export BUILD_MODE="Release"
export ARCHITECTURES="arm64-v8a armeabi-v7a"

# 下载选项
export DOWNLOAD_MIRROR="china"
export DOWNLOAD_TIMEOUT=600
export DOWNLOAD_RETRIES=5

# 功能开关
export ENABLE_LTO="ON"
export BUILD_STATIC="ON"
export BUILD_SHARED="OFF"
```

## 🐛 常见问题

### 问题1: 配置文件未生效

**原因：** 配置文件路径错误或格式错误

**解决：**
```bash
# 检查文件是否存在
ls -la user_config.sh

# 检查语法
bash -n user_config.sh

# 重新加载
source config.sh
```

### 问题2: NDK 路径找不到

**原因：** 路径设置错误或 NDK 未安装

**解决：**
```bash
# 检查路径是否存在
ls -la "$OHOS_NDK"

# 检查工具链文件
ls -la "$OHOS_NDK/native/build/cmake/ohos.toolchain.cmake"

# 使用绝对路径
export OHOS_NDK="/绝对路径/to/ndk"
```

### 问题3: 配置验证失败

**原因：** 必需配置未设置或无效

**解决：**
```bash
# 查看详细错误信息
source config.sh && validate_config

# 根据提示修复配置
# 然后重新验证
```

## 💡 提示

1. **使用绝对路径**：避免相对路径可能带来的问题
2. **备份配置**：修改前备份 `user_config.sh`
3. **版本控制**：不要将 `user_config.sh` 提交到 Git（已添加到 .gitignore）
4. **定期验证**：配置修改后运行 `validate_config` 验证

## 📚 相关文档

- [快速开始指南](QUICK_START.md)
- [故障排除指南](TROUBLESHOOTING.md)
- [实现说明](IMPLEMENTATION.md)
