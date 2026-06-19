# HarmonyOS 交叉编译指南（基于华为开发者文档）

参考：[华为开发者博客 - 常见C/C++开源三方软件HarmonyOS交叉编译](https://developer.huawei.com/consumer/cn/blog/topic/03203338118552006)

## 📋 目录

1. [系统环境准备](#系统环境准备)
2. [HarmonyOS交叉编译工具链准备](#harmonyos交叉编译工具链准备)
3. [CMake构建方式](#cmake构建方式)
4. [configure构建方式](#configure构建方式)
5. [make构建方式](#make构建方式)
6. [meson构建方式](#meson构建方式)
7. [HarmonyOS化代码常见修改](#harmonyos化代码常见修改)

## 1. 系统环境准备

### 1.1 依赖组件

常见的三方软件编译依赖以下组件：

- autoconf
- ninja-build
- meson
- automake
- libtool
- texinfo
- m4
- pkg-config
- flex
- bison
- autopoint

### 1.2 安装命令

```bash
sudo apt install autoconf automake libtool texinfo ninja-build meson
sudo apt install m4 pkg-config python3-pip flex bison autopoint
pip3 install meson --upgrade  # 更新meson至最新，部分sdk编译需要高版本meson
```

## 2. HarmonyOS交叉编译工具链准备

### 2.1 下载工具链

1. 从华为开发者官网下载编译工具链：[下载链接](https://developer.huawei.com/consumer/cn/download/)
2. 下载最新的 **Command Line Tools**
3. 下载后解压（本文默认解压目录为 `/opt/harmony/ctl`，可根据自身情况设定文件夹）

### 2.2 设置环境变量

```bash
export OHOS_SDK=/opt/harmony/ctl/openharmony  # 配置SDK路径，此处需配置成自己的sdk解压目录
export OHOS_NDK=${OHOS_SDK}/native  # NDK路径
export OHOS_API_LEVEL=9  # API级别，根据实际情况设置
```

## 3. CMake构建方式

### 3.1 基本配置

对于解压后代码根路径包含 `CMakeLists.txt` 的项目，使用以下方式：

```bash
mkdir build && cd build  # 创建编译文件夹
mkdir -p /opt/harmony/xxx  # 创建安装文件夹

# 使用 ohos.toolchain.cmake 工具链文件
${OHOS_SDK}/native/build-tools/cmake/bin/cmake \
    -DCMAKE_TOOLCHAIN_FILE=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake \
    -DOHOS_ARCH=arm64-v8a \
    -DCMAKE_INSTALL_PREFIX=/opt/harmony/xxx \
    ..

make -j  # 启用所有核编译
make install  # 安装到对应目录
```

### 3.2 关键参数说明

| 参数 | 说明 |
|------|------|
| `CMAKE_TOOLCHAIN_FILE` | 指定工具链文件路径（必须） |
| `OHOS_ARCH` | 目标架构：`arm64-v8a`、`armeabi-v7a`、`x86_64` |
| `OHOS_STL` | C++库链接方式：`c++_static`（静态）或 `c++_shared`（动态） |
| `CMAKE_INSTALL_PREFIX` | 安装路径 |

### 3.3 本项目中的实现

本项目已自动配置 CMake 构建，所有构建脚本都会：

1. 自动检测 `ohos.toolchain.cmake` 文件位置
2. 设置正确的 `OHOS_ARCH` 和 `OHOS_STL`
3. 配置 `CMAKE_FIND_ROOT_PATH` 限制依赖搜索范围
4. 使用正确的 C++ 标准（C++17）

## 4. configure构建方式

### 4.1 设置环境变量

```bash
export OHOS_SDK=/opt/harmony/ctl/openharmony
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export CC="${OHOS_SDK}/native/llvm/bin/aarch64-unknown-linux-ohos-clang --target=aarch64-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/aarch64-unknown-linux-ohos-clang++ --target=aarch64-linux-ohos"
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export CFLAGS="-fPIC -D__MUSL__=1"  # 32bit需要增加配置 -march=armv7a
export CXXFLAGS="-fPIC -D__MUSL__=1"
```

**重要说明：**
- 使用 `aarch64-unknown-linux-ohos-clang` 避免出现不兼容c99语法
- 使用 `aarch64-unknown-linux-ohos-clang++` 避免出现不兼容问题
- 必须添加 `--target=aarch64-linux-ohos` 参数

### 4.2 生成configure文件

```bash
chmod +x autogen.sh  # 增加脚本执行权限
./autogen.sh  # 生成configure文件
```

### 4.3 执行编译

```bash
mkdir -p /opt/harmony/xxx  # 创建安装文件夹
./configure --host=aarch64-linux --prefix=/opt/harmony/xxx
# 如果需要添加其余选项，可使用 ./configure --help 查看
# 常见选项有启用OpenSSL（--with-openssl=xxxxx(openssl install路径)），
# 交叉编译宿主路径（部分三方软件如icu交叉编译依编译产物 --with-cross-build=xxxx）
make -j
make install
```

## 5. make构建方式

### 5.1 设置环境变量

与 configure 方式相同，参考 [4.1 设置环境变量](#41-设置环境变量)

### 5.2 执行编译

```bash
mkdir -p /opt/harmony/xxx  # 创建安装文件夹
make -j
make install PREFIX=/opt/harmony/xxx
```

## 6. meson构建方式

### 6.1 创建交叉编译文件

在代码根目录创建 `arm64-v8a-cross-file.txt`，具体内容如下：

```ini
[binaries]
c = '/opt/harmony/ctl/openharmony/native/llvm/bin/aarch64-unknown-linux-ohos-clang'
cpp = '/opt/harmony/ctl/openharmony/native/llvm/bin/aarch64-unknown-linux-ohos-clang++'
ar = '/opt/harmony/ctl/openharmony/native/llvm/bin/llvm-ar'
strip = '/opt/harmony/ctl/openharmony/native/llvm/bin/llvm-strip'
ld = '/opt/harmony/ctl/openharmony/native/llvm/bin/ld.lld'
pkgconfig = '/usr/bin/pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'arm64-v8a'
endian = 'little'

[properties]
needs_exe_wrapper = true
skip_sanity_check = true
sys_root = ''
platform = 'generic'
pkg_config_libdir = ''

[built-in options]
c_args = ['-D__MUSL__=1', '-mfpu=neon']
cpp_args = ['-D__MUSL__=1', '-mfpu=neon']
c_link_args = []
cpp_link_args = []
```

### 6.2 依赖项处理

#### 环境可联网

```bash
meson setup build --cross-file ./arm64-v8a-cross-file.txt
```

#### 环境不可联网

修改 `subprojects` 下相关 `.wrap` 文件：

```ini
[wrap-file]
directory = libffi  # 解压路径
source_url = file:///home/xxx/libffi-v3.4.4.zip  # file://开头拼接文件全路径
source_filename = libffi-v3.4.4.zip  # 文件名
source_hash = XXX
```

执行命令：

```bash
meson setup build --cross-file ./arm64-v8a-cross-file.txt --wrap-mode=nodownload --force-fallback-for=all
# 最后参数为关闭联网下载
```

#### 兜底方式（单独编译依赖子项）

按照上述方式分别编译并安装相关依赖项，并将所有依赖项的安装目录的 `lib/pkgconfig` 文件夹复制出来，用 `:` 分割，设置为 `pkg-config-path`：

```bash
meson setup build --cross-file ./arm64-v8a-cross-file.txt \
    --pkg-config-path=/home/skjx/mailcore/pcre/lib/pkgconfig:/home/skjx/mailcore/libffi/lib/pkgconfig
```

### 6.3 编译构建

```bash
cd build
ninja
```

## 7. HarmonyOS化代码常见修改

### 7.1 系统函数缺失

部分 Linux 系统函数 HarmonyOS 未实现，需手动修改：

- **qsort_r**：需手动替换为 `qsort`（删除最后的 data 参数）
- 其他缺失的系统函数需要根据实际情况进行适配

### 7.2 本项目中的处理

本项目已通过补丁文件处理常见的 HarmonyOS 兼容性问题：

- `patches/icu-harmony.patch` - ICU 库适配
- `patches/openssl-harmony.patch` - OpenSSL 库适配
- `patches/sqlite-harmony.patch` - SQLite 库适配
- `patches/tdlib-harmony.patch` - TDLib 适配

## 8. 本项目的最佳实践

### 8.1 编译器选择优先级

本项目按照华为文档建议，按以下优先级选择编译器：

1. `aarch64-unknown-linux-ohos-clang`（华为文档推荐）
2. `aarch64-linux-ohos{API_LEVEL}-clang`（带API级别）
3. `aarch64-linux-ohos-clang`（通用格式）
4. `clang`（回退选项）

### 8.2 环境变量设置

本项目在 `config.sh` 中自动设置：

- ✅ 使用 `--target` 参数避免不兼容问题
- ✅ 设置 `-fPIC -D__MUSL__=1` 标志
- ✅ 正确配置工具链路径
- ✅ 支持 Windows 环境（.exe 扩展名）

### 8.3 CMake 配置

所有 CMake 构建脚本都会：

- ✅ 使用 `ohos.toolchain.cmake` 工具链文件
- ✅ 设置 `OHOS_ARCH` 和 `OHOS_STL`
- ✅ 配置 `CMAKE_FIND_ROOT_PATH` 限制搜索范围
- ✅ 使用 C++17 标准（如需要）

## 9. 快速开始

### 9.1 初始化配置

```bash
# 创建用户配置文件
# 由 builder.sh 配置菜单自动生成
./builder.sh  # 主菜单 → 5. 配置管理 → 配置后选 9 保存

# 编辑配置文件，设置 HarmonyOS SDK 路径
export OHOS_NDK="/path/to/harmony/ndk"
export OHOS_API_LEVEL=9
```

### 9.2 完整构建

```bash
# 完整构建流程（下载 → 编译 → 打包）
./builder.sh --full

# 或仅编译现有源码
./builder.sh --build

# 或编译单个架构
./builder.sh --arch=arm64-v8a
```

### 9.3 验证构建结果

```bash
# 验证构建结果
./scripts/verify_build.sh --arch arm64-v8a

# 检查库文件格式
file install/arm64-v8a/lib/*.a
# 应该显示：ELF 64-bit LSB shared object, ARM aarch64
```

## 10. 参考资源

- [华为开发者博客 - 常见C/C++开源三方软件HarmonyOS交叉编译](https://developer.huawei.com/consumer/cn/blog/topic/03203338118552006)
- [HarmonyOS NDK 编译指南](https://developer.harmonyos.com/)
- [本项目构建指南](BUILD_GUIDE.md)
- [用户配置指南](USER_CONFIG.md)

## 11. 常见问题

### Q1: 编译器找不到怎么办？

**A:** 检查 `OHOS_NDK` 路径是否正确，确保工具链目录存在：
```bash
ls ${OHOS_NDK}/native/llvm/bin/aarch64-unknown-linux-ohos-clang
```

### Q2: CMake 找不到工具链文件？

**A:** 确保 `ohos.toolchain.cmake` 文件存在：
```bash
ls ${OHOS_NDK}/native/build/cmake/ohos.toolchain.cmake
```

### Q3: 编译时出现不兼容的 C99 语法错误？

**A:** 确保使用 `aarch64-unknown-linux-ohos-clang` 并添加 `--target` 参数。

### Q4: 如何查看详细的编译日志？

**A:** 编译日志保存在 `logs/build/` 目录下，可以查看对应库的日志文件。
