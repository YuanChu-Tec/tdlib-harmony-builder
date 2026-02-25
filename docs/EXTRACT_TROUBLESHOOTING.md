# 解压问题故障排除

## 🔍 ICU 解压失败

### 问题描述

ICU 源码包 `icu4c-78_2-src.tgz` 解压失败。

### 可能的原因

1. **符号链接问题**: Windows/Git Bash 无法创建符号链接（symlink），这是最常见的原因
   - 错误信息: `tar: icu/LICENSE: Cannot create symlink to '../LICENSE': No such file or directory`
   - **解决方案**: 已自动处理，脚本会忽略符号链接错误，只要文件已解压即可
2. **tar 命令问题**: Windows/Git Bash 中的 tar 命令可能不支持某些参数
3. **路径问题**: Windows 路径格式可能导致问题
4. **文件损坏**: 下载的文件可能不完整
5. **权限问题**: 目标目录可能没有写权限

### 解决方案

#### 方法1: 手动解压测试

```bash
# 测试解压脚本
./scripts/test_extract.sh src/downloads/icu4c-78_2-src.tgz
```

#### 方法2: 手动解压

```bash
# 进入解压目录
cd src/extracted

# 手动解压
tar -xzf ../downloads/icu4c-78_2-src.tgz

# 或使用绝对路径
tar -xzf /c/Users/28483/Desktop/tdlib-harmony-builder/src/downloads/icu4c-78_2-src.tgz -C /c/Users/28483/Desktop/tdlib-harmony-builder/src/extracted
```

#### 方法3: 使用 7-Zip（Windows）

如果 tar 命令有问题，可以使用 7-Zip：

```bash
# 安装 7-Zip 后
7z x src/downloads/icu4c-78_2-src.tgz -osrc/extracted/
```

#### 方法4: 检查文件完整性

```bash
# 检查文件大小
ls -lh src/downloads/icu4c-78_2-src.tgz

# 检查文件类型
file src/downloads/icu4c-78_2-src.tgz

# 测试文件是否损坏
tar -tzf src/downloads/icu4c-78_2-src.tgz | head -5
```

如果 `tar -tzf` 失败，说明文件可能损坏，需要重新下载。

#### 方法5: 重新下载

```bash
# 删除旧文件
rm src/downloads/icu4c-78_2-src.tgz

# 重新下载
./scripts/download_sources.sh
```

### 诊断步骤

1. **检查 tar 命令**
   ```bash
   tar --version
   # 或
   tar -V
   ```

2. **测试解压命令**
   ```bash
   # 测试是否能列出文件
   tar -tzf src/downloads/icu4c-78_2-src.tgz | head -5
   
   # 如果成功，尝试解压
   mkdir -p src/extracted/test
   tar -xzf src/downloads/icu4c-78_2-src.tgz -C src/extracted/test
   ```

3. **检查错误信息**
   ```bash
   # 运行解压脚本并查看详细输出
   ./scripts/extract_sources.sh 2>&1 | tee extract.log
   ```

### 常见错误

#### 错误1: "Cannot create symlink" (符号链接错误)

**原因**: Windows/Git Bash 环境不支持创建符号链接

**错误信息示例**:
```
tar: icu/LICENSE: Cannot create symlink to '../LICENSE': No such file or directory
tar: Exiting with failure status due to previous errors
```

**解决方案**: 
- ✅ **已自动处理**: 解压函数会自动检测符号链接错误，如果文件已成功解压，会忽略此错误
- 符号链接通常只是指向其他文件的快捷方式，不影响编译
- 如果解压目录中有内容（如 `icu` 目录），说明解压已成功

**验证解压是否成功**:
```bash
# 检查解压目录是否有内容
ls -la src/extracted/ | grep icu

# 如果看到 icu 或 icu4c-78_2 目录，说明解压成功
```

#### 错误2: "tar: invalid option"

**原因**: tar 版本不支持某些参数

**解决**: 使用兼容的参数
```bash
tar -xzf file.tgz -C dest/
# 或
tar xzf file.tgz -C dest/
```

#### 错误3: "Cannot change directory"

**原因**: 目标目录不存在或权限不足

**解决**: 
```bash
mkdir -p src/extracted
chmod 755 src/extracted
```

#### 错误4: "gzip: stdin: unexpected end of file"

**原因**: 文件下载不完整或损坏

**解决**: 重新下载文件

### 验证解压结果

解压成功后，应该看到：

```bash
ls -la src/extracted/ | grep icu
# 应该看到 icu 或 icu4c-78_2 目录
```

### 如果仍然失败

1. 查看详细日志: `logs/extract/extract_*.log`
2. 手动解压并继续: 解压后可以跳过此步骤，继续后续流程
3. 报告问题: 提供完整的错误信息和环境信息
