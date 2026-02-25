# TDLib for HarmonyOS 快速开始指南

## 🚀 快速开始

### 1. 环境准备

```bash
# 克隆或进入项目目录
cd tdlib-harmony-builder

# 运行环境设置脚本
./setup_env.sh
```

按照提示：
- 检查系统要求
- 安装系统依赖（可选）
- 配置 HarmonyOS NDK 路径
- 设置环境变量

### 2. 配置 HarmonyOS NDK

如果还没有设置 NDK 路径：

```bash
export OHOS_NDK=/path/to/harmony/ndk
export OHOS_API_LEVEL=9
```

### 3. 完整构建（推荐）

```bash
# 一键完整构建（下载 → 解压 → 补丁 → 编译 → 打包）
./builder.sh --full
```

### 4. 分步构建

如果需要更多控制：

```bash
# 步骤1: 下载所有依赖库源码
./scripts/download_sources.sh

# 步骤2: 解压源码包
./scripts/extract_sources.sh

# 步骤3: 应用 HarmonyOS 适配补丁
./scripts/apply_patches.sh

# 步骤4: 编译所有依赖库（指定架构）
./scripts/build_all.sh --arch arm64-v8a

# 步骤5: 验证构建结果
./scripts/verify_build.sh --arch arm64-v8a

# 步骤6: 打包发布
./scripts/package_dist.sh
```

## 📦 单独编译某个库

```bash
# 编译 zlib
./scripts/build/build_zlib.sh arm64-v8a

# 编译 OpenSSL
./scripts/build/build_openssl.sh arm64-v8a

# 编译 TDLib
./scripts/build/build_tdlib.sh arm64-v8a
```

## 🔍 验证构建

```bash
# 验证特定架构的构建结果
./scripts/verify_build.sh --arch arm64-v8a

# 详细输出
./scripts/verify_build.sh --arch arm64-v8a --verbose
```

## 📊 查看日志

```bash
# 查看构建日志
ls -lh logs/build/

# 查看特定库的编译日志
cat logs/build/zlib_arm64-v8a_build.log

# 实时查看日志
tail -f logs/build/tdlib_arm64-v8a_build.log
```

## 📦 使用编译结果

编译完成后，库文件位于：

```
install/
├── arm64-v8a/
│   ├── lib/          # 所有库文件
│   └── include/      # 所有头文件
├── armeabi-v7a/
│   └── ...
└── x86_64/
    └── ...
```

发布包位于：

```
dist/
└── tdlib-harmonyos-1.8.0-harmonyos-YYYYMMDD.tar.gz
```

## 🛠️ 常见问题

### 1. NDK 路径错误

```bash
# 检查 NDK 路径
echo $OHOS_NDK

# 重新设置
export OHOS_NDK=/path/to/harmony/ndk
./setup_env.sh
```

### 2. 编译失败

```bash
# 查看详细日志
cat logs/build/<库名>_<架构>_build.log

# 清理并重新编译
rm -rf build/<架构>/<库名>
./scripts/build/build_<库名>.sh <架构>
```

### 3. 内存不足

```bash
# 减少并行任务数
export PARALLEL_JOBS=2
./scripts/build_all.sh --arch arm64-v8a
```

### 4. 网络问题

```bash
# 手动下载源码到 src/downloads/
# 然后运行
./scripts/extract_sources.sh
./scripts/apply_patches.sh
./scripts/build_all.sh --arch arm64-v8a
```

## 📚 更多信息

- 详细实现说明：`docs/IMPLEMENTATION.md`
- 编译指南：`build helps.md`
- 系统设计：`TDLib For HarmonyOS.md`

## 🎯 下一步

1. 验证构建结果
2. 集成到你的 HarmonyOS 项目
3. 测试 TDLib 功能
4. 根据需要调整编译选项
