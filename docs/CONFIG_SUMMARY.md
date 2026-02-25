# 配置文件系统总结

## 📋 配置文件架构

项目使用分层配置系统，优先级从高到低：

1. **用户配置文件** (`user_config.sh`) - 用户自定义配置
2. **环境变量** - 命令行设置的环境变量
3. **主配置文件** (`config.sh`) - 默认配置和系统配置

## 📁 配置文件说明

### 1. user_config.sh.example
**用途**: 用户配置模板文件

**位置**: 项目根目录

**说明**: 
- 包含所有可配置项的详细说明
- 提供默认值和示例
- 用户可以复制此文件创建自己的配置

**使用**:
```bash
cp user_config.sh.example user_config.sh
# 然后编辑 user_config.sh
```

### 2. user_config.sh
**用途**: 用户实际使用的配置文件

**位置**: 项目根目录

**说明**:
- 由用户创建和编辑
- 包含用户的个人路径和配置
- **不会被提交到版本控制**（已在 .gitignore 中）

**创建方式**:
```bash
# 方式1: 使用初始化脚本（推荐）
./scripts/init_config.sh

# 方式2: 手动复制
cp user_config.sh.example user_config.sh
```

### 3. config.sh
**用途**: 主配置文件

**位置**: 项目根目录

**说明**:
- 系统核心配置
- 自动加载用户配置文件
- 提供默认值和验证功能
- **不要直接修改此文件**（除非是系统级修改）

## 🔄 配置加载流程

```
1. 加载 config.sh
   ↓
2. 检查 user_config.sh 是否存在
   ↓
3. 如果存在，加载 user_config.sh
   ↓
4. 使用用户配置覆盖默认值
   ↓
5. 验证配置
   ↓
6. 应用配置
```

## ⚙️ 配置项分类

### 必需配置
- `OHOS_NDK` - HarmonyOS NDK 路径
- `OHOS_API_LEVEL` - HarmonyOS API 级别

### 推荐配置
- `PARALLEL_JOBS` - 并行任务数
- `ARCHITECTURES` - 目标架构
- `BUILD_MODE` - 构建模式

### 可选配置
- `DOWNLOAD_MIRROR` - 下载镜像源
- `DOWNLOAD_TIMEOUT` - 下载超时
- `DOWNLOAD_RETRIES` - 下载重试次数

### 高级配置
- 路径配置（DOWNLOAD_DIR, BUILD_DIR 等）
- 编译器标志（EXTRA_CFLAGS 等）
- 功能开关（ENABLE_LTO 等）

## 🛠️ 工具脚本

### init_config.sh
**用途**: 初始化用户配置文件

**功能**:
- 自动创建 user_config.sh
- 尝试自动检测 NDK 路径
- 自动检测 CPU 核心数
- 交互式配置

**使用**:
```bash
./scripts/init_config.sh
```

### validate_config() 函数
**用途**: 验证配置

**功能**:
- 检查必需配置是否设置
- 验证路径是否存在
- 检查工具链是否可用
- 验证配置值是否合理

**使用**:
```bash
source config.sh && validate_config
```

## 📝 配置示例

### 最小配置
```bash
export OHOS_NDK="/path/to/ndk"
export OHOS_API_LEVEL=9
```

### 推荐配置
```bash
export OHOS_NDK="/path/to/ndk"
export OHOS_API_LEVEL=9
export PARALLEL_JOBS=4
export BUILD_MODE="Release"
export ARCHITECTURES="arm64-v8a"
```

### 完整配置
查看 `user_config.sh.example` 获取完整示例。

## ✅ 最佳实践

1. **使用初始化脚本**: 首次配置时使用 `./scripts/init_config.sh`
2. **使用绝对路径**: 避免相对路径可能带来的问题
3. **验证配置**: 修改配置后运行 `validate_config`
4. **备份配置**: 重要修改前备份 `user_config.sh`
5. **不要提交**: 不要将 `user_config.sh` 提交到版本控制

## 🔍 故障排除

### 配置未生效
```bash
# 检查文件是否存在
ls -la user_config.sh

# 检查语法
bash -n user_config.sh

# 重新加载
source config.sh
```

### 路径找不到
```bash
# 检查路径
ls -la "$OHOS_NDK"

# 使用绝对路径
export OHOS_NDK="/绝对路径/to/ndk"
```

### 验证失败
```bash
# 查看详细错误
source config.sh && validate_config

# 根据提示修复
```

## 📚 相关文档

- [用户配置使用指南](USER_CONFIG.md) - 详细配置说明
- [快速开始指南](QUICK_START.md) - 快速上手指南
- [故障排除指南](TROUBLESHOOTING.md) - 常见问题解决
