# TDLib for HarmonyOS 构建指南

## 目录
1. [环境要求](#环境要求)
2. [快速开始](#快速开始)
3. [详细构建步骤](#详细构建步骤)
4. [架构说明](#架构说明)
5. [构建模式](#构建模式)
6. [故障排除](#故障排除)

## 环境要求

### 硬件要求
- CPU: 至少 4 核心
- 内存: 至少 8GB RAM
- 磁盘空间: 至少 50GB 可用空间

### 软件要求
- 操作系统: Linux (Ubuntu 20.04+, CentOS 8+) 或 macOS (10.15+)
- 必要工具:
  - Git
  - CMake 3.15+
  - Ninja 或 Make
  - Clang/LLVM
  - HarmonyOS NDK

## 快速开始

### 方法一：一键式构建（推荐）
```bash
# 克隆项目
git clone https://github.com/your-repo/tdlib-harmony-builder.git
cd tdlib-harmony-builder

# 设置环境
./setup_env.sh

# 重新加载环境变量
source ~/.bashrc  # 或 source ~/.zshrc

# 完整构建
./builder.sh --full