#!/bin/bash
# 检查 mtproto_api.h 文件是否存在和可访问

SOURCE_DIR="src/extracted/td-1.8.0"
MT_PROTO_SOURCE="$SOURCE_DIR/td/mtproto/mtproto_api.h"
MT_PROTO_GEN="$SOURCE_DIR/td/generate/auto/td/mtproto/mtproto_api.h"

echo "检查 mtproto_api.h 文件..."
echo "源目录路径: $MT_PROTO_SOURCE"
echo "生成目录路径: $MT_PROTO_GEN"

if [[ -f "$MT_PROTO_SOURCE" ]]; then
    echo "✓ 源目录文件存在"
    ls -lh "$MT_PROTO_SOURCE" 2>/dev/null || echo "  无法列出文件信息"
else
    echo "✗ 源目录文件不存在"
fi

if [[ -f "$MT_PROTO_GEN" ]]; then
    echo "✓ 生成目录文件存在"
    ls -lh "$MT_PROTO_GEN" 2>/dev/null || echo "  无法列出文件信息"
else
    echo "✗ 生成目录文件不存在"
fi

echo ""
echo "测试编译器查找路径..."
INCLUDE1="$SOURCE_DIR"
INCLUDE2="$SOURCE_DIR/td/generate/auto"

echo "包含路径1: $INCLUDE1"
echo "包含路径2: $INCLUDE2"

if [[ -f "$INCLUDE1/td/mtproto/mtproto_api.h" ]]; then
    echo "✓ 从包含路径1可以找到文件"
else
    echo "✗ 从包含路径1无法找到文件"
fi

if [[ -f "$INCLUDE2/td/mtproto/mtproto_api.h" ]]; then
    echo "✓ 从包含路径2可以找到文件"
else
    echo "✗ 从包含路径2无法找到文件"
fi
