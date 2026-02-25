# TDLib HarmonyOS 适配补丁说明

## 概述

在鸿蒙/OpenHarmony 上交叉编译 TDLib 时，需对源码应用适配补丁并可选复制 EventFdPipe 源文件。补丁与复制在 **`build_tdlib.sh`** 中**自动执行**，无需手动操作。

## 补丁与源文件列表

| 补丁/源 | 作用 |
|--------|------|
| `patches/tdlib-harmony-thread-affinity.patch` | 在 HarmonyOS 上**实现**线程亲和（用 gettid + sched_setaffinity/sched_getaffinity） |
| `patches/tdlib-eventfd-pipe/`（EventFdPipe.h/cpp） | 无 eventfd 时用 **pipe** 实现 EventFd，供 MpscPollableQueue 与 AsyncFileLog 使用 |
| `patches/tdlib-harmony-eventfd-pipe.patch` | 将 EventFdPipe 接入 EventFd.h 与 CMakeLists.txt |
| `patches/tdlib-harmony-asyncfilelog-eventfd.patch` | 在仍使用 TD_EVENTFD_UNSUPPORTED 时提供 AsyncFileLog 桩实现（本构建用 TD_EVENTFD_PIPE，可不依赖此补丁） |

## 应用方式

### 自动应用（推荐）

执行 TDLib 编译时，脚本会：

1. 若 `tdutils/td/utils/port/detail/` 下缺少 `EventFdPipe.h`，从 `patches/tdlib-eventfd-pipe/` 复制到源码目录；
2. 在源码根目录依次应用上述补丁。

```bash
./scripts/build/build_tdlib.sh arm64-v8a
```

流程：`setup_build_env` → 定位 `SOURCE_DIR` → **复制 EventFdPipe（若缺）** → **应用 HarmonyOS 补丁** → 生成 API（如需要）→ 配置与编译。

补丁逻辑说明：脚本会先检测目标修改是否已存在于源码；若已存在则只打印「补丁已存在: xxx，跳过」并跳过该补丁（不再执行 `patch`），避免对已打补丁的源码重复打补丁产生失败与警告。重新解压全新 TDLib 源码后再次构建时，会正常应用补丁。

### 手动应用（可选）

在 TDLib 源码根目录下：

```bash
SOURCE_DIR="path/to/td-1.8.0"
PATCHES_DIR="path/to/tdlib-harmony-builder/patches"
DETAIL="$SOURCE_DIR/tdutils/td/utils/port/detail"

# 1. 复制 EventFdPipe 源文件（若缺）
cp "$PATCHES_DIR/tdlib-eventfd-pipe/EventFdPipe.h" "$DETAIL/"
cp "$PATCHES_DIR/tdlib-eventfd-pipe/EventFdPipe.cpp" "$DETAIL/"

# 2. 应用补丁
cd "$SOURCE_DIR"
patch -p1 -i "$PATCHES_DIR/tdlib-harmony-thread-affinity.patch"
patch -p1 -i "$PATCHES_DIR/tdlib-harmony-eventfd-pipe.patch"
patch -p1 -i "$PATCHES_DIR/tdlib-harmony-asyncfilelog-eventfd.patch"
```

## 功能实现情况：两项均已实现

### 1. 线程亲和（thread affinity）— **已实现**

- **实现方式**：在 `TD_HARMONYOS` 下用 `syscall(SYS_gettid)` 取当前线程 TID，再调用 `sched_setaffinity(tid, ...)` / `sched_getaffinity(tid, ...)`。
- **调用场景**：仅 `ConcurrentScheduler` 中当前线程对自身设置亲和（`this_thread::get_id()`），与实现匹配。
- **结论**：鸿蒙上线程亲和**已支持**，行为与 Linux 上设置当前线程亲和一致。

### 2. 异步文件日志（AsyncFileLog）— **已实现**

- **实现方式**：鸿蒙构建使用 **`-DTD_EVENTFD_PIPE=1`**，采用基于 **pipe** 的 `EventFdPipe` 替代 eventfd；`MpscPollableQueue` 与 AsyncFileLog 正常使用该 EventFd。
- **源文件**：`EventFdPipe.h` / `EventFdPipe.cpp` 放在 `patches/tdlib-eventfd-pipe/`，构建时若缺失会复制到 TDLib 源码并借 `tdlib-harmony-eventfd-pipe.patch` 接入。
- **结论**：鸿蒙上异步文件日志**可用**，功能与有 eventfd 的平台一致。

### 总结表

| 功能 | 鸿蒙上状态 |
|------|------------|
| Telegram API、MTProto、网络、加密 | ✅ 完整支持 |
| 消息、用户、群组、文件、秘密聊天等 | ✅ 完整支持 |
| 线程亲和（当前线程绑核） | ✅ **已实现**（gettid + sched_setaffinity） |
| 异步文件日志（AsyncFileLog） | ✅ **已实现**（EventFdPipe） |

在此方案下，TDLib 在鸿蒙上可正确编译并实现**全部**预期功能，无功能裁剪。

## 校验补丁/源是否就绪

在 TDLib 源码根目录下检查：

```bash
# 线程亲和：应包含 TD_HARMONYOS 与 sched_setaffinity
grep -n "TD_HARMONYOS\|sched_setaffinity\|SYS_gettid" tdutils/td/utils/port/detail/ThreadPthread.cpp

# EventFdPipe：应存在并接入
ls tdutils/td/utils/port/detail/EventFdPipe.h
grep -n "TD_EVENTFD_PIPE\|EventFdPipe" tdutils/td/utils/port/EventFd.h
```

## 重新解压源码后

重新下载或解压 TDLib 后，需重新执行：

```bash
./scripts/build/build_tdlib.sh arm64-v8a
```

脚本会再次复制 EventFdPipe（若缺）并应用所有补丁，然后完成配置与编译。

## 相关文档

- API 生成与编译流程：`docs/TDLIB_API_GENERATION_FIX.md`
- 手动/占位符编译：`docs/MANUAL_BUILD_TDLIB_HARMONYOS.md`
