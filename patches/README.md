# HarmonyOS 适配补丁说明

## 📋 概述

本目录包含用于将各库适配到 HarmonyOS 平台的补丁文件。

**重要更新** (2026-01-24):
- ✅ 大部分 HarmonyOS 适配已通过编译选项实现，无需补丁
- ✅ 不必要的补丁已删除
- ✅ 保留 Windows wgetopt 修复补丁（用于 TDLib API 生成器）
- ✅ 新增 TDLib HarmonyOS 适配补丁（线程亲和、AsyncFileLog 无 eventfd），在 `build_tdlib.sh` 中自动应用

## 📄 补丁列表

### 1. `tdlib-harmony-thread-affinity.patch` ✅ **TDLib 鸿蒙适配**

- **状态**: ✅ **必要** - 在鸿蒙上编译 TDLib 时使用
- **作用**: 在 `TD_HARMONYOS` 下不定义 `TD_HAVE_THREAD_AFFINITY`，避免使用不存在的 `pthread_setaffinity_np` / `pthread_getaffinity_np`
- **应用时机**: 在 `build_tdlib.sh` 中自动应用（配置前）
- **详细说明**: 参见 `docs/TDLIB_HARMONYOS_PATCHES.md`

### 2. `patches/tdlib-eventfd-pipe/`（EventFdPipe.h/cpp）+ `tdlib-harmony-eventfd-pipe.patch` ✅ **TDLib 鸿蒙适配**

- **状态**: ✅ **必要** - 在鸿蒙上启用异步文件日志
- **作用**: 无 eventfd 时用 pipe 实现 EventFd（EventFdPipe），供 MpscPollableQueue 与 AsyncFileLog 使用；构建时使用 `-DTD_EVENTFD_PIPE=1`
- **应用时机**: 在 `build_tdlib.sh` 中自动复制源文件并应用补丁（配置前）
- **详细说明**: 参见 `docs/TDLIB_HARMONYOS_PATCHES.md`

### 3. `tdlib-harmony-asyncfilelog-eventfd.patch` ✅ **TDLib 鸿蒙适配（备用）**

- **状态**: 可选 - 仅在使用 `TD_EVENTFD_UNSUPPORTED` 构建时需要；本构建使用 `TD_EVENTFD_PIPE`，通常不依赖此补丁
- **作用**: 在无 eventfd 且未使用 EventFdPipe 时提供 AsyncFileLog 桩实现
- **应用时机**: 在 `build_tdlib.sh` 中自动应用（配置前）

### 4. `tdlib-tl-parser-wgetopt-windows.patch` ✅ **Windows/MSYS2 专用**

- **状态**: ✅ **必要** - 仅在 Windows/MSYS2 上构建 TDLib 主机代码生成器时使用
- **作用**: 
  - 修正 `wgetopt.h` 中的函数声明，避免编译错误
  - 修复 "expected 0, have 3" 错误
- **应用时机**: 
  - 在 `generate_tdlib_api.sh` 中自动检测和应用
  - 仅在 Windows/MSYS2 环境下且需要生成 API 文件时使用
- **相关脚本**: `scripts/fix_wgetopt_c_windows.py`（进一步修复 wgetopt.c）

### 5. `tdlib-tl-parser-wgetopt-c-windows.patch` ✅ **Windows/MSYS2 专用**

- **状态**: ✅ **必要** - 配合 Python 脚本使用
- **作用**: 修复 wgetopt.c 中的 Windows 兼容性问题
- **应用方式**: 通过 `fix_wgetopt_c_windows.py` 脚本自动处理

## 🔧 HarmonyOS 适配实现方式

**HarmonyOS 平台适配主要通过编译选项实现，无需补丁**:

### 1. TDLib 适配
- ✅ 编译标志: `-DOHOS`, `-DTD_HARMONYOS=1`, `-DTD_EVENTFD_UNSUPPORTED=1`
- ✅ CMake 配置: `OHOS_PLATFORM=OHOS`, `OHOS_STL=c++_static`, `OHOS_ARCH`
- ✅ 实现位置: `scripts/build/build_tdlib.sh`

### 2. OpenSSL 适配
- ✅ 编译标志: `-D__OHOS__`, `-D__MUSL__=1`
- ✅ 实现位置: `scripts/build/build_openssl.sh`

