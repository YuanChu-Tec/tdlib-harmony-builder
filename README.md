# TDLib for HarmonyOS 自动化编译系统

自动化编译 TDLib 及其所有依赖库，适配 HarmonyOS 平台（arm64-v8a / armeabi-v7a / x86_64）。

## 🚀 快速开始

### 1. 运行交互菜单

```bash
./builder.sh
```

首次运行会自动检测 NDK 路径，引导完成基本配置。

### 2. 使用菜单操作

```
主菜单:
  1. 构建操作     → 完整构建 / 分步构建
  2. 清理操作     → 清理构建缓存或全部清除
  3. 测试操作     → 测试构建系统
  4. 系统信息     → 查看环境信息
  5. 配置管理     → 设置 NDK / API / 版本 / 架构
  0. 退出
```

### 3. 完整构建

选择 **1. 构建操作** → **1. 完整构建（所有架构）**，或直接：

```bash
./builder.sh --full
```

### 4. 构建完成

编译完成后选择打包，或使用：

```bash
./builder.sh --package
```

打包产物在 `dist/` 目录：
```
dist/
└── tdlib-harmonyos-{version}-{date}/
    ├── include/           # TDLib 头文件
    ├── libs/
    │   ├── arm64-v8a/     # 64位 ARM 静态库/动态库
    │   ├── armeabi-v7a/   # 32位 ARM 静态库
    │   └── x86_64/        # 64位 x86 静态库
    ├── cmake/             # CMake 查找模块
    ├── tdlib-config.cmake # CMake 配置文件
    └── README.md          # 使用说明
```

### 5. 在项目中使用

```cmake
# CMakeLists.txt
set(OHOS_ARCH_ABI "arm64-v8a")  # 可选: arm64-v8a, armeabi-v7a, x86_64
list(APPEND CMAKE_PREFIX_PATH "path/to/tdlib-harmonyos")
find_package(tdlib REQUIRED)
target_link_libraries(your_app TDLib::TDLib)
```

---

## 📁 项目结构

```
tdlib-harmony-builder/
├── builder.sh                  # 主入口脚本（交互菜单 + CLI）
├── config.sh                   # 通用配置（所有脚本共享）
├── user_config.sh              # 用户配置（由菜单生成，不提交）
├── scripts/
│   ├── build_all.sh            # 全量编译入口
│   ├── common.sh               # 公共函数库
│   ├── extract_sources.sh      # 解压源码
│   ├── apply_patches.sh        # 应用补丁
│   ├── verify_build.sh         # 验证编译结果
│   ├── cleanup.sh              # 清理构建
│   ├── package_dist.sh         # 打包发布
│   └── build/                  # 各依赖库编译脚本
│       ├── build_tdlib.sh      # 编译 TDLib
│       ├── build_openssl.sh    # 编译 OpenSSL
│       ├── build_protobuf.sh   # 编译 Protocol Buffers
│       └── build_*.sh          # 其他依赖库
├── cmake/
│   └── FindTDLib.cmake         # CMake 查找模块
├── patches/                    # HarmonyOS 适配补丁
└── dist/                       # 打包产物目录
```

---

## ⚙️ 配置管理

所有配置通过 **主菜单 → 5. 配置管理** 进行：

```
路径配置:
  1. 设置 NDK 路径         # HarmonyOS NDK 安装路径
  2. 设置 API 级别         # 如 9, 12, 23

版本配置:
  3. 设置 TDLib 源码版本   # 实际 TDLib 版本
  4. 设置 HarmonyOS 适配版本

构建配置:
  5. 设置目标架构          # 多选用空格分隔
  6. 设置构建模式          # Release / Debug / Profile
  7. 设置并行任务数        # 默认: CPU核心数-1

  8. 查看当前配置          # 显示所有配置 + 工具链有效性
  9. 保存配置并退出        # 写入 user_config.sh
  0. 返回主菜单            # 不保存
```

配置保存后自动写入 `user_config.sh`，下次启动自动加载。

---

## 🔧 CLI 命令

| 命令 | 说明 |
|:-----|:------|
| `./builder.sh` | 启动交互菜单 |
| `./builder.sh --full` | 完整构建（解压 + 编译 + 打包） |
| `./builder.sh --extract` | 仅解压源码 |
| `./builder.sh --build` | 仅编译现有源码（所有架构） |
| `./builder.sh --build-package` | 编译并打包 |
| `./builder.sh --package` | 仅打包已编译的库 |
| `./builder.sh --help` | 显示帮助信息 |

---

## 🛠️ 构建的依赖库

| 库 | 用途 | 备注 |
|:---|:-----|:------|
| OpenSSL | 加密支持 | 含 libcrypto.a, libssl.a |
| zlib | 压缩 | |
| SQLite | 本地存储 | |
| ICU | Unicode 支持 | 含 libicuuc.a, libicudata.a, libicui18n.a |
| Protocol Buffers | 序列化 | protobuf 3.21.12 |
| crc32c | CRC32C 校验 | |
| xxhash | 哈希 | |
| Abseil | Google 基础库 | |
| RE2 | 正则表达式 | |
| libevent | 事件循环 | 含 event, event_core, event_extra, event_pthreads |
| lz4 | 快速压缩 | |
| snappy | 压缩 | |
| double-conversion | 数字转换 | |
| libphonenumber | 电话号码处理 | |
| **TDLib** | Telegram 库 | 核心产物 |

---

## 📝 许可证

各库有其自己的许可证，请参考各库的 LICENSE 文件。
