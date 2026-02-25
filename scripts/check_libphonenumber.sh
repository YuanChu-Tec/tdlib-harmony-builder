#!/bin/bash
# 检查 libphonenumber 编译状态

ARCH="${1:-arm64-v8a}"

echo "检查 libphonenumber 编译状态 (架构: $ARCH)..."
echo ""

# 检查库文件
LIB_FILE="install/${ARCH}/lib/libphonenumber.a"
if [[ -f "$LIB_FILE" ]]; then
    echo "✓ 库文件存在: $LIB_FILE"
    ls -lh "$LIB_FILE" 2>/dev/null || echo "  文件大小: $(stat -f%z "$LIB_FILE" 2>/dev/null || echo "未知")"
else
    echo "✗ 库文件不存在: $LIB_FILE"
fi

# 检查头文件目录
HEADER_DIR="install/${ARCH}/include/phonenumbers"
if [[ -d "$HEADER_DIR" ]]; then
    echo "✓ 头文件目录存在: $HEADER_DIR"
    HEADER_COUNT=$(find "$HEADER_DIR" -name "*.h" 2>/dev/null | wc -l)
    echo "  头文件数量: $HEADER_COUNT"
else
    echo "✗ 头文件目录不存在: $HEADER_DIR"
fi

echo ""
echo "检查源文件修复状态..."

# 检查 regexp_adapter_re2.cc
RE2_FILE="src/extracted/libphonenumber-9.0.22/cpp/src/phonenumbers/regexp_adapter_re2.cc"
if [[ -f "$RE2_FILE" ]]; then
    if grep -q "using StringPiece = re2::StringPiece;" "$RE2_FILE" 2>/dev/null; then
        echo "✓ regexp_adapter_re2.cc 已修复（包含 using StringPiece = re2::StringPiece）"
    else
        echo "✗ regexp_adapter_re2.cc 未修复（缺少 using StringPiece = re2::StringPiece）"
    fi
    
    if grep -q "std::string(utf8_input_.data(), utf8_input_.size())" "$RE2_FILE" 2>/dev/null; then
        echo "✓ regexp_adapter_re2.cc 已修复（ToString() 方法已修复）"
    else
        if grep -q "utf8_input_.ToString()" "$RE2_FILE" 2>/dev/null; then
            echo "✗ regexp_adapter_re2.cc 未修复（仍使用 ToString() 方法）"
        fi
    fi
    
    if grep -q "re2::StringPiece\* Data()" "$RE2_FILE" 2>/dev/null; then
        echo "✓ regexp_adapter_re2.cc 已修复（Data() 方法使用 re2::StringPiece）"
    else
        echo "✗ regexp_adapter_re2.cc 未修复（Data() 方法未使用 re2::StringPiece）"
    fi
else
    echo "✗ regexp_adapter_re2.cc 文件不存在: $RE2_FILE"
fi

# 检查 string_byte_sink.h
BYTE_SINK_FILE="src/extracted/libphonenumber-9.0.22/cpp/src/phonenumbers/string_byte_sink.h"
if [[ -f "$BYTE_SINK_FILE" ]]; then
    if grep -q "#include <unicode/bytestream.h>" "$BYTE_SINK_FILE" 2>/dev/null; then
        echo "✓ string_byte_sink.h 已修复（包含 bytestream.h）"
    else
        echo "✗ string_byte_sink.h 未修复（缺少 bytestream.h）"
    fi
else
    echo "✗ string_byte_sink.h 文件不存在: $BYTE_SINK_FILE"
fi

echo ""
echo "检查编译日志..."

# 检查最近的编译日志
BUILD_LOG="logs/build/libphonenumber_${ARCH}_build.log"
if [[ -f "$BUILD_LOG" ]]; then
    ERROR_COUNT=$(grep -c "error:" "$BUILD_LOG" 2>/dev/null || echo "0")
    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        echo "✗ 编译日志中发现 $ERROR_COUNT 个错误"
        echo "  最后几个错误:"
        grep "error:" "$BUILD_LOG" 2>/dev/null | tail -3
    else
        echo "✓ 编译日志中未发现错误"
    fi
else
    echo "⚠ 编译日志不存在: $BUILD_LOG"
fi

echo ""
echo "检查完成"
