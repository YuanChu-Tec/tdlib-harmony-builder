# 编译问题修复说明 (2026-01-24)

## 问题概述

在编译过程中遇到两个主要问题：

1. **libphonenumber 主机工具构建失败** - ICU 头文件找不到
2. **tdlib 主机工具配置失败** - 缺少 gperf 工具

## 已实施的修复

### 1. libphonenumber 主机工具 ICU 配置修复

**问题：** 主机工具构建时找不到 ICU 头文件，导致编译错误：
```
error: 'icu' has not been declared
```

**修复：** 
- ✅ 在主机工具 CMake 配置中添加 ICU include 路径
- ✅ 通过 `CMAKE_CXX_FLAGS` 直接添加 `-I` 路径，确保头文件能被找到
- ✅ 支持使用系统 ICU 或交叉编译的 ICU 头文件

**修改文件：** `scripts/build/build_libphonenumber.sh`

### 2. tdlib 主机工具 gperf 检测修复

**问题：** 主机工具配置时找不到 gperf 工具：
```
Could NOT find gperf. Add path to gperf executable to PATH environment variable
```

**修复：**
- ✅ 添加 gperf 工具检测
- ✅ 如果找到 gperf，自动指定路径给 CMake
- ✅ 如果未找到，提供清晰的错误提示和安装建议

**修改文件：** `scripts/build/build_tdlib.sh`

## 用户操作指南

### 安装 gperf（Windows/MSYS2）

如果遇到 tdlib 编译失败，需要安装 gperf：

```bash
# 在 MSYS2 终端中执行
pacman -S gperf
```

### 验证修复

重新编译失败的库：

```bash
# 清理之前的构建
rm -rf build/arm64-v8a/libphonenumber-host-tools
rm -rf build/arm64-v8a/tdlib-host-tools

# 重新编译
./scripts/build/build_libphonenumber.sh arm64-v8a
./scripts/build/build_tdlib.sh arm64-v8a
```

## 技术细节

### libphonenumber ICU 配置

主机工具构建时，ICU 配置优先级：

1. **系统 ICU**（通过 pkg-config 检测）
2. **交叉编译的 ICU 头文件**（仅用于头文件，不链接库）

配置示例：
```cmake
-DUSE_ICU_REGEXP=ON
-DICU_INCLUDE_DIR="/path/to/icu/include"
-DCMAKE_CXX_FLAGS="-I/path/to/icu/include -I/path/to/icu/include/unicode"
```

### tdlib gperf 配置

如果找到 gperf，CMake 配置会自动包含：
```cmake
-DGPERF_EXECUTABLE="/path/to/gperf"
```

## 后续建议

1. **安装 gperf**：在 Windows 上通过 MSYS2 安装 `pacman -S gperf`
2. **验证 ICU**：确保 ICU 已正确编译和安装
3. **清理重建**：如果仍有问题，清理构建目录后重新编译

## 相关文件

- `scripts/build/build_libphonenumber.sh` - libphonenumber 构建脚本
- `scripts/build/build_tdlib.sh` - TDLib 构建脚本
- `logs/build/libphonenumber_arm64-v8a_host_tools_build.log` - 构建日志
- `logs/build/tdlib_arm64-v8a_host_tools_configure.log` - 配置日志
