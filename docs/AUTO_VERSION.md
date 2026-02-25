# 自动获取最新版本功能说明

## 📋 概述

系统现在支持自动获取并下载依赖库的最新版本，无需手动更新版本号。

## ⚙️ 配置方法

### 启用自动获取最新版本

在 `user_config.sh` 中设置：

```bash
# 启用自动获取最新版本
export USE_LATEST_VERSION="true"
# 或
export USE_LATEST_VERSION="auto"
# 或
export USE_LATEST_VERSION="latest"
```

### 使用固定版本（推荐）

```bash
# 使用固定版本（默认，更稳定）
export USE_LATEST_VERSION="false"
```

## 🔍 工作原理

### 1. 版本获取方式

系统会根据库的类型使用不同的方法获取最新版本：

#### GitHub 仓库
使用 GitHub API 获取最新 release 或 tag：
- protobuf
- libphonenumber
- crc32c
- xxhash
- re2
- libevent
- lz4
- snappy
- double-conversion
- tdlib
- icu

#### 官方网站
解析官方网站获取最新版本：
- OpenSSL: 从 openssl.org 获取
- zlib: 从 zlib.net 获取
- SQLite: 从 sqlite.org 获取

### 2. 版本获取流程

```
1. 检查 USE_LATEST_VERSION 配置
   ↓
2. 如果启用，调用 get_latest_version() 函数
   ↓
3. 从相应源获取最新版本号
   ↓
4. 如果获取成功，更新版本变量
   ↓
5. 如果获取失败，使用默认版本（保证稳定性）
   ↓
6. 使用更新后的版本下载源码
```

## 📝 使用示例

### 示例1: 启用自动版本

```bash
# user_config.sh
export USE_LATEST_VERSION="true"

# 运行下载脚本
./scripts/download_sources.sh

# 系统会自动：
# 1. 获取所有库的最新版本
# 2. 显示获取到的版本号
# 3. 下载最新版本的源码
```

### 示例2: 检查特定库的最新版本

```bash
# 检查单个库的最新版本
./scripts/get_latest_version.sh tdlib

# 输出示例：
# 1.9.0
```

### 示例3: 混合使用

你也可以在 `user_config.sh` 中为特定库设置固定版本，其他库使用最新版本：

```bash
# 使用最新版本
export USE_LATEST_VERSION="true"

# 但为特定库设置固定版本（在 config.sh 中）
# 这些会在 update_to_latest_versions() 中被覆盖
# 如果需要固定特定库，可以修改脚本逻辑
```

## 🔧 技术细节

### GitHub API 获取

```bash
# 获取最新 release
curl -sL "https://api.github.com/repos/tdlib/td/releases/latest"

# 如果没有 release，获取最新 tag
curl -sL "https://api.github.com/repos/tdlib/td/tags"
```

### 版本格式处理

系统会自动处理不同的版本格式：
- 带前缀的标签：`v1.8.0` → `1.8.0`
- 带前缀的 release：`release-72-1` → `72.1`
- 日期格式：`2023-06-01` → `2023-06-01`

## ⚠️ 注意事项

### 1. 网络要求

自动获取最新版本需要：
- 能够访问 GitHub API（如果使用 GitHub 仓库）
- 能够访问官方网站（如果使用官网解析）
- 需要 `curl` 或 `wget` 工具

### 2. API 限制

GitHub API 有速率限制：
- 未认证：60 请求/小时
- 认证后：5000 请求/小时

如果遇到限制，系统会回退到默认版本。

### 3. 稳定性考虑

**推荐使用固定版本**，因为：
- 最新版本可能包含未测试的更改
- 固定版本经过验证，更稳定
- 避免因版本更新导致的编译问题

### 4. 版本兼容性

不同库的最新版本可能存在兼容性问题，建议：
- 首次使用最新版本时，先测试编译
- 如果遇到问题，回退到固定版本
- 记录成功编译的版本组合

## 🐛 故障排除

### 问题1: 无法获取最新版本

**症状：**
```
⚠️  警告: openssl: 无法获取最新版本，使用默认版本
```

**解决方案：**
1. 检查网络连接
2. 检查是否有 `curl` 或 `wget`
3. 检查防火墙设置
4. 使用固定版本（设置 `USE_LATEST_VERSION=false`）

### 问题2: GitHub API 限制

**症状：**
```
API rate limit exceeded
```

**解决方案：**
1. 等待一段时间后重试
2. 使用 GitHub token（需要修改脚本）
3. 使用固定版本

### 问题3: 版本格式错误

**症状：**
```
下载失败: 404 Not Found
```

**解决方案：**
1. 检查获取到的版本号是否正确
2. 查看下载 URL 是否正确
3. 手动验证版本是否存在
4. 回退到固定版本

## 📊 版本信息存储

获取到的版本信息会：
- 在下载时显示
- 存储在环境变量中
- 用于生成下载 URL
- **不会**保存到配置文件（每次运行都重新获取）

如果需要固定某个获取到的版本，可以：
1. 运行一次自动获取
2. 查看输出的版本号
3. 在 `user_config.sh` 中手动设置该版本
4. 设置 `USE_LATEST_VERSION=false`

## 🔗 相关文档

- [用户配置指南](USER_CONFIG.md)
- [下载脚本说明](../scripts/download_sources.sh)
