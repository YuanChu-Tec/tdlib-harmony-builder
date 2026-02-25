# 基于华为开发者博客的 libphonenumber for HarmonyOS 编译指南

参考：[华为开发者博客 - libphonenumber 编译实践](https://developer.huawei.com/consumer/cn/blog/topic/03203338118552006)

## 一、核心配置要点

### 1. **C++ 标准设置**

根据华为开发者博客的建议，libphonenumber 需要 C++17 标准：

```cmake
-DCMAKE_CXX_STANDARD=17
-DCMAKE_CXX_STANDARD_REQUIRED=ON
```

**已实施**：已在主构建配置中添加（第 473-474 行）

### 2. **HarmonyOS 平台标志**

```bash
-D__MUSL__=1
-D__OHOS__=1
```

**已实施**：已在 `config.sh` 中设置（第 487-488 行）

### 3. **工具链配置**

```cmake
-DCMAKE_TOOLCHAIN_FILE="ohos.toolchain.cmake"
-DOHOS_ARCH="arm64-v8a"
-DOHOS_STL=c++_static
```

**已实施**：已在主构建配置中设置（第 440-443 行）

### 4. **依赖库路径配置**

```cmake
-DCMAKE_FIND_ROOT_PATH="${ARCH_INSTALL_DIR}"
-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
```

**已实施**：已在主构建配置中设置（第 467-469 行）

## 二、关键修复点

### 1. **禁用地理编码器工具（主构建）**

```cmake
-DBUILD_GEOCODER=OFF
```

**原因**：`generate_geocoding_data` 是主机工具，不应在交叉编译中构建

**已实施**：已在主构建配置中设置（第 450 行）

### 2. **启用 ICU 正则表达式**

```cmake
-DUSE_ICU_REGEXP=ON
```

**原因**：libphonenumber 需要 ICU 正则表达式引擎支持

**已实施**：已在主构建配置中设置（第 451 行）

### 3. **Abseil 兼容层**

由于 Protobuf 33.4 依赖 Abseil，但 HarmonyOS 交叉编译环境中没有完整的 Abseil，项目创建了最小兼容层：

- `absl/base/optimization.h`
- `absl/strings/string_view.h`
- `absl/container/btree_map.h`

**已实施**：已在脚本中自动创建（第 40-103 行）

### 4. **主机工具分离**

主机工具（`generate_geocoding_data`）在主机构建中编译，使用：

```cmake
-DCMAKE_CXX_STANDARD=17
-DBUILD_GEOCODER=ON
```

**已实施**：已在主机工具构建配置中设置（第 564 行）

## 三、编译流程

### 1. **环境准备**

```bash
# 设置 HarmonyOS NDK 路径
export OHOS_NDK="C:/Users/28483/AppData/Local/OpenHarmony/Sdk/20/native"

# 设置 Command Line Tools 路径（可选）
export OHOS_COMMAND_LINE_TOOLS="C:/Users/28483/command-line-tools"
```

### 2. **编译依赖库**

按顺序编译依赖库：

```bash
./scripts/build/build_zlib.sh arm64-v8a
./scripts/build/build_icu.sh arm64-v8a
./scripts/build/build_protobuf.sh arm64-v8a
# ... 其他依赖库
```

### 3. **编译 libphonenumber**

```bash
# 清理构建目录（如果之前失败）
rm -rf build/arm64-v8a/libphonenumber

# 编译
./scripts/build/build_libphonenumber.sh arm64-v8a
```

## 四、关键配置对比

| 配置项 | 华为博客建议 | 项目实现 | 状态 |
|--------|------------|---------|------|
| C++ 标准 | C++17 | C++17 | ✅ |
| MUSL 标志 | `-D__MUSL__=1` | 已设置 | ✅ |
| 工具链文件 | `ohos.toolchain.cmake` | 已配置 | ✅ |
| BUILD_GEOCODER | 主构建中禁用 | `OFF` | ✅ |
| USE_ICU_REGEXP | 启用 | `ON` | ✅ |
| CMAKE_FIND_ROOT_PATH | 限制搜索范围 | 已配置 | ✅ |
| Abseil 兼容 | 需要处理 | 兼容层 | ✅ |

## 五、常见问题处理

### 1. **Abseil 头文件未找到**

**解决方案**：项目已自动创建 Abseil 兼容层，包含 Protobuf 需要的头文件

### 2. **ICU 头文件未找到**

**解决方案**：脚本会自动从 ICU 源码复制缺失的头文件（第 404-420 行）

### 3. **Protobuf runtime_version.h 未找到**

**解决方案**：脚本会自动创建占位符文件（第 386-402 行）

### 4. **generate_geocoding_data 在主构建中编译**

**解决方案**：已设置 `-DBUILD_GEOCODER=OFF`，并实现主机工具分离

## 六、验证编译结果

### 检查库文件

```bash
# 检查静态库是否存在
ls -lh install/arm64-v8a/lib/libphonenumber.a

# 验证库文件格式（应为 ARM aarch64）
file install/arm64-v8a/lib/libphonenumber.a
```

### 检查头文件

```bash
# 检查头文件是否安装
ls -lh install/arm64-v8a/include/phonenumbers/
```

## 七、参考资源

- [华为开发者博客 - libphonenumber 编译实践](https://developer.huawei.com/consumer/cn/blog/topic/03203338118552006)
- [Protobuf Abseil 支持文档](https://protobuf.com.cn/reference/cpp/abseil)
- [HarmonyOS NDK 编译指南](https://developer.harmonyos.com/)
- [CMake find_path 文档](https://cmake.com.cn/cmake/help/latest/command/find_path.html)

## 八、下一步

1. **清理构建目录**：
   ```bash
   rm -rf build/arm64-v8a/libphonenumber
   ```

2. **重新编译**：
   ```bash
   ./scripts/build/build_libphonenumber.sh arm64-v8a
   ```

3. **检查日志**：
   - 查看 `logs/build/libphonenumber_arm64-v8a_configure.log`
   - 查看 `logs/build/libphonenumber_arm64-v8a_build.log`

如果仍有问题，请提供最新的编译日志以便进一步诊断。
