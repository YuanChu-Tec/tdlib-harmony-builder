#!/bin/bash
# 初始化用户配置文件（已迁移到 builder.sh 配置菜单）
# 
# 此脚本已废弃，请使用 builder.sh 的交互式配置菜单：
#
#   ./builder.sh  →  主菜单选 5 (配置管理)  →  配置后选 9 保存
#

echo "============================================"
echo "  init_config.sh 已废弃"
echo "============================================"
echo ""
echo "请使用 builder.sh 的配置菜单自动生成 user_config.sh："
echo ""
echo "  1. 运行 ./builder.sh"
echo "  2. 主菜单选择 5 (配置管理)"
echo "  3. 分别设置 NDK 路径、API 级别等"
echo "  4. 选择 9 保存配置到 user_config.sh"
echo ""
echo "配置菜单支持设置以下项目："
echo "  - HarmonyOS NDK 路径"
echo "  - API 级别"
echo "  - TDLib 源码版本 / HarmonyOS 适配版本"
echo "  - 目标架构（多选）"
echo "  - 构建模式（Release/Debug/Profile）"
echo "  - 并行任务数"
echo ""

read -p "是否现在启动 builder.sh？ [Y/n]: " answer
if [[ ! "$answer" =~ ^[nN] ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    exec "$SCRIPT_DIR/builder.sh"
fi
