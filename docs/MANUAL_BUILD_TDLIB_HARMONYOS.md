# 手动编译 TDLib for HarmonyOS 详细指南（已自动化）

本指南对应《手动编译 TDLib for HarmonyOS 详细指南》的流程，已通过脚本实现**按上述方式自动化**，可在项目内直接使用。

---

## 1. 准备工作

### 1.1 目录结构

使用本项目的标准布局：

```
tdlib-harmony-builder/
├── src/extracted/td-1.8.0/   # TDLib 源码
├── build/<arch>/tdlib/       # 构建目录
├── install/<arch>/           # 安装目录
├── logs/build/               # 日志
└── scripts/
    ├── set_env_manual.sh     # 手动编译环境变量
    └── build/
        ├── build_tdlib_manual.sh           # 一键执行手动流程
        └── ensure_manual_api_placeholders.sh # API 占位符创建
```

### 1.2 环境变量（MSYS2/WSL）

```bash
# 加载项目配置后，可用：
source config.sh
source scripts/set_env_manual.sh arm64-v8a

# 将设置：
#   OHOS_SDK, CC, CXX, AR, RANLIB, STRIP
#   CMAKE_TOOLCHAIN, SYSROOT
#   TD_SRC, TD_BUILD, TD_INSTALL
```

---

## 2. API 文件与占位符（指南 §2）

### 2.1 自动创建占位符

脚本 `ensure_manual_api_placeholders.sh` 会创建：

- `td/mtproto/mtproto_api.h`
- `td/telegram/telegram_api.h`, `secret_api.h`, `td_api.h`
- `td/generate/auto/td/...` 下对应 `.h` / `.hpp` / `.cpp`
- `tdutils/generate/auto` 下 MIME 占位符
- `td/generate/auto/tlo/*.tlo` 空文件

**说明**：占位符仅用于满足 CMake 对文件存在性的要求。**完整可链接的 TDLib 必须使用真实 API 文件**（由主机代码生成器生成）。参见 [TDLIB_API_GENERATION_FIX.md](TDLIB_API_GENERATION_FIX.md)。

### 2.2 禁用代码生成器

交叉编译时，TDLib 的 CMake 已不会构建/运行主机端生成器；我们通过占位符或预生成 API 文件替代。无需再手动注释 `add_subdirectory(generate)`。

---

## 3. 依赖库（指南 §3）

### 3.1 自动编译依赖

`build_tdlib_manual.sh` 默认会依次运行：

- `build_zlib.sh`, `build_openssl.sh`
- `build_sqlite.sh`, `build_icu.sh`, `build_protobuf.sh`
- `build_crc32c.sh`, `build_xxhash.sh`, `build_abseil.sh`
- `build_re2.sh`, `build_libphonenumber.sh`
- `build_double_conversion.sh`, `build_snappy.sh`, `build_lz4.sh`, `build_libevent.sh`

若依赖已就绪，可加 `--skip-deps` 跳过。

---

## 4. 配置与构建（指南 §4–5）

### 4.1 一键执行（推荐）

```bash
# 完整流程：依赖 + 占位符（若无 API）+ 配置 + 编译 + 安装
./scripts/build/build_tdlib_manual.sh arm64-v8a

# 跳过依赖编译
./scripts/build/build_tdlib_manual.sh arm64-v8a --skip-deps

# 强制使用 API 占位符（方便调试，链接会失败）
./scripts/build/build_tdlib_manual.sh arm64-v8a --placeholder-api
```

### 4.2 分步执行

```bash
source config.sh
source scripts/set_env_manual.sh arm64-v8a

# 1. 依赖（可选）
./scripts/build/build_zlib.sh arm64-v8a
./scripts/build/build_openssl.sh arm64-v8a
# ... 其余依赖

# 2. API 占位符（仅当无预生成 API 且欲走占位符流程时）
export TD_SRC="$(pwd)/src/extracted/td-1.8.0"
source scripts/build/ensure_manual_api_placeholders.sh

# 3. 配置
mkdir -p "$TD_BUILD" && cd "$TD_BUILD"
cmake "$TD_SRC" -GNinja \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$TD_INSTALL" \
  -DOPENSSL_ROOT_DIR="$TD_INSTALL" \
  -DZLIB_ROOT="$TD_INSTALL" \
  -DBUILD_AUTO_TOOLS=OFF \
  -DBUILD_GENERATOR=OFF \
  -DTD_ENABLE_JNI=OFF \
  # ... 其余 -D 见 build_tdlib_manual.sh

# 4. 编译与安装
ninja -j4
ninja install
```

---

## 5. 验证（指南 §8）

安装完成后，脚本会调用 `verify_build_result` 检查：

- `libtdclient.a`, `libtdcore.a`, `libtdapi.a`（及若生成则 `libtdjson.so`）
- 头文件目录 `td/telegram` 等

也可手动检查：

```bash
ls -la install/arm64-v8a/lib/libtd*.a
ls -la install/arm64-v8a/include/td/
```

---

## 6. 故障排除（指南 §10）

| 现象 | 处理 |
|------|------|
| CMake 找不到工具链 | 确认 `OHOS_NDK` / `OHOS_SDK`，检查 `CMAKE_TOOLCHAIN` 路径 |
| 缺少 OpenSSL/zlib | 先跑 `build_zlib`、`build_openssl`，或去掉 `--skip-deps` |
| 链接错误 | 使用 `-static-libstdc++`、正确 `-L` / `-l` 顺序；确认使用**真实 API 文件**而非占位符 |
| C++ 标准库问题 | 使用 `-DOHOS_STL=c++_static` |

---

## 7. 与指南的对应关系

| 指南章节 | 本仓库实现 |
|----------|------------|
| §1 准备工作 | `config.sh`, `set_env_manual.sh` |
| §2 手动解决 API | `ensure_manual_api_placeholders.sh`，或预生成 API |
| §3 编译依赖 | 各 `build_*.sh`，可由 `build_tdlib_manual.sh` 统一调用 |
| §4 手动配置 | `build_tdlib_manual.sh` 内 CMake 配置 |
| §5 分步执行 | `build_tdlib_manual.sh` 或上述分步命令 |
| §8 验证 | `verify_build_result` |

---

## 8. 总结

- **自动化入口**：`./scripts/build/build_tdlib_manual.sh [arch] [--skip-deps] [--placeholder-api]`
- **环境**：`source scripts/set_env_manual.sh [arch]`
- **占位符**：`source scripts/build/ensure_manual_api_placeholders.sh`（需已设置 `TD_SRC`）
- **完整可用的 TDLib**：必须使用**真实生成的 API 文件**，参见 [TDLIB_API_GENERATION_FIX.md](TDLIB_API_GENERATION_FIX.md)；占位符仅用于流程调试或验证配置。