### 3. libphonenumber RE2 兼容性
- ✅ 内联修复: 在 `build_libphonenumber.sh` 中直接修复源文件
- ✅ 修复内容: `regexp_adapter_re2.cc` 和 `string_byte_sink.h`
- ✅ 无需补丁: 修复代码已集成到编译脚本中

### 4. 其他库
- ✅ SQLite: 自动检测平台，无需特殊适配
- ✅ ICU: configure 脚本已有自动检测逻辑
- ✅ 其他依赖库: 通过工具链和编译选项自动适配

## 📊 补丁状态总结

| 补丁 | 状态 | 说明 |
|------|------|------|
| `tdlib-harmony-thread-affinity.patch` | ✅ 保留 | TDLib 鸿蒙：实现线程亲和（gettid+sched_setaffinity） |
| `tdlib-eventfd-pipe/` + `tdlib-harmony-eventfd-pipe.patch` | ✅ 保留 | TDLib 鸿蒙：EventFdPipe 实现 AsyncFileLog |
| `tdlib-harmony-asyncfilelog-eventfd.patch` | ✅ 保留 | TDLib 鸿蒙：备用 AsyncFileLog 桩（TD_EVENTFD_UNSUPPORTED 时） |
| `tdlib-tl-parser-wgetopt-windows.patch` | ✅ 保留 | Windows 下 API 生成器需要 |
| `tdlib-tl-parser-wgetopt-c-windows.patch` | ✅ 保留 | Windows 下 API 生成器需要 |
| ~~`openssl-harmony.patch`~~ | ❌ 已删除 | OpenSSL 3.x 不适用，已通过编译选项实现 |
| ~~`sqlite-harmony.patch`~~ | ❌ 已删除 | SQLite 自动检测，无需补丁 |
| ~~`icu-harmony.patch`~~ | ❌ 已删除 | ICU configure 已有处理逻辑 |
| ~~`tdlib-harmony.patch`~~ | ❌ 已删除 | 已通过 CMake 配置实现 |
| ~~`libphonenumber-re2-api-fix.patch`~~ | ❌ 已删除 | 已在编译脚本中内联修复 |

## 🔧 补丁应用说明

### 自动应用

补丁会在需要时自动应用：
- **TDLib HarmonyOS 补丁**: 在 `build_tdlib.sh` 中自动应用（配置前）
- **wgetopt 补丁**: 在 `generate_tdlib_api.sh` 中自动检测和应用（仅 Windows/MSYS2）

### 手动应用（通常不需要）

```bash
# TDLib HarmonyOS 补丁（在 TDLib 源码根目录下执行）
cd src/extracted/td-1.8.0
patch -p1 -i ../../patches/tdlib-harmony-thread-affinity.patch
patch -p1 -i ../../patches/tdlib-harmony-asyncfilelog-eventfd.patch

# 仅在 Windows 下生成 TDLib API 时可能需要
patch -p1 -i ../../patches/tdlib-tl-parser-wgetopt-windows.patch
```

**注意**: 通常不需要手动应用，脚本会自动处理。详见 `docs/TDLIB_HARMONYOS_PATCHES.md`。

## ✅ 当前实现状态

**HarmonyOS 适配已完全通过以下方式实现**:

1. ✅ **编译标志**: 
   - `-DOHOS`, `-D__OHOS__`
   - `-DTD_HARMONYOS=1`
   - `-DTD_EVENTFD_UNSUPPORTED=1`

2. ✅ **CMake 配置**: 
   - `OHOS_PLATFORM=OHOS`
   - `OHOS_STL=c++_static`
   - `OHOS_ARCH=<架构>`

3. ✅ **工具链**: 
   - 使用 `ohos.toolchain.cmake`
   - 自动选择正确的编译器

4. ✅ **内联修复**: 
   - libphonenumber RE2 兼容性修复
   - 直接在编译脚本中实现

5. ✅ **Windows 特殊处理**: 
   - wgetopt 修复（仅 Windows 下 API 生成器需要）

**结论**: 补丁主要用于 Windows 下的特殊情况，大部分适配已通过编译配置实现，无需手动应用补丁。
