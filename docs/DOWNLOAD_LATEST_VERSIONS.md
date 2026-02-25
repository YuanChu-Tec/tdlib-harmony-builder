# 下载最新版本源码指南

## 概述

项目支持自动获取并下载所有依赖库的最新版本，无需手动更新版本号。

## 快速开始

### 方式 1：使用重置脚本（推荐）

一键重置并下载所有最新版本：

```bash
./scripts/reset_to_latest.sh
```

此脚本会：
1. ✅ 清理所有已下载的源码
2. ✅ 清理所有已解压的源码
3. ✅ 启用最新版本下载
4. ✅ 重新下载所有依赖库的最新版本

### 方式 2：使用下载脚本

保留已下载的源码，只下载缺失的库：

```bash
./scripts/download_latest_sources.sh
```

### 方式 3：手动配置

1. **启用最新版本下载**

编辑 `user_config.sh`：

```bash
export USE_LATEST_VERSION="true"
```

2. **下载源码**

```bash
./scripts/download_sources.sh
```

## 配置说明

### USE_LATEST_VERSION 选项

在 `user_config.sh` 中：

```bash
# 启用最新版本（默认已启用）
export USE_LATEST_VERSION="true"

# 或使用固定版本（更稳定）
export USE_LATEST_VERSION="false"
```

### 支持的库

系统会自动获取以下库的最新版本：

- ✅ **OpenSSL** - 从 openssl.org 获取
- ✅ **zlib** - 从 zlib.net 获取
- ✅ **SQLite** - 从 sqlite.org 获取
- ✅ **ICU** - 从 GitHub 获取
- ✅ **Protobuf** - 从 GitHub 获取
- ✅ **libphonenumber** - 从 GitHub 获取
- ✅ **crc32c** - 从 GitHub 获取
- ✅ **xxhash** - 从 GitHub 获取
- ✅ **Abseil** - 从 GitHub 获取（LTS 版本）
- ✅ **RE2** - 从 GitHub 获取
- ✅ **libevent** - 从 GitHub 获取
- ✅ **LZ4** - 从 GitHub 获取
- ✅ **Snappy** - 从 GitHub 获取
- ✅ **double-conversion** - 从 GitHub 获取
- ✅ **TDLib** - 从 GitHub 获取

## 版本获取方式

### GitHub 仓库

使用 GitHub API 获取最新 release 或 tag：

```bash
# 示例：获取 TDLib 最新版本
curl -sL "https://api.github.com/repos/tdlib/td/releases/latest" | grep tag_name
```

### 官方网站

解析官方网站获取最新版本：

- **OpenSSL**: https://www.openssl.org/source/
- **zlib**: https://zlib.net/
- **SQLite**: https://www.sqlite.org/download.html

## 特殊处理

### Abseil

Abseil 使用 LTS（长期支持）版本格式：`lts-YYYYMMDD.PATCH`

- 标签格式：`lts-20240116.2`
- 下载 URL：`https://github.com/abseil/abseil-cpp/archive/refs/tags/lts-20240116.2.tar.gz`
- 解压目录：`abseil-cpp-lts-20240116.2`

系统会自动获取最新的 LTS 版本。

### RE2

RE2 使用日期格式的标签（如 `2023-06-01`）。

**注意：** 根据项目配置，RE2 默认使用固定版本 `2023-06-01`，因为新版本对 Abseil 依赖较重，在 HarmonyOS NDK 上可能存在兼容性问题。

## 验证下载结果

### 检查下载的版本

```bash
# 查看下载的文件
ls -lh src/downloads/

# 查看解压的目录
ls -d src/extracted/*/
```

### 检查版本信息

```bash
# 检查特定库的最新版本
./scripts/get_latest_version.sh tdlib
./scripts/get_latest_version.sh abseil
./scripts/get_latest_version.sh protobuf
```

## 常见问题

### Q: 如何查看当前使用的版本？

A: 查看 `config.sh` 中的 `*_VERSION_DEFAULT` 变量，或在下载时查看日志输出。

### Q: 下载失败怎么办？

A: 
1. 检查网络连接
2. 检查是否有 `curl` 或 `wget`
3. 如果 GitHub API 受限，可以设置 `USE_LATEST_VERSION=false` 使用固定版本

### Q: 如何固定特定库的版本？

A: 在 `config.sh` 中直接修改对应的 `*_VERSION_DEFAULT` 变量，或在 `user_config.sh` 中覆盖：

```bash
# 固定 TDLib 版本
export TDLIB_VERSION="1.8.0"
```

### Q: 最新版本编译失败怎么办？

A: 
1. 查看编译日志：`logs/build/`
2. 回退到固定版本：设置 `USE_LATEST_VERSION=false`
3. 或手动指定已知可用的版本

## 相关文件

- `scripts/reset_to_latest.sh` - 重置并下载最新版本脚本
- `scripts/download_latest_sources.sh` - 下载最新版本脚本
- `scripts/get_latest_version.sh` - 获取最新版本函数
- `scripts/download_sources.sh` - 主下载脚本
- `config.sh` - 配置文件（包含版本定义）
- `user_config.sh` - 用户配置文件（包含 USE_LATEST_VERSION 设置）

## 参考

- [自动获取最新版本功能说明](docs/AUTO_VERSION.md)
- [用户配置指南](docs/USER_CONFIG.md)
