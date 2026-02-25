#!/bin/bash
# 测试路径规范化函数

source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

echo "测试路径规范化函数..."
echo ""

# 测试用例
test_cases=(
    "C:\\Users\\28483\\AppData\\Local\\OpenHarmony\\Sdk\\20\\native"
    "C:\Users\28483\AppData\Local\OpenHarmony\Sdk\20\native"
    "C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20/native"
    "C:Users28483AppDataLocalOpenHarmonySdk20native"
    "/home/user/harmony/ndk"
)

for test_path in "${test_cases[@]}"; do
    echo "原始路径: $test_path"
    normalized=$(normalize_path "$test_path")
    echo "规范化后: $normalized"
    if [[ -d "$normalized" ]]; then
        echo "✅ 路径存在"
    else
        echo "❌ 路径不存在"
    fi
    echo ""
done
