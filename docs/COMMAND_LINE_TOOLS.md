# HarmonyOS Command Line Tools 配置指南

## 概述

HarmonyOS Command Line Tools 是 HarmonyOS 开发工具集，包含以下工具：

- **hvigorw**: HarmonyOS 项目构建工具
- **ohpm**: HarmonyOS 包管理器
- **codelinter**: 代码检查工具

## 安装位置

根据您的配置，Command Line Tools 已安装在：
```
C:\Users\28483\command-line-tools
```

## 配置说明

### 1. 在 user_config.sh 中配置

已在 `user_config.sh` 中添加了以下配置：

```bash
# HarmonyOS Command Line Tools 路径（可选）
export OHOS_COMMAND_LINE_TOOLS="${OHOS_COMMAND_LINE_TOOLS:-C:/Users/28483/command-line-tools}"
```

### 2. 自动添加到 PATH

在 `scripts/common.sh` 的 `setup_build_env()` 函数中，已自动将 Command Line Tools 的 `bin` 目录添加到 PATH：

```bash
# 添加 HarmonyOS Command Line Tools 到 PATH（如果存在）
if [[ -n "$OHOS_COMMAND_LINE_TOOLS" ]] && [[ -d "$OHOS_COMMAND_LINE_TOOLS" ]]; then
    export PATH="${OHOS_COMMAND_LINE_TOOLS}/bin:$PATH"
fi
```

## 工具说明

### ohpm (HarmonyOS Package Manager)

HarmonyOS 包管理器，用于管理 HarmonyOS 项目的依赖包。

**使用示例：**
```bash
# 安装依赖
ohpm install

# 查看已安装的包
ohpm list
```

### hvigorw (HarmonyOS Build Tool)

HarmonyOS 项目构建工具，用于构建 HarmonyOS 应用和库。

**使用示例：**
```bash
# 构建项目
hvigorw assembleHap

# 清理构建
hvigorw clean
```

### codelinter

代码检查工具，用于检查代码质量和规范。

**使用示例：**
```bash
# 检查代码
codelinter
```

## 验证配置

### 检查工具是否可用

```bash
# 加载配置
source config.sh

# 检查 ohpm
which ohpm || where ohpm

# 检查 hvigorw
which hvigorw || where hvigorw
```

### 检查 PATH

```bash
# 查看 PATH 中是否包含 Command Line Tools
echo $PATH | grep command-line-tools
```

## 环境变量

如果已在系统环境变量中设置了 `C:\Users\28483\command-line-tools\bin`，则：

1. **优先级**：系统环境变量 > `user_config.sh` 配置
2. **自动检测**：脚本会自动检测并使用已设置的环境变量
3. **无需重复**：如果已在系统 PATH 中设置，`user_config.sh` 中的配置是可选的

## 故障排除

### 工具未找到

如果工具未找到，请检查：

1. **路径是否正确**：
   ```bash
   ls -la "C:/Users/28483/command-line-tools/bin"
   ```

2. **环境变量是否设置**：
   ```bash
   echo $OHOS_COMMAND_LINE_TOOLS
   ```

3. **PATH 是否包含**：
   ```bash
   echo $PATH | grep command-line-tools
   ```

### Windows 路径格式

在 Windows 上，路径可以使用以下格式：

- Unix 风格：`C:/Users/28483/command-line-tools`
- Windows 风格：`C:\Users\28483\command-line-tools`

脚本会自动处理路径格式转换。

## 相关文档

- [HarmonyOS 开发文档](https://developer.harmonyos.com/)
- [ohpm 使用指南](https://ohpm.openharmony.cn/)
- [hvigor 构建工具文档](https://developer.harmonyos.com/cn/docs/documentation/doc-guides-V3/build-system-overview-0000001527744585-V3)
