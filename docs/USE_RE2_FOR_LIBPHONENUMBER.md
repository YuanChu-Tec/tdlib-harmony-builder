# 使用 RE2 替代 ICU 编译 libphonenumber

## 概述

libphonenumber 支持两种正则表达式引擎：
- **ICU 正则表达式引擎**（默认）：功能完整，但依赖 ICU 库
- **RE2 正则表达式引擎**（推荐）：更轻量，不依赖 ICU，编译更简单

## 为什么推荐使用 RE2？

1. **更轻量**：RE2 不依赖 ICU，减少依赖链
2. **编译更简单**：避免 ICU 相关的编译问题
3. **性能更好**：RE2 专为正则表达式优化
4. **兼容性更好**：在 HarmonyOS 上编译更稳定

## 当前状态检查

运行检查脚本查看依赖状态：

```bash
./scripts/check_dependencies_status.sh arm64-v8a
```

### 检查结果示例

```
检查 ICU: ✅ 库文件存在 ✅ 头文件存在
检查 RE2: ❌ 库文件缺失 ❌ 头文件缺失
检查 Abseil 兼容层: ✅ 存在
```

## 编译步骤

### 步骤 1：编译 RE2（如果尚未编译）

```bash
./scripts/build/build_re2.sh arm64-v8a
```

### 步骤 2：编译 libphonenumber

libphonenumber 构建脚本会自动检测 RE2 是否可用：

- **如果 RE2 可用**：自动使用 RE2（`USE_RE2=ON`, `USE_ICU_REGEXP=OFF`）
- **如果 RE2 不可用但 ICU 可用**：使用 ICU（`USE_RE2=OFF`, `USE_ICU_REGEXP=ON`）
- **如果两者都不可用**：尝试使用 ICU（可能失败）

```bash
./scripts/build/build_libphonenumber.sh arm64-v8a
```

## 手动指定使用 RE2

如果需要强制使用 RE2（即使 ICU 也可用），可以修改构建脚本或设置环境变量：

```bash
# 在 build_libphonenumber.sh 中，修改检测逻辑
# 将 USE_RE2_FOR_REGEXP 设置为 true
```

## 验证编译结果

编译成功后，检查生成的库：

```bash
ls -lh install/arm64-v8a/lib/libphonenumber.a
```

## 常见问题

### Q: RE2 和 ICU 可以同时使用吗？

A: 不可以。libphonenumber 只能使用一种正则表达式引擎。如果同时设置了 `USE_RE2=ON` 和 `USE_ICU_REGEXP=ON`，RE2 会优先。

### Q: 使用 RE2 会影响功能吗？

A: 不会。RE2 和 ICU 在 libphonenumber 中的功能是等价的，只是底层实现不同。

### Q: 如果 RE2 编译失败怎么办？

A: 可以回退到使用 ICU。确保 ICU 已正确编译，然后 libphonenumber 构建脚本会自动使用 ICU。

## 技术细节

### CMake 配置

使用 RE2 时的 CMake 配置：

```cmake
-DUSE_RE2=ON
-DUSE_ICU_REGEXP=OFF
-DRE2_ROOT="${ARCH_INSTALL_DIR}"
-DRE2_INCLUDE_DIR="${ARCH_INSTALL_DIR}/include"
-DRE2_LIB="${ARCH_INSTALL_DIR}/lib/libre2.a"
```

### 代码中的使用

libphonenumber 会根据 CMake 配置自动选择正则表达式引擎：

- `USE_RE2=ON` → 使用 `regexp_adapter_re2.cc`
- `USE_ICU_REGEXP=ON` → 使用 `regexp_adapter_icu.cc`

## 相关文件

- `scripts/build/build_re2.sh` - RE2 编译脚本
- `scripts/build/build_libphonenumber.sh` - libphonenumber 编译脚本（已支持自动检测 RE2）
- `scripts/check_dependencies_status.sh` - 依赖状态检查脚本

## 参考

- [RE2 官方文档](https://github.com/google/re2)
- [libphonenumber CMake 选项](https://github.com/google/libphonenumber/blob/master/cpp/CMakeLists.txt)
