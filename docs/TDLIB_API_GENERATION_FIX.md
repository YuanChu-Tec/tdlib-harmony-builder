# TDLib API 文件生成修复

## 📋 问题描述

TDLib 编译失败，错误信息：
```
fatal error: 'td/mtproto/mtproto_api.h' file not found
```

## 🔍 问题根本原因

TDLib 的核心 API 和协议层代码（包括 `mtproto_api.h`、`td_api.h` 等）是在 CMake **配置阶段**由内部工具自动生成的。这些文件是从 `.tl` 文件（Type Language 定义文件）生成的。

**关键问题**：
1. TDLib 源码中的预生成文件都是**占位符**，不是真正的 API 文件
2. TDLib 的 CMakeLists.txt 在交叉编译时（`if (NOT CMAKE_CROSSCOMPILING)`）**不会自动生成**这些文件
3. 需要**手动使用主机工具**生成这些文件

## ✅ 修复方案

### 1. 一键真实生成 API（推荐）

项目提供 **`scripts/build/generate_tdlib_api.sh`**，在主机端构建 `tl-parser`、`generate_common` 并生成真实 API 文件：

```bash
./scripts/build/generate_tdlib_api.sh [arm64-v8a]
```

- **Windows/MSYS2**：脚本会自动应用 `wgetopt` 兼容修复（补丁 + `scripts/fix_wgetopt_c_windows.py`）。
- 生成目录：`build/tdlib-api-generator`；输出写入 `td/generate/auto/...`，并复制 `mtproto_api.h` 到 `td/mtproto/`。
- **`build_tdlib.sh`**、**`build_tdlib_manual.sh`** 在检测到 API 缺失或占位符时，会**自动调用**本脚本；无需单独执行（除非你想先生成再编译）。

### 2. 使用主机工具生成 API 文件（手动流程）

在配置 TDLib 之前，使用主机编译器构建代码生成器并运行：

**步骤**：
1. 使用主机编译器配置 TDLib（不使用工具链文件）
2. 构建代码生成器工具：
   - `tl-parser` - 解析 .tl 文件
   - `tdtl` - Type Language 库
   - `generate_common` - 生成 API 文件
3. 运行生成器：
   - 使用 `tl-parser` 生成 TLO 文件
   - 使用 `generate_common` 生成所有 API 文件
4. 验证生成的文件不是占位符
5. 继续交叉编译 TDLib

### 3. 实现细节

**主机工具构建目录**（`generate_tdlib_api.sh` 使用）：
```bash
HOST_BUILD_DIR="${BUILD_DIR}/tdlib-api-generator"
```

**构建步骤**：
```bash
# 1. 配置主机版本（不使用工具链文件）
cmake "$SOURCE_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DTD_ENABLE_OPENSSL=OFF \
    -DTD_ENABLE_PARSER=OFF \
    ...

# 2. 构建生成器工具
cmake --build . --target tl-parser
cmake --build . --target tdtl
cmake --build . --target generate_common

# 3. 运行生成器
cd "$SOURCE_DIR/td/generate"
./tl-parser -e auto/tlo/mtproto_api.tlo scheme/mtproto_api.tl
./generate_common
```

**生成的文件位置**：
- `td/generate/auto/td/telegram/td_api.cpp/h/hpp`
- `td/generate/auto/td/mtproto/mtproto_api.h`
- `td/mtproto/mtproto_api.h`（需要复制）

### 4. 验证生成的文件

**检查文件是否存在**：
```bash
if [[ -f "$MT_PROTO_SOURCE_H" ]]; then
    # 检查是否是真正的文件（不是占位符）
    if ! grep -q "Auto-generated placeholder" "$MT_PROTO_SOURCE_H"; then
        log_success "API 文件已成功生成"
    fi
fi
```

## 📊 修复效果

### 修复前
- ❌ 使用占位符文件，编译失败
- ❌ 编译器找不到 `mtproto_api.h`
- ❌ TDLib 无法正常编译

### 修复后
- ✅ 使用主机工具生成真正的 API 文件
- ✅ 文件被正确复制到源目录
- ✅ 编译器能够找到所有必需的头文件
- ✅ TDLib 可以正常编译

## 🎯 确保 TDLib 功能完整性

### 生成的 API 文件

所有 TDLib 需要的 API 文件都会被生成：

1. **td_api 文件**：
   - `td_api.cpp` - Telegram API 实现
   - `td_api.h` - Telegram API C 头文件
   - `td_api.hpp` - Telegram API C++ 头文件

2. **mtproto_api 文件**：
   - `mtproto_api.h` - MTProto API 头文件
   - `mtproto_api.cpp` - MTProto API 实现（如果需要）

3. **其他 API 文件**：
   - `telegram_api.h/cpp` - Telegram API
   - `secret_api.h/cpp` - Secret API

### 验证机制

