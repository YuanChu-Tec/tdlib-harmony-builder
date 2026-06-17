# TDLib for HarmonyOS 自动化编译系统

自动化编译 TDLib 及其所有依赖库，适配 HarmonyOS 平台。

## 🚀 快速开始

> **📖 完整文档**: 请查看 [完整编译指南](COMPLETE_BUILD_GUIDE.md) 获取详细的环境配置、编译流程、错误处理和使用说明。

### 1. 初始化配置

```bash
# 运行初始化脚本
./scripts/init_config.sh

# 或手动创建
cp user_config.sh.example user_config.sh
# 然后编辑 user_config.sh，填入你的 HarmonyOS NDK 路径
```

### 2. 配置环境路径

编辑 `user_config.sh`，至少需要设置：

```bash
# HarmonyOS NDK 路径（必需）
export OHOS_NDK="C:/Users/YourName/AppData/Local/OpenHarmony/Sdk/20/native"

# HarmonyOS API 级别（必需）
export OHOS_API_LEVEL=20

# 并行编译任务数（推荐: CPU核心数 - 1）
export PARALLEL_JOBS=7
```

### 3. 准备源码

**手动下载源码**：请自行下载所有依赖库的源码压缩包，直接放到 `src/downloads/` 目录即可。

**文件名要求**：
- ✅ **不再有固定文件名要求**，支持任意文件名
- ✅ 支持多种压缩格式：`.tar.gz`、`.tgz`、`.tar.bz2`、`.tar.xz`、`.zip`、`.tar`
- ✅ 解压后直接使用原目录名，脚本会自动识别

**操作步骤**：
1. 从各库官方网站下载源码压缩包（如 `openssl-3.6.0.tar.gz`、`zlib-1.2.13.tar.gz`、`td-1.8.0.tar.gz` 等）
2. 将所有压缩包放到 `src/downloads/` 目录
3. 运行 `./builder.sh --full` 自动解压并编译

**需要的库**（可在 `config.sh` 中查看版本要求）：
- OpenSSL
- zlib
- SQLite
- ICU
- Protocol Buffers
- libphonenumber
- crc32c
- xxhash
- Abseil
- RE2
- libevent
- lz4
- snappy
- double-conversion
- TDLib

### 4. 验证配置

```bash
source config.sh && validate_config
```

### 5. 开始构建

```bash
# 完整构建（推荐）
./builder.sh --full

# 或分步执行
./scripts/extract_sources.sh       # 解压源码
./scripts/apply_patches.sh         # 应用补丁
./scripts/build_all.sh --arch arm64-v8a  # 编译
./scripts/verify_build.sh --arch arm64-v8a  # 验证
```

**详细说明请查看 [完整编译指南](COMPLETE_BUILD_GUIDE.md)**

## 📁 项目结构

```
tdlib-harmony-builder/
├── user_config.sh.example    # 用户配置模板
├── user_config.sh            # 用户配置文件（需要创建）
├── config.sh                 # 主配置文件
├── builder.sh                # 主构建脚本
├── setup_env.sh              # 环境设置脚本
├── scripts/                  # 构建脚本
│   ├── init_config.sh        # 初始化配置脚本
│   ├── build/                # 各库编译脚本
│   └── ...
├── patches/                  # HarmonyOS 适配补丁
├── docs/                     # 文档
└── ...
```

## ⚙️ 配置说明

### 必需配置

- **OHOS_NDK**: HarmonyOS NDK 安装路径
- **OHOS_API_LEVEL**: HarmonyOS API 级别（如 9, 10, 11, 20）

### 可选配置

- **PARALLEL_JOBS**: 并行编译任务数（默认: CPU核心数）
- **ARCHITECTURES**: 目标架构（默认: arm64-v8a）
- **BUILD_MODE**: 构建模式（Release 或 Debug）

详细配置说明请查看 `user_config.sh.example`。

## 📚 文档

### ⭐ 主要文档

- **[完整编译指南](COMPLETE_BUILD_GUIDE.md)** ⭐ **推荐阅读** - 包含完整的环境配置、编译流程、错误处理和项目使用说明

### 其他文档

- [用户配置指南](docs/USER_CONFIG.md) - 详细的配置说明
- [故障排除指南](docs/TROUBLESHOOTING.md) - 常见问题解决方案
- [TDLib API 生成修复](docs/TDLIB_API_GENERATION_FIX.md) - API 文件生成问题详解

### 已归档文档

历史文档和详细技术说明已归档到 `docs/archive/` 目录，包括：
- 各库的编译修复记录
- 补丁分析报告
- 实现细节说明
- 历史构建指南

如需查看历史文档，请访问 `docs/archive/` 目录。

## 🛠️ 工具脚本

### 主要脚本
- `scripts/init_config.sh` - 初始化用户配置
- `scripts/build_all.sh` - 编译所有依赖库
- `scripts/verify_build.sh` - 验证构建结果
- `scripts/cleanup.sh` - 清理构建文件
- `scripts/check_project_integrity.sh` - 项目完整性检查 ⭐ **新增**

### 编译脚本
- `scripts/build/build_tdlib.sh` - 编译 TDLib（推荐）
- `scripts/build/generate_tdlib_api.sh` - 生成 TDLib API 文件
- `scripts/build/build_*.sh` - 编译各个依赖库

### 诊断工具
- `scripts/check_dependencies.sh` - 检查依赖状态
- `scripts/check_compiler.sh` - 检查编译器
- `scripts/verify_compiler_paths.sh` - 验证编译器路径
- `scripts/test_build.sh` - 测试构建系统

### 其他工具
- `scripts/package_dist.sh` - 打包发布

## 📝 许可证

各库有其自己的许可证，请参考各库的 LICENSE 文件。
