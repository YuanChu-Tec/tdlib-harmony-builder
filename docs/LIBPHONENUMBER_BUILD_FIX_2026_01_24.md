# libphonenumber 编译问题修复 (2026-01-24)

## 问题描述

libphonenumber 编译失败，主要有以下问题：

1. **主构建仍然尝试编译 `generate_geocoding_data` 工具**
   - 即使设置了 `BUILD_GEOCODER=OFF`，CMake 仍然在编译工具
   - 错误：`fatal error: 'absl/container/btree_map.h' file not found`

2. **缺少 Abseil 头文件**
   - 主构建时找不到 `absl/base/optimization.h`
   - 主构建时找不到 `absl/strings/string_view.h`
   - 主构建时找不到 `absl/container/btree_map.h`

3. **缺少 ICU 头文件**
   - 主构建时找不到 ICU 头文件：`'icu' has not been declared`
   - 主机工具构建时也找不到 ICU 头文件

## 已实施的修复

### 1. 清理 CMake 缓存

**位置：** `scripts/build/build_libphonenumber.sh` - 主构建配置前

**修复：**
```bash
# 清理 CMake 缓存，确保 BUILD_GEOCODER=OFF 生效
log_info "清理 CMake 缓存..."
rm -rf CMakeCache.txt CMakeFiles/ 2>/dev/null || true
```

### 2. 强制设置 BUILD_GEOCODER=OFF

**位置：** `scripts/build/build_libphonenumber.sh` - CMakeLists.txt 修改和 CMake 配置

**修复：**
- ✅ 在 CMakeLists.txt 中直接设置 `set(BUILD_GEOCODER OFF CACHE BOOL ... FORCE)`
- ✅ 在 CMake 配置时传递 `-DBUILD_GEOCODER=OFF`
- ✅ 配置后再次强制设置 `-DBUILD_GEOCODER:BOOL=OFF` 覆盖缓存
- ✅ 注释掉 `if (BUILD_GEOCODER)` 块中的 `add_subdirectory(tools)` 调用

### 3. 添加 Abseil 和 ICU include 路径

**位置：** `scripts/build/build_libphonenumber.sh` - CMake 配置

**修复：**
```bash
-DCMAKE_CXX_FLAGS="... -I$ARCH_INSTALL_DIR_WIN/include/unicode -I$ARCH_INSTALL_DIR_WIN/include/absl"
```

### 4. 主机工具 ICU 配置

**位置：** `scripts/build/build_libphonenumber.sh` - 主机工具构建配置

**修复：**
- ✅ 检测系统 ICU 或交叉编译的 ICU 头文件
- ✅ 在主机工具 CMake 配置中添加 ICU include 路径
- ✅ 通过 `CMAKE_CXX_FLAGS` 直接添加 `-I` 路径

## 关键修改点

### 修改 1：清理 CMake 缓存

```bash
# 创建构建目录
BUILD_DIR=$(create_build_dir "libphonenumber" "$ARCH")
cd "$BUILD_DIR" || exit 1

# 清理 CMake 缓存，确保 BUILD_GEOCODER=OFF 生效
log_info "清理 CMake 缓存..."
rm -rf CMakeCache.txt CMakeFiles/ 2>/dev/null || true
```

### 修改 2：注释掉 tools 目录

```bash
# 注释 BUILD_GEOCODER 块中的 add_subdirectory(tools)
sed -i '/^if (BUILD_GEOCODER)/,/^endif()/s|^  add_subdirectory("${TOOLS_DIR}" "${TOOLS_BINARY_DIR}")|# 主构建中禁用 BUILD_GEOCODER 块中的 tools 目录\n#  add_subdirectory("${TOOLS_DIR}" "${TOOLS_BINARY_DIR}")|' CMakeLists.txt
```

### 修改 3：添加 include 路径

```bash
-DCMAKE_CXX_FLAGS="... -I$ARCH_INSTALL_DIR_WIN/include/unicode -I$ARCH_INSTALL_DIR_WIN/include/absl"
```

### 修改 4：主机工具 ICU 配置

```bash
if [[ -n "$HOST_ICU_INCLUDE" ]]; then
    CMAKE_ARGS+=(
        "-DUSE_ICU_REGEXP=ON"
        "-DICU_INCLUDE_DIR=\"$HOST_ICU_INCLUDE\""
        "-DCMAKE_CXX_FLAGS=\"-I$HOST_ICU_INCLUDE -I$HOST_ICU_INCLUDE/unicode\""
    )
fi
```

## 验证步骤

### 1. 清理构建目录

```bash
rm -rf build/arm64-v8a/libphonenumber
rm -rf build/arm64-v8a/libphonenumber-host-tools
```

### 2. 验证头文件存在

```bash
# 检查 ICU 头文件
ls install/arm64-v8a/include/unicode/unistr.h
ls install/arm64-v8a/include/unicode/regex.h

# 检查 Abseil 兼容层
ls install/arm64-v8a/include/absl/base/optimization.h
ls install/arm64-v8a/include/absl/strings/string_view.h
ls install/arm64-v8a/include/absl/container/btree_map.h
```

### 3. 重新编译

```bash
./scripts/build/build_libphonenumber.sh arm64-v8a
```

## 预期结果

编译成功后应该：

1. ✅ 主构建不再尝试编译 `generate_geocoding_data` 工具
2. ✅ 主构建能找到 Abseil 兼容层头文件
3. ✅ 主构建能找到 ICU 头文件
4. ✅ 主机工具构建成功（如果 ICU 可用）

## 如果仍然失败

### 检查点 1：CMake 缓存

```bash
# 手动清理缓存
rm -rf build/arm64-v8a/libphonenumber/CMakeCache.txt
rm -rf build/arm64-v8a/libphonenumber/CMakeFiles/
```

### 检查点 2：验证 BUILD_GEOCODER 设置

```bash
# 检查 CMake 缓存
grep BUILD_GEOCODER build/arm64-v8a/libphonenumber/CMakeCache.txt
# 应该显示：BUILD_GEOCODER:BOOL=OFF
```

### 检查点 3：检查头文件路径

```bash
# 验证 include 路径是否正确
cat build/arm64-v8a/libphonenumber/CMakeCache.txt | grep CMAKE_CXX_FLAGS
# 应该包含 -I.../include/unicode 和 -I.../include/absl
```

## 相关文件

- `scripts/build/build_libphonenumber.sh` - 主构建脚本
- `src/extracted/libphonenumber-9.0.22/cpp/CMakeLists.txt` - CMake 配置文件
- `logs/build/libphonenumber_arm64-v8a_configure.log` - 配置日志
- `logs/build/libphonenumber_arm64-v8a_build.log` - 构建日志