编译脚本会自动验证：
- ✅ 文件是否存在
- ✅ 文件是否可读
- ✅ 文件是否非空
- ✅ 文件不是占位符

## 📝 代码变更

### 新增的主机工具生成逻辑

```bash
# 检查是否需要生成文件
if [[ "$NEED_GENERATE" == "true" ]]; then
    # 创建主机工具构建目录
    HOST_GEN_BUILD_DIR="${ARCH_BUILD_DIR}/tdlib-host-generator"
    
    # 使用主机编译器配置
    cmake "$SOURCE_DIR" -DCMAKE_BUILD_TYPE=Release ...
    
    # 构建生成器工具
    cmake --build . --target tl-parser
    cmake --build . --target tdtl
    cmake --build . --target generate_common
    
    # 运行生成器
    ./tl-parser -e auto/tlo/mtproto_api.tlo scheme/mtproto_api.tl
    ./generate_common
fi
```

### 文件验证逻辑

```bash
# 验证文件不是占位符
if grep -q "Auto-generated placeholder" "$MT_PROTO_SOURCE_H"; then
    log_warning "警告：文件仍然是占位符"
else
    log_success "API 文件已成功生成"
fi
```

## 🔧 使用说明

### 单独生成 API（可选）

```bash
./scripts/build/generate_tdlib_api.sh [arm64-v8a]
```

生成完成后，再执行 `build_tdlib.sh` 或 `build_tdlib_manual.sh` 即可直接使用真实 API 进行交叉编译。

### 编译 TDLib（自动生成 API）

```bash
./scripts/build/build_tdlib.sh arm64-v8a
# 或
./scripts/build/build_tdlib_manual.sh arm64-v8a
```

当检测到 API 缺失或为占位符时，会**自动调用** `generate_tdlib_api.sh` 生成真实 API，再继续配置与编译。

### 验证生成的文件

编译脚本会自动验证：
- ✅ 文件是否存在
- ✅ 文件是否可读
- ✅ 文件是否非空
- ✅ 文件不是占位符

## 🪟 Windows / MSYS2 下的 wgetopt 修复

在 Windows 或 MSYS2 上构建主机代码生成器时，`tl-parser` 依赖的 `wgetopt.c` / `wgetopt.h` 可能与系统头文件中的 `getenv` / `getopt` 声明冲突，导致编译失败。

**处理方式**：`generate_tdlib_api.sh` 在检测到 Windows/MSYS2 时会自动：

1. **wgetopt.h**：应用 `patches/tdlib-tl-parser-wgetopt-windows.patch`，将 `extern int getopt ();` 改为完整原型，避免 "expected 0, have 3" 错误。
2. **wgetopt.c**：运行 `scripts/fix_wgetopt_c_windows.py`：
   - 在 `!__GNU_LIBRARY__` 时添加 `#include <stdlib.h>`
   - 移除 `extern char *getenv();` 自声明
   - 在 `_WIN32` / `__MINGW32__` / `__MSYS__` 下用 `posixly_correct = NULL` 替代 `getenv("POSIXLY_CORRECT")`

应用上述修复后，主机生成器应能在 MSYS2 等环境下正常编译。

## ⏭️ 主机生成器失败时

若 `generate_tdlib_api.sh` 在本机失败（如 Windows 上 wgetopt 修复仍不足），可：

1. **单独调试生成**：`./scripts/build/generate_tdlib_api.sh`，查看 `logs/build/generate_tdlib_api_*.log`，确认 wgetopt 补丁与 `fix_wgetopt_c_windows.py` 已正确应用。
2. **使用预生成 API**：在 Linux 或 Docker 中完成一次 `generate_tdlib_api.sh`，将 `td/generate/auto/`、`td/mtproto/mtproto_api.h` 等拷贝到本机对应路径，再运行 `build_tdlib.sh`。
3. **占位符流程（仅调试）**：`build_tdlib_manual.sh --placeholder-api` 使用占位符；可完成配置，但链接会失败，仅用于排查环境。

## ⚠️ 注意事项

1. **主机编译器要求**
   - 需要可用的主机 C++ 编译器（g++、clang++ 等）
   - 需要 CMake 工具

2. **生成器构建失败**
   - 若主机工具构建失败，会尝试使用占位符文件
   - 占位符文件会导致 TDLib 编译失败
   - 建议先应用 wgetopt 补丁（Windows）或使用 `TD_SKIP_HOST_GENERATOR` 并自行准备 API 文件

3. **文件位置**
   - 生成的文件在 `td/generate/auto/` 目录中
   - 需要复制到 `td/mtproto/` 目录供编译器使用

## ✅ 总结

通过本次修复：
- ✅ 添加了主机代码生成器逻辑
- ✅ 自动检测是否需要生成文件
- ✅ 使用主机工具生成真正的 API 文件
- ✅ 验证生成的文件不是占位符
- ✅ 确保 TDLib 功能完整性

TDLib 现在可以正常编译，API 文件会被正确生成。
