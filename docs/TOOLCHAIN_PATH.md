# 工具链文件路径配置说明

## 📋 概述

工具链文件 `ohos.toolchain.cmake` 是 HarmonyOS/OpenHarmony 交叉编译的关键文件。系统会自动检测并适配不同的路径结构。

## 🔍 支持的路径结构

系统支持以下路径结构：

### 1. OpenHarmony SDK 结构（推荐）

```
OpenHarmony/Sdk/20/
└── native/
    ├── build/
    │   └── cmake/
    │       └── ohos.toolchain.cmake  ← 工具链文件
    ├── llvm/
    └── sysroot/
```

**配置方式：**
```bash
export OHOS_NDK="C:/Users/YourName/AppData/Local/OpenHarmony/Sdk/20/native"
```

### 2. 标准 NDK 结构

```
harmony/ndk/
└── native/
    ├── build/
    │   └── cmake/
    │       └── ohos.toolchain.cmake  ← 工具链文件
    ├── llvm/
    └── sysroot/
```

**配置方式：**
```bash
export OHOS_NDK="/path/to/harmony/ndk"
```

### 3. 旧版本结构

```
harmony/ndk/
├── build/
│   └── cmake/
│       └── ohos.toolchain.cmake  ← 工具链文件
└── toolchains/
    └── llvm/
```

## ⚙️ 自动检测

系统会自动按以下顺序检测工具链文件：

1. `${OHOS_NDK}/build/cmake/ohos.toolchain.cmake` （如果 NDK 路径包含 "native"）
2. `${OHOS_NDK}/native/build/cmake/ohos.toolchain.cmake` （标准结构）
3. `${OHOS_NDK}/build/cmake/ohos.toolchain.cmake` （旧版本结构）

## 🛠️ 手动指定

如果自动检测失败，可以手动指定工具链文件路径：

```bash
export OHOS_TOOLCHAIN_FILE="/path/to/ohos.toolchain.cmake"
```

## ✅ 验证工具链文件

### 方法1: 使用验证函数

```bash
source config.sh && validate_config
```

### 方法2: 使用工具脚本

```bash
./scripts/get_toolchain_file.sh
```

### 方法3: 手动检查

```bash
# Windows (Git Bash)
ls -la "C:/Users/YourName/AppData/Local/OpenHarmony/Sdk/20/native/build/cmake/ohos.toolchain.cmake"

# Linux/macOS
ls -la "/path/to/ndk/native/build/cmake/ohos.toolchain.cmake"
```

## 🔧 常见问题

### 问题1: 工具链文件未找到

**症状：**
```
⚠️  警告: 工具链文件未找到
```

**解决方案：**

1. **检查 NDK 路径是否正确**
   ```bash
   echo $OHOS_NDK
   ls -la "$OHOS_NDK"
   ```

2. **检查工具链文件是否存在**
   ```bash
   # 对于 OpenHarmony SDK 结构
   ls -la "$OHOS_NDK/build/cmake/ohos.toolchain.cmake"
   
   # 对于标准结构
   ls -la "$OHOS_NDK/native/build/cmake/ohos.toolchain.cmake"
   ```

3. **手动指定路径**
   ```bash
   export OHOS_TOOLCHAIN_FILE="/完整路径/to/ohos.toolchain.cmake"
   ```

### 问题2: Windows 路径格式问题

**症状：** 路径包含反斜杠，导致检测失败

**解决方案：**

系统会自动转换路径格式，但建议在配置文件中使用正斜杠：

```bash
# ✅ 正确
export OHOS_NDK="C:/Users/YourName/AppData/Local/OpenHarmony/Sdk/20/native"

# ⚠️  也可以（会自动转换）
export OHOS_NDK="C:\\Users\\YourName\\AppData\\Local\\OpenHarmony\\Sdk\\20\\native"
```

### 问题3: 路径包含空格

**症状：** 路径包含空格导致解析错误

**解决方案：**

使用引号包裹路径：

```bash
export OHOS_NDK="C:/Program Files/Harmony/ndk"
```

## 📝 配置示例

### Windows (OpenHarmony SDK)

```bash
# user_config.sh
export OHOS_NDK="C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20/native"
export OHOS_SDK="C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20"
export OHOS_API_LEVEL=20
```

### Linux/macOS (标准 NDK)

```bash
# user_config.sh
export OHOS_NDK="/home/user/harmony/ndk"
export OHOS_API_LEVEL=9
```

## 🔗 相关文档

- [用户配置使用指南](USER_CONFIG.md)
- [故障排除指南](TROUBLESHOOTING.md)
