# Abseil 库集成指南

## 概述

Abseil 是 Google 开发的 C++ 基础库集合，RE2 和 Protobuf 等库依赖它。本项目已集成 Abseil 的编译支持。

## 为什么需要 Abseil？

1. **RE2 依赖**：RE2 正则表达式库需要 Abseil
2. **Protobuf 依赖**：Protobuf 33.4+ 版本依赖 Abseil
3. **更好的兼容性**：使用完整的 Abseil 库比兼容层更可靠

## 编译顺序

Abseil 需要在以下库之前编译：
- **RE2**：RE2 依赖 Abseil
- **Protobuf 33.4+**：新版本 Protobuf 依赖 Abseil

正确的编译顺序：
```bash
1. zlib
2. openssl
3. sqlite
4. icu
5. protobuf
6. crc32c
7. xxhash
8. abseil    # ← 在 RE2 之前
9. re2       # ← 依赖 Abseil
10. libevent
11. lz4
12. snappy
13. double-conversion
14. libphonenumber
15. tdlib
```

## 配置

### 版本配置

在 `config.sh` 中：
```bash
export ABSEIL_VERSION_DEFAULT="20240116.2"
```

这是 Abseil 的 LTS（长期支持）版本，格式为 `YYYYMMDD.PATCH`。

### 下载 URL

Abseil 使用 GitHub 标签格式：`lts-20240116.2`
- 下载 URL：`https://github.com/abseil/abseil-cpp/archive/refs/tags/lts-20240116.2.tar.gz`
- 解压后目录：`abseil-cpp-lts-20240116.2`

## 编译步骤

### 1. 下载源码

```bash
./scripts/download_sources.sh
```

### 2. 单独编译 Abseil

```bash
./scripts/build/build_abseil.sh arm64-v8a
```

### 3. 编译所有依赖（推荐）

```bash
./scripts/build_all.sh --arch arm64-v8a
```

`build_all.sh` 会自动按正确顺序编译，包括 Abseil。

## 验证编译结果

### 检查库文件

```bash
# 检查 Abseil 库文件
ls install/arm64-v8a/lib/libabsl_*.a

# 检查头文件
ls install/arm64-v8a/include/absl/
```

### 检查 CMake 配置

```bash
# 检查 CMake 配置文件
ls install/arm64-v8a/lib/cmake/absl/
```

## RE2 使用 Abseil

RE2 构建脚本会自动检测 Abseil：

1. **如果 Abseil 已编译**：使用完整的 Abseil 库
2. **如果 Abseil 未编译**：回退到 Abseil 兼容层（可能不完整）

### 推荐做法

**始终先编译 Abseil**，然后再编译 RE2：

```bash
# 1. 编译 Abseil
./scripts/build/build_abseil.sh arm64-v8a

# 2. 编译 RE2（会自动使用 Abseil）
./scripts/build/build_re2.sh arm64-v8a
```

## 技术细节

### CMake 配置

Abseil 使用 CMake 构建，关键配置：

```cmake
-DCMAKE_TOOLCHAIN_FILE="${OHOS_TOOLCHAIN_FILE}"
-DOHOS_ARCH="arm64-v8a"
-DOHOS_STL=c++_static
-DCMAKE_BUILD_TYPE=Release
-DBUILD_SHARED_LIBS=OFF
-DABSL_BUILD_TESTING=OFF
-DABSL_PROPAGATE_CXX_STD=ON
-DCMAKE_POSITION_INDEPENDENT_CODE=ON
-DCMAKE_CXX_STANDARD=17
```

### 安装位置

- **库文件**：`install/arm64-v8a/lib/libabsl_*.a`
- **头文件**：`install/arm64-v8a/include/absl/`
- **CMake 配置**：`install/arm64-v8a/lib/cmake/absl/`

### RE2 链接 Abseil

RE2 通过 CMake 的 `find_package(absl)` 自动查找 Abseil：

```cmake
# 如果 Abseil 已编译
-Dabsl_DIR="${ARCH_INSTALL_DIR}/lib/cmake/absl"
-DCMAKE_PREFIX_PATH="${ARCH_INSTALL_DIR}"
```

## 常见问题

### Q: Abseil 编译失败怎么办？

A: 检查：
1. HarmonyOS NDK 是否正确配置
2. C++17 标准库是否可用
3. 查看详细日志：`logs/build/abseil_arm64-v8a_build.log`

### Q: RE2 仍然找不到 Abseil？

A: 确保：
1. Abseil 已成功编译和安装
2. `install/arm64-v8a/lib/cmake/absl/` 目录存在
3. RE2 构建脚本检测逻辑正确

### Q: 可以使用 Abseil 兼容层吗？

A: 可以，但不推荐。兼容层可能不完整，导致编译或运行时错误。建议使用完整的 Abseil 库。

## 相关文件

- `scripts/build/build_abseil.sh` - Abseil 编译脚本
- `scripts/build/build_re2.sh` - RE2 编译脚本（已支持自动检测 Abseil）
- `config.sh` - 配置文件（包含 Abseil 版本）
- `scripts/build_all.sh` - 批量编译脚本（包含 Abseil）

## 参考

- [Abseil 官方文档](https://abseil.io/)
- [Abseil GitHub](https://github.com/abseil/abseil-cpp)
- [Abseil LTS 版本](https://github.com/abseil/abseil-cpp/releases)
