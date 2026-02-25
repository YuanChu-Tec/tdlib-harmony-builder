# TDLib for HarmonyOS 故障排除指南

## 🔍 常见问题及解决方案

### 1. HarmonyOS NDK 相关问题

#### 问题：NDK 路径未找到
```
❌ HarmonyOS NDK 未找到: /path/to/ndk
```

**解决方案：**
```bash
# 方法1: 设置环境变量
export OHOS_NDK=/path/to/harmony/ndk
export OHOS_API_LEVEL=9

# 方法2: 运行环境设置脚本
./setup_env.sh

# 方法3: 编辑 config.sh
# 修改 OHOS_NDK 变量的默认值
```

#### 问题：工具链文件不存在
```
❌ 工具链目录不存在: /path/to/ndk/native/llvm
```

**解决方案：**
1. 检查 NDK 目录结构
2. 确认 NDK 版本是否支持 HarmonyOS
3. 检查路径是否正确

```bash
# 检查 NDK 结构
ls -la $OHOS_NDK/native/llvm/bin/
ls -la $OHOS_NDK/native/build/cmake/
```

### 2. 编译错误

#### 问题：编译器找不到
```
❌ 编译器不存在: aarch64-linux-ohos9-clang
```

**解决方案：**
```bash
# 检查编译器是否存在
ls $OHOS_NDK/native/llvm/bin/*clang*

# 如果路径不同，检查实际路径
find $OHOS_NDK -name "*clang*" -type f
```

#### 问题：链接错误 - 找不到库
```
undefined reference to `SSL_*`
undefined reference to `sqlite3_*`
```

**解决方案：**
1. 检查依赖库是否已编译
```bash
./scripts/check_dependencies.sh arm64-v8a
```

2. 重新编译缺失的库
```bash
./scripts/build/build_openssl.sh arm64-v8a
./scripts/build/build_sqlite.sh arm64-v8a
```

3. 检查库文件路径
```bash
ls -la install/arm64-v8a/lib/
```

#### 问题：CMake 配置失败
```
CMake Error: Could not find OpenSSL
```

**解决方案：**
1. 确保依赖库已编译
2. 检查 CMAKE_PREFIX_PATH 设置
3. 手动指定库路径（已在 build_tdlib.sh 中配置）

### 3. 下载问题

#### 问题：源码下载失败
```
❌ 下载失败: https://...
```

**解决方案：**
```bash
# 方法1: 使用镜像源（如果支持）
export DOWNLOAD_MIRROR="china"

# 方法2: 手动下载
# 1. 查看下载URL
grep "get_download_url" config.sh

# 2. 手动下载到 src/downloads/
wget <URL> -O src/downloads/<filename>

# 3. 继续构建流程
./scripts/extract_sources.sh
```

### 4. 补丁应用问题

#### 问题：补丁应用失败
```
patch: **** Only garbage was found in the patch input.
```

**解决方案：**
1. 检查源码版本是否匹配
2. 补丁可能已应用，可以忽略
3. 手动检查补丁内容

```bash
# 检查补丁是否已应用
cd src/extracted/openssl-1.1.1w
patch -p1 --reverse --check < ../../patches/openssl-harmony.patch
```

### 5. ICU 编译问题

#### 问题：ICU 主机构建失败
```
无法执行二进制文件
```

**解决方案：**
ICU 需要先编译主机工具。脚本已处理，但如果失败：

```bash
# 手动处理
cd src/extracted/icu/source
unset CC CXX CFLAGS CXXFLAGS
./configure --enable-static
make -j4
# 然后恢复交叉编译环境变量
```

### 6. TDLib 编译问题

#### 问题：TDLib CMake 找不到依赖
```
Could not find a package configuration file provided by "RE2"
```

**解决方案：**
1. 确保所有依赖库已编译
```bash
./scripts/check_dependencies.sh arm64-v8a
```

2. 检查 build_tdlib.sh 中的依赖配置
3. 手动指定库路径（已在脚本中配置）

#### 问题：TDLib 链接错误
```
undefined reference to `td::*`
```

**解决方案：**
1. 检查 TDLib 是否成功编译
```bash
ls -la install/arm64-v8a/lib/libtd*
```

2. 检查链接顺序
3. 确保使用相同的 C++ 标准库（c++_static 或 c++_shared）

### 7. 内存不足

#### 问题：编译时内存不足
```
make: *** [all] Error 137
```

**解决方案：**
```bash
# 减少并行任务数
export PARALLEL_JOBS=2
./scripts/build_all.sh --arch arm64-v8a

# 或单独编译
./scripts/build/build_zlib.sh arm64-v8a
./scripts/build/build_openssl.sh arm64-v8a
# ...
```

### 8. 架构不匹配

#### 问题：库文件架构错误
```
file libtdjson.so
# 显示错误的架构
```

**解决方案：**
1. 确保使用正确的架构编译
2. 清理并重新编译
```bash
rm -rf build/arm64-v8a install/arm64-v8a
./scripts/build_all.sh --arch arm64-v8a
```

### 9. 验证失败

#### 问题：构建验证发现缺失的库
```
❌ 缺失的库: libtdjson.so
```

**解决方案：**
1. 检查编译日志
```bash
cat logs/build/tdlib_arm64-v8a_build.log
```

2. 重新编译 TDLib
```bash
./scripts/build/build_tdlib.sh arm64-v8a
```

3. 检查安装目录
```bash
find install/ -name "libtd*"
```

## 🛠️ 诊断工具

### 1. 检查依赖状态
```bash
./scripts/check_dependencies.sh arm64-v8a
```

### 2. 测试构建系统
```bash
./scripts/test_build.sh
```

### 3. 验证构建结果
```bash
./scripts/verify_build.sh --arch arm64-v8a --verbose
```

### 4. 查看详细日志
```bash
# 查看所有日志
ls -lh logs/build/

# 查看特定库的日志
cat logs/build/openssl_arm64-v8a_build.log

# 实时查看日志
tail -f logs/build/tdlib_arm64-v8a_build.log
```

## 📋 完整重建流程

如果遇到严重问题，可以完全重建：

```bash
# 1. 清理所有文件
./scripts/cleanup.sh

# 2. 重新下载
./scripts/download_sources.sh

# 3. 重新解压
./scripts/extract_sources.sh

# 4. 重新应用补丁
./scripts/apply_patches.sh

# 5. 重新编译（单个架构）
./scripts/build_all.sh --arch arm64-v8a

# 6. 验证
./scripts/verify_build.sh --arch arm64-v8a
```

## 🔗 获取帮助

如果以上方法都无法解决问题：

1. **查看详细日志**: `logs/build/` 目录
2. **检查环境变量**: `env | grep OHOS`
3. **验证工具链**: `$CC --version`
4. **检查磁盘空间**: `df -h`
5. **检查内存**: `free -h`

## 📝 报告问题

报告问题时请提供：
- 操作系统和版本
- HarmonyOS NDK 版本
- 错误日志
- 执行的命令
- 环境变量设置
