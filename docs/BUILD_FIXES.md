# 编译问题修复指南

## ✅ 已修复的问题

### 1. zlib 编译失败
**问题**: CMake 使用 Ninja 生成器，但脚本使用 `make` 命令
**修复**: 
- 使用 `cmake --build` 代替 `make`
- 使用 `cmake --install` 代替 `make install`

### 2. protobuf 工具链路径错误
**问题**: 工具链路径硬编码为 `${OHOS_NDK}/native/build/cmake/ohos.toolchain.cmake`，但 `OHOS_NDK` 已经指向 `native` 目录
**修复**: 使用 `get_toolchain_file` 函数动态查找工具链文件

### 3. crc32c 工具链路径和构建命令
**修复**: 同 protobuf 和 zlib

## ⚠️ 需要修复的脚本

以下脚本需要应用相同的修复：

1. `scripts/build/build_snappy.sh`
2. `scripts/build/build_libphonenumber.sh`
3. `scripts/build/build_libevent.sh`
4. `scripts/build/build_lz4.sh`
5. `scripts/build/build_xxhash.sh`
6. `scripts/build/build_tdlib.sh`
7. `scripts/build/build_re2.sh`

## 🔧 修复步骤

对于每个脚本，需要：

### 步骤1: 修复工具链路径

找到：
```bash
# 配置 CMake
run_command \
    "\"$CMAKE_CMD\" \"$SOURCE_DIR\" \
        -DCMAKE_TOOLCHAIN_FILE=\"${OHOS_NDK}/native/build/cmake/ohos.toolchain.cmake\" \
```

替换为：
```bash
# 获取工具链文件路径
TOOLCHAIN_FILE="${OHOS_TOOLCHAIN_FILE:-}"
if [[ -z "$TOOLCHAIN_FILE" ]] && command -v get_toolchain_file &> /dev/null; then
    TOOLCHAIN_FILE=$(get_toolchain_file "$OHOS_NDK")
fi
if [[ -z "$TOOLCHAIN_FILE" ]]; then
    # 默认路径
    TOOLCHAIN_FILE="${OHOS_NDK}/build/cmake/ohos.toolchain.cmake"
    if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
        TOOLCHAIN_FILE="${OHOS_NDK}/native/build/cmake/ohos.toolchain.cmake"
    fi
fi

# 配置 CMake
run_command \
    "\"$CMAKE_CMD\" \"$SOURCE_DIR\" \
        -DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE\" \
```

### 步骤2: 修复编译命令（如果使用 make）

找到：
```bash
run_command \
    "make -j${PARALLEL_JOBS}" \
```

替换为：
```bash
run_command \
    "\"$CMAKE_CMD\" --build . --config Release -j${PARALLEL_JOBS}" \
```

### 步骤3: 修复安装命令（如果使用 make install）

找到：
```bash
run_command \
    "make install" \
```

替换为：
```bash
run_command \
    "\"$CMAKE_CMD\" --install . --config Release" \
```

## 📝 快速修复脚本

可以运行以下命令批量修复（需要手动验证）：

```bash
# 修复工具链路径
for script in scripts/build/build_*.sh; do
    if grep -q 'native/build/cmake/ohos.toolchain.cmake' "$script" && ! grep -q 'get_toolchain_file' "$script"; then
        echo "需要修复: $script"
    fi
done
```

## ✅ 验证修复

修复后，重新运行编译：

```bash
./scripts/build_all.sh --arch arm64-v8a
```

## 📊 当前状态

- ✅ OpenSSL: 编译成功
- ✅ SQLite: 编译成功
- ✅ zlib: 已修复，待验证
- ✅ protobuf: 已修复，待验证
- ✅ crc32c: 已修复，待验证
- ⚠️ 其他库: 需要应用相同修复
