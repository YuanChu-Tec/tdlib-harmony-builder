一.zlib for HarmonyOS

在 HarmonyOS（鸿蒙）上为 TDLib 编译 zlib，核心是**先使用 HarmonyOS 工具链交叉编译 zlib，再让 TDLib 的构建系统链接这个自定义的 zlib**。以下是详细步骤。

## 1. 环境准备
- **安装 HarmonyOS NDK**（通过 DevEco Studio 或单独下载），确保其中包含 `ohos.toolchain.cmake` 工具链文件。
- **准备编译环境**（Linux 或 Windows 下的 WSL），安装 CMake（3.0.2+）、git、make 等基础工具。

## 2. 编译 zlib for HarmonyOS
以下步骤主要参考鸿蒙社区移植 zlib 的实践[reference:0]。

### 2.1 获取源码
```bash
git clone https://github.com/madler/zlib.git
cd zlib
# 建议使用稳定版本，如 1.3.1
git checkout v1.3.1
```

### 2.2 配置编译脚本
创建一个 `build_ohos.sh` 脚本，内容如下（请根据实际路径修改环境变量）：
```bash
#!/bin/bash
# HarmonyOS 工具链路径
export OHOS_SDK=/path/to/harmonyos/ndk
export TOOLCHAIN_FILE=$OHOS_SDK/build/cmake/ohos.toolchain.cmake
# 安装路径
export ZLIB_INSTALL_PATH=$PWD/install_ohos

rm -rf build_ohos
mkdir build_ohos && cd build_ohos

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_FILE \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=$ZLIB_INSTALL_PATH

make -j$(nproc)
make install
```
> **关键参数说明**：
> - `-DCMAKE_TOOLCHAIN_FILE`：指定 HarmonyOS 工具链文件，这是交叉编译的关键[reference:1]。
> - `-DBUILD_SHARED_LIBS=ON`：生成动态库（.so），便于后续 TDLib 链接。
> - `-DCMAKE_INSTALL_PREFIX`：指定安装目录，避免污染系统目录。

### 2.3 执行编译
```bash
chmod +x build_ohos.sh
./build_ohos.sh
```
编译完成后，在 `install_ohos` 目录下会得到 `include/zlib.h`、`lib/libz.so` 等文件。

## 3. 编译 TDLib 并链接自定义 zlib
TDLib 的编译依赖包括 OpenSSL、zlib 等[reference:2]。在编译 TDLib 时，需要指向刚才编译的 zlib。

### 3.1 获取 TDLib 源码
```bash
git clone https://github.com/tdlib/td.git
cd td
mkdir build && cd build
```

### 3.2 配置 CMake
在 `td/build` 目录下执行以下命令（假设 zlib 安装在 `../zlib/install_ohos`）：
```bash
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/build/cmake/ohos.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DZLIB_LIBRARY=../zlib/install_ohos/lib/libz.so \
    -DZLIB_INCLUDE_DIR=../zlib/install_ohos/include \
    -DOPENSSL_ROOT_DIR=/path/to/openssl_for_harmonyos \  # 如需自行编译 OpenSSL
    -DCMAKE_PREFIX_PATH=../zlib/install_ohos
```
> **说明**：
> - `-DZLIB_LIBRARY` 和 `-DZLIB_INCLUDE_DIR` 直接指定刚才编译的 zlib 库和头文件路径。
> - 如果 OpenSSL 也需要交叉编译，请提前完成并指定 `OPENSSL_ROOT_DIR`。
> - `-DCMAKE_PREFIX_PATH` 可以让 CMake 在该路径下查找依赖的 CMake 包。

### 3.3 编译 TDLib
```bash
make -j$(nproc)
make install
```
编译成功后，会在 `install` 目录下得到 TDLib 的静态库/动态库及头文件。

## 4. 验证
- **检查链接**：使用 `readelf -d libtdclient.so`（或 `objdump -p`）查看动态库依赖，确认 `libz.so` 的路径是否正确。
- **简单测试**：编写一个简单的测试程序，调用 `td::ClientManager` 等接口，验证库能否正常加载。

## 5. 注意事项
- **工具链版本**：HarmonyOS NDK 的版本应与目标设备系统版本匹配，避免 ABI 不兼容。
- **架构匹配**：在 `ohos.toolchain.cmake` 中可通过 `-DOHOS_ARCH=arm64-v8a` 等参数指定目标架构，需与 zlib 编译时保持一致。
- **静态链接**：若希望静态链接 zlib，可在编译 zlib 时设置 `-DBUILD_SHARED_LIBS=OFF`，并在编译 TDLib 时指定 `-DZLIB_LIBRARY=../zlib/install_ohos/lib/libz.a`。
- **其他依赖**：TDLib 还依赖 OpenSSL、gperf 等，这些库也需要用相同的 HarmonyOS 工具链提前编译。

## 总结
整个过程分为两个核心步骤：
1.  **使用 HarmonyOS 工具链编译 zlib**：通过 `ohos.toolchain.cmake` 配置交叉编译，生成动态库。
2.  **编译 TDLib 时指定自定义 zlib**：通过 CMake 参数 `-DZLIB_LIBRARY` 和 `-DZLIB_INCLUDE_DIR` 指向第一步的编译结果。

这样即可在 HarmonyOS 平台上为 TDLib 提供专用的 zlib 库，满足其压缩功能依赖。如果在编译过程中遇到工具链或依赖问题，建议查阅 HarmonyOS NDK 官方文档或社区移植案例。

二.openssl for HarmonyOS

在 HarmonyOS 上为 TDLib 编译 OpenSSL，本质上是为鸿蒙的 **Native 环境**准备 OpenSSL 库。由于官方 OpenSSL 未直接提供鸿蒙支持，因此需要**交叉编译**。下面将详细介绍两种主流方法（自动化工具 vs 手动配置），并说明如何将编译好的库集成到 TDLib。

---

## 🔧 第一步：准备 HarmonyOS SDK 与工具链
无论采用哪种编译方式，都需要先准备好 HarmonyOS Native SDK（即 NDK）。

| 步骤 | 说明 |
|------|------|
| 1. 下载 SDK | 从 [HarmonyOS Native SDK 下载页面](https://developer.harmonyos.com/cn/develop/deveco-studio#native) 获取对应平台的 **ohos-sdk**。建议下载完整版，确保包含 `sysroot`。 |
| 2. 解压并设置环境变量 | 解压后，将 `ohos-sdk/native/llvm/bin` 加入 `PATH`，并设置 `OHOS_NATIVE_HOME`：<br>`export OHOS_NATIVE_HOME=/path/to/ohos-sdk/darwin/native`<br>`export PATH=$OHOS_NATIVE_HOME/llvm/bin:$PATH` |
| 3. 验证工具链 | 执行 `clang --version`，确认输出中包含 `OHOS` 或 `harmonyos` 字样。 |

---

## 📦 第二步：编译 OpenSSL
### 方法一：使用 lycium 自动化编译（推荐）
lycium 是 HarmonyOS 官方提供的**开源 C 库自动化编译框架**，适合快速得到可用的库。

1.  **获取 lycium 仓库**
    ```bash
    git clone https://gitee.com/openharmony-sig/tpc_c_cplusplus.git
    cd tpc_c_cplusplus/lycium
    ```

2.  **执行编译**
    ```bash
    ./build.sh openssl
    ```
    脚本会自动下载 openssl 源码、配置交叉编译参数并编译。编译过程中若遇到网络问题，可手动下载源码包放入 `thirdparty/openssl` 目录[reference:0]。

3.  **获取编译结果**
    编译完成后，库文件与头文件会生成在 `lycium/usr` 目录下，按架构（armeabi-v7a、arm64-v8a、x86_64）组织[reference:1]。

### 方法二：手动配置编译（更灵活）
手动编译可以更精细地控制配置参数，适合需要定制化的情况。

1.  **下载 OpenSSL 源码**
    ```bash
    wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz
    tar -zxvf openssl-1.1.1w.tar.gz
    cd openssl-1.1.1w
    ```

2.  **编写配置脚本**  
    创建 `build_config.sh`，根据架构设置编译参数（以 arm64-v8a 为例）[reference:2][reference:3]：
    ```bash
    # build_config.sh
    export OHOS_NATIVE_HOME=/path/to/ohos-sdk/darwin/native
    export PATH=$OHOS_NATIVE_HOME/llvm/bin:$PATH

    # 架构参数（可传入 arm64-v8a、armeabi-v7a、x86_64）
    THE_ARCH=${1:-arm64}
    case "$THE_ARCH" in
      armv7a|armeabi-v7a)
        OHOS_ARCH="armeabi-v7a"
        OHOS_TARGET="arm-linux-ohos"
        OPENSSL_ARCH="linux-armv4"
        ;;
      arm64|arm64-v8a)
        OHOS_ARCH="arm64"
        OHOS_TARGET="aarch64-linux-ohos"
        OPENSSL_ARCH="linux-aarch64"
        ;;
      x86_64)
        OHOS_ARCH="x86_64"
        OHOS_TARGET="x86_64-linux-ohos"
        OPENSSL_ARCH="linux-x86_64"
        ;;
    esac

    # 工具链
    export CC=$OHOS_NATIVE_HOME/llvm/bin/clang
    export CXX=$OHOS_NATIVE_HOME/llvm/bin/clang++
    export AR=$OHOS_NATIVE_HOME/llvm/bin/llvm-ar
    export LD=$OHOS_NATIVE_HOME/llvm/bin/ld-lld
    export RANLIB=$OHOS_NATIVE_HOME/llvm/bin/llvm-ranlib
    export STRIP=$OHOS_NATIVE_HOME/llvm/bin/llvm-strip

    # 编译标志
    export CFLAGS="--target=$OHOS_TARGET --sysroot=$OHOS_NATIVE_HOME/sysroot -fPIC"
    export LDFLAGS="--rtlib=compiler-rt -fuse-ld=lld"
    ```

3.  **编写编译脚本**  
    创建 `build_openssl.sh`：
    ```bash
    #!/bin/bash
    source build_config.sh $1

    PREFIX=$(pwd)/libs/openssl/$OHOS_ARCH
    ./Configure $OPENSSL_ARCH \
        --prefix=$PREFIX \
        no-engine \
        no-asm \
        no-threads \
        shared

    make clean
    make -j$(nproc)
    make install
    ```

4.  **执行编译**
    ```bash
    # 编译 arm64-v8a
    bash build_openssl.sh arm64-v8a

    # 编译 armeabi-v7a
    bash build_openssl.sh armeabi-v7a
    ```

5.  **注意事项**
    - **libatomic 依赖**：armv7 架构下 OpenSSL 默认依赖 `libatomic`，但鸿蒙 SDK 未提供。解决方法：在配置中加上 `no-threads` 禁用多线程，或自行编译 libatomic[reference:4][reference:5]。
    - **软链接问题**：默认编译出的 `.so` 文件带版本号软链接，如需简化可在配置中修改。

---

## 🧩 第三步：将编译好的 OpenSSL 集成到 TDLib
TDLib 通常使用 CMake 构建，集成 OpenSSL 主要涉及**头文件路径**与**库文件路径**的设置。

### 1. 组织库文件
将编译好的 OpenSSL 库文件与头文件按以下结构放置：
```
tdlib/
  thirdparty/
    openssl/
      arm64-v8a/
        include/   （头文件）
        lib/       （libssl.so, libcrypto.so 或 .a 静态库）
      armeabi-v7a/
        include/
        lib/
```

### 2. 修改 CMakeLists.txt
在 TDLib 的 CMakeLists.txt 中（或通过 `-D` 参数）指定 OpenSSL 路径：
```cmake
# 根据目标架构设置路径
set(OHOS_ARCH "arm64-v8a")  # 或 armeabi-v7a
set(OPENSSL_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/openssl/${OHOS_ARCH})

# 头文件
include_directories(${OPENSSL_ROOT_DIR}/include)

# 库文件
link_directories(${OPENSSL_ROOT_DIR}/lib)

# 链接目标
target_link_libraries(your_target
    PRIVATE ssl crypto
)
```
如果使用静态库，可直接指定库文件路径：
```cmake
target_link_libraries(your_target
    PRIVATE
    ${OPENSSL_ROOT_DIR}/lib/libssl.a
    ${OPENSSL_ROOT_DIR}/lib/libcrypto.a
)
```

### 3. 编译 TDLib
在配置 TDLib 时，通过 CMake 参数传递 OpenSSL 路径：
```bash
cd tdlib
mkdir build && cd build
cmake .. \
  -DOPENSSL_ROOT_DIR=../thirdparty/openssl/arm64-v8a \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/ohos-sdk/native/build/cmake/ohos.toolchain.cmake
make
```

---

## 📝 总结
| 步骤 | 关键点 |
|------|--------|
| 1. 准备 SDK | 下载完整的 HarmonyOS Native SDK，设置 `OHOS_NATIVE_HOME` 与 `PATH`。 |
| 2. 编译 OpenSSL | **自动化**：使用 lycium，执行 `./build.sh openssl`。<br>**手动**：编写 `build_config.sh` 与 `build_openssl.sh`，针对不同架构配置并编译。 |
| 3. 集成到 TDLib | 将编译好的库与头文件放入 `thirdparty/openssl/架构/`，在 CMakeLists.txt 中正确设置 `include_directories` 与 `link_libraries`。 |
| 4. 编译 TDLib | 使用 `ohos.toolchain.cmake` 工具链，指定 `OPENSSL_ROOT_DIR` 进行交叉编译。 |

> 以上方法均已在鸿蒙开发者社区或开源项目中得到验证[reference:6][reference:7][reference:8]。根据实际项目需求选择自动化或手动方式，并注意架构兼容性与依赖库问题。

三.sqlite for HarmonyOS

在 HarmonyOS（鸿蒙）上为 TDLib 编译 SQLite，主要有两种主流方案：**使用 lycium 自动化编译**或**手动使用 HarmonyOS NDK 编译**。下表对比了两种方案的特点，便于你根据自身情况选择：

| 方案 | 优点 | 缺点 | 适用场景 |
| :--- | :--- | :--- | :--- |
| **lycium 自动化编译** | 一键完成，无需深入配置 | 需熟悉 HPKBUILD 脚本修改 | 需要快速获得标准 SQLite 库 |
| **手动使用 HarmonyOS NDK 编译** | 可完全控制编译选项 | 步骤较多，需手动配置交叉编译 | 需要自定义 SQLite 功能（如 FTS5、JSON1 等） |

## 🔧 方案一：使用 lycium 自动化编译 SQLite
lycium 是 HarmonyOS 官方推荐的 C/C++ 三方库交叉编译框架，其编译流程已高度自动化。

### 1. 环境准备
- **安装 HarmonyOS NDK**（即 Native SDK），并设置 `OHOS_SDK` 环境变量。
- **获取 lycium 工具**：从 [tpc_c_cplusplus 仓库](https://gitee.com/openharmony-sig/tpc_c_cplusplus) 克隆或下载 zip 包，进入 `lycium` 目录。
- **配置编译工具链**（以 Mac 为例）：
  ```bash
  cd lycium/Buildtools
  tar -zxvf toolchain.tar.gz
  cp toolchain/* ${OHOS_SDK}/native/llvm/bin
  ```

### 2. 编译 SQLite
lycium 默认提供了 SQLite 的 HPKBUILD 脚本，直接运行即可编译：
```bash
./build.sh sqlite
```
编译完成后，库文件会生成在 `lycium/usr/${OHOS_ARCH}/lib` 目录下，头文件在 `lycium/usr/${OHOS_ARCH}/include`。

### 3. 自定义编译选项（如需）
若需要启用 SQLite 的特定功能（如 `SQLITE_ENABLE_COLUMN_METADATA`），需修改 HPKBUILD 脚本：
1. 打开 `lycium/thirdparty/sqlite/HPKBUILD`。
2. 在 `build()` 函数中添加对应的编译选项，例如：
   ```bash
   CFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA=1" make
   ```
3. 重新执行 `./build.sh sqlite`。

> **注意**：直接修改 `sqlite3.c` 源码可能被 lycium 的解压步骤覆盖，因此推荐通过 HPKBUILD 脚本传递宏定义[reference:0]。

## 🛠️ 方案二：手动使用 HarmonyOS NDK 编译 SQLite
若 lycium 无法满足定制需求，可手动使用 HarmonyOS NDK 进行交叉编译。

### 1. 下载 SQLite 源码
从 [SQLite 官网](https://www.sqlite.org/download.html) 下载最新稳定版源码包（例如 `sqlite-autoconf-*.tar.gz`）。

### 2. 配置交叉编译环境
解压源码后，进入目录，设置 NDK 工具链路径（以 arm64-v8a 为例）：
```bash
export OHOS_SDK=/path/to/harmonyos/ndk
export CC="${OHOS_SDK}/native/llvm/bin/clang"
export CFLAGS="--target=aarch64-linux-ohos --sysroot=${OHOS_SDK}/native/sysroot"
export LDFLAGS="--target=aarch64-linux-ohos --sysroot=${OHOS_SDK}/native/sysroot"
```

### 3. 编译与安装
运行配置脚本并编译：
```bash
./configure --host=aarch64-linux-ohos --prefix=/path/to/install
make
make install
```
编译完成后，在 `/path/to/install` 目录下会得到 `libsqlite3.so` 和头文件。

### 4. 验证库文件
使用 `file` 命令确认库文件架构是否正确：
```bash
file libsqlite3.so
# 应显示：ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, ...
```

## 📦 将编译好的 SQLite 集成到 TDLib
TDLib 默认通过 CMake 查找 SQLite。您需要将编译好的 SQLite 库和头文件放入 TDLib 的编译环境中。

### 1. 放置库文件与头文件
在 TDLib 项目目录下创建 `thirdparty/sqlite` 文件夹，并按架构组织文件：
```
tdlib/
  thirdparty/
    sqlite/
      arm64-v8a/
        include/   （存放 sqlite3.h、sqlite3ext.h）
        lib/       （存放 libsqlite3.so）
```

### 2. 修改 CMakeLists.txt
在 TDLib 的 CMakeLists.txt 中，添加以下语句以指定 SQLite 的路径：
```cmake
target_include_directories(tdlib PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/sqlite/${OHOS_ARCH}/include)
target_link_libraries(tdlib PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/sqlite/${OHOS_ARCH}/lib/libsqlite3.so)
```

### 3. 配置 DevEco Studio 项目（若使用）
如果是在 DevEco Studio 中编译 TDLib 作为原生模块，还需在 `build-profile.json5` 中添加外部 Native 依赖：
```json
"externalNativeOptions": {
  "cppFlags": "-I${projectDir}/thirdparty/sqlite/${OHOS_ARCH}/include",
  "linkFlags": "-L${projectDir}/thirdparty/sqlite/${OHOS_ARCH}/lib -lsqlite3"
}
```

## ⚠️ 常见问题与注意事项
| 问题 | 可能原因与解决方案 |
| :--- | :--- |
| **编译时提示“找不到 sqlite3.h”** | 头文件路径未正确设置，检查 `target_include_directories`。 |
| **运行时崩溃“undefined symbol”** | 编译的 SQLite 版本与 TDLib 所需版本不匹配，建议使用 TDLib 推荐的 SQLite 版本。 |
| **lycium 编译时网络超时** | HPKBUILD 中源码下载链接可能被墙，可手动下载源码包并放置到 `thirdparty/sqlite` 目录。 |
| **自定义宏定义未生效** | 在 lycium 的 HPKBUILD 中正确添加 `CFLAGS` 选项，并重新编译。 |
| **架构不匹配** | 确保编译的 SQLite 架构（arm64-v8a/armeabi-v7a）与目标设备一致。 |

## 📚 参考资源
- [lycium 官方仓库（OpenHarmony-SIG/tpc_c_cplusplus）](https://gitee.com/openharmony-sig/tpc_c_cplusplus)
- [HarmonyOS 开发实践——基于 lycium 的开源 C 库编译与集成](https://cloud.tencent.com/developer/article/2470239)[reference:1]
- [HarmonyOS 鸿蒙 Next 通过 lycium 编译 sqlite 库问题](http://bbs.itying.com/topic/678e453c4b218c005fa25dc2)[reference:2]
- [DevEco 如何使用本地已编译的 SQLite](http://bbs.itying.com/topic/68e714792cb460013cc1a0c6)[reference:3]
- [SQLite 官方下载页面](https://www.sqlite.org/download.html)

总之，推荐先尝试 **lycium 自动化编译**以快速获得可用的 SQLite 库。若需要深度定制，再采用**手动 NDK 编译**。成功编译 SQLite 后，只需将其库文件和头文件正确集成到 TDLib 的编译系统中即可。

四.icu for HarmonyOS

在 HarmonyOS（鸿蒙）上编译 TDLib 时，其依赖的 **ICU（International Components for Unicode）** 库需要单独进行交叉编译。以下是详细的步骤与关键问题解决方案。

---

## 🔧 一、准备工作：安装 HarmonyOS 交叉编译工具链
1.  **下载 HarmonyOS Native SDK**  
    从 [HarmonyOS 官方开发者网站](https://developer.harmonyos.com/cn/develop/deveco-studio) 下载 **Native SDK**（通常包含 `llvm`、`sysroot`、`cmake` 等）。
2.  **设置环境变量**  
    将工具链路径加入 `PATH`，并定义交叉编译相关的变量：
    ```bash
    export OHOS_SDK=/path/to/ohos-sdk
    export CC=$OHOS_SDK/native/llvm/bin/clang
    export CXX=$OHOS_SDK/native/llvm/bin/clang++
    export AR=$OHOS_SDK/native/llvm/bin/llvm-ar
    export LD=$OHOS_SDK/native/llvm/bin/ld.lld
    export RANLIB=$OHOS_SDK/native/llvm/bin/llvm-ranlib
    export SYSROOT=$OHOS_SDK/native/sysroot
    export CFLAGS="--target=aarch64-linux-ohos --sysroot=$SYSROOT"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="--target=aarch64-linux-ohos --sysroot=$SYSROOT"
    ```

---

## 📦 二、编译 ICU 库
### 2.1 下载 ICU 源代码
```bash
wget https://github.com/unicode-org/icu/releases/download/release-74-2/icu4c-74_2-src.tgz
tar xzf icu4c-74_2-src.tgz
cd icu/source
```

### 2.2 配置主机构建（避免架构不匹配）
ICU 的构建过程需要先在主机上生成一些工具，然后再用这些工具进行目标平台的交叉编译。**若环境变量设置不当，会导致主机工具也被编译成目标架构，从而出现“无法执行二进制文件”的错误**[reference:0]。

以下脚本会**保存并清空交叉编译环境变量**，确保主机工具使用本地编译器生成：
```bash
# 保存所有交叉编译相关的环境变量
SAVE_CC="$CC"
SAVE_CXX="$CXX"
SAVE_CFLAGS="$CFLAGS"
SAVE_CXXFLAGS="$CXXFLAGS"
SAVE_LDFLAGS="$LDFLAGS"
SAVE_AR="$AR"
SAVE_LD="$LD"
SAVE_RANLIB="$RANLIB"
SAVE_SYSROOT="$SYSROOT"

# 清空这些变量，让 configure 使用主机编译器
unset CC CXX CFLAGS CXXFLAGS LDFLAGS AR LD RANLIB SYSROOT

# 配置主机版本（仅用于生成工具）
./configure --enable-static --disable-shared --disable-samples --disable-tests

# 编译主机工具
make -j$(nproc)

# 恢复交叉编译环境变量
export CC="$SAVE_CC"
export CXX="$SAVE_CXX"
export CFLAGS="$SAVE_CFLAGS"
export CXXFLAGS="$SAVE_CXXFLAGS"
export LDFLAGS="$SAVE_LDFLAGS"
export AR="$SAVE_AR"
export LD="$SAVE_LD"
export RANLIB="$SAVE_RANLIB"
export SYSROOT="$SAVE_SYSROOT"
```

### 2.3 交叉编译 ICU 库（目标平台：HarmonyOS aarch64）
```bash
# 清理之前的主机构建产物（保留工具）
make clean

# 配置目标平台
./configure \
    --host=aarch64-linux-ohos \
    --prefix=$PWD/../../icu-harmonyos-install \
    --enable-static \
    --disable-shared \
    --disable-samples \
    --disable-tests \
    --with-cross-build=$PWD/../host_build  # 指向主机工具所在目录

# 编译并安装
make -j$(nproc)
make install
```
编译完成后，ICU 库会被安装到 `icu-harmonyos-install` 目录，其中包含 `include`、`lib` 等子目录。

---

## 🚀 三、在 TDLib 中使用编译好的 ICU
### 3.1 下载 TDLib 源代码
```bash
git clone https://github.com/tdlib/td.git
cd td
mkdir build && cd build
```

### 3.2 配置 CMake，指定 ICU 路径
TDLib 的 CMake 脚本会通过 `find_package(ICU)` 查找 ICU 库。你可以通过设置 `ICU_ROOT` 变量来指向自定义的安装路径[reference:1]：
```bash
cmake \
    -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/build/cmake/ohos.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DICU_ROOT=/path/to/icu-harmonyos-install \
    ..
```
> **提示**：如果 CMake 仍找不到 ICU，可以手动指定包含目录和库目录：
> ```bash
> -DICU_INCLUDE_DIR=/path/to/icu-harmonyos-install/include \
> -DICU_LIBRARY=/path/to/icu-harmonyos-install/lib/libicuuc.a
> ```

### 3.3 编译 TDLib
```bash
make -j$(nproc)
```
编译成功后，你会在 `build` 目录下得到 TDLib 的静态库（如 `libtdclient.a`、`libtdcore.a` 等）。

---

## 💎 四、关键问题与解决方案
| 问题 | 原因 | 解决方法 |
|------|------|----------|
| **“无法执行二进制文件”**（主机工具无法运行） | 环境变量（`AR`、`LD`、`RANLIB`、`SYSROOT`）仍指向交叉编译工具链，导致主机工具被编译成目标架构[reference:2]。 | 在主机构建前**清空**所有交叉编译相关的环境变量（见 2.2 节）。 |
| **CMake 找不到 ICU** | ICU 未安装在标准路径，CMake 的 `FindICU` 模块无法定位。 | 设置 `-DICU_ROOT=/path/to/icu-harmonyos-install` 或手动指定 `ICU_INCLUDE_DIR` 和 `ICU_LIBRARY`。 |
| **链接时缺少 ICU 符号** | 未链接所有必要的 ICU 组件（如 `i18n`、`data`、`uc`）。 | 在 CMake 中显式要求组件：`find_package(ICU COMPONENTS i18n data uc REQUIRED)`[reference:3]。 |

---

## 📚 五、参考资料
1.  **鸿蒙PC命令行适配ICU 主机构建架构不匹配问题解决** – 详细介绍了 ICU 在 HarmonyOS 交叉编译中的环境变量问题与修复方案[reference:4]。
2.  **鸿蒙OpenHarmony〖ICU4C〗标准库ArkTS API** – 说明 ICU4C 在 HarmonyOS 中的基本用法与头文件引入方式[reference:5]。
3.  **摆脱链接困境：CMake 中 FindICU 库的故障排除与最佳替代方案** – 讲解如何在 CMake 中正确配置 ICU 库路径[reference:6]。
4.  **第三方库交叉编译** – 提供通用的交叉编译方法与 `pkg-config` 环境变量设置技巧[reference:7]。

---

## 🎯 总结
在 HarmonyOS 上编译 TDLib 需要先交叉编译 ICU 库。关键步骤包括：
1.  安装 HarmonyOS Native SDK 并设置交叉编译环境。
2.  下载 ICU 源码，**在主机构建前清空交叉编译环境变量**，避免工具链架构不匹配。
3.  配置 ICU 的交叉编译，并安装到自定义目录。
4.  在 TDLib 的 CMake 配置中通过 `-DICU_ROOT` 指定 ICU 路径，确保 CMake 能够找到库文件。

按照上述步骤操作，即可顺利在 HarmonyOS 平台上完成 TDLib 的编译。如果在实际操作中遇到其他问题，建议查阅 [TDLib 官方 GitHub](https://github.com/tdlib/td) 或 [HarmonyOS 原生开发文档](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/build-overview-0000001263160405)。

五.libiconv for HarmonyOS

在 TDLib 中为 HarmonyOS（OpenHarmony）编译 libiconv，主要分为**配置交叉编译环境**、**编译 libiconv** 与**集成到 TDLib** 三个步骤。以下是基于 OpenHarmony NDK 工具链的详细操作流程。

---

## 🔧 1. 环境准备
### 1.1 安装 OpenHarmony NDK
- 从 [OpenHarmony SDK](https://gitee.com/openharmony/docs/blob/master/zh-cn/release-notes/OpenHarmony-v5.0.3-release.md#%E5%BC%80%E5%8F%91%E8%80%85%E5%B7%A5%E5%85%B7) 下载并解压 **Linux 平台的 Native SDK**，其中包含 `llvm`、`sysroot`、`cmake` 等工具。
- 假设 SDK 解压路径为 `/root/ohos-sdk/linux`，后续环境变量将基于此设置。

### 1.2 准备编译主机
- 推荐使用 **Linux 主机**（Ubuntu 20.04+ 或 CentOS 8+）。
- 确保已安装 `git`、`make`、`automake`、`libtool`、`pkg-config` 等基础构建工具。

---

## 📦 2. 获取 libiconv 源码
```bash
# 下载最新稳定版（这里以 1.18 为例）
wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz
tar -xzf libiconv-1.18.tar.gz
cd libiconv-1.18
```

---

## ⚙️ 3. 配置交叉编译环境
创建环境配置脚本 `exports.sh`，内容参考以下（关键变量已标注说明）[reference:0]：

```bash
#!/bin/bash
echo "加载 OpenHarmony 交叉编译环境配置"

# 你的 SDK 路径，请根据实际情况修改
SDK_PATH="/root/ohos-sdk/linux"
echo "SDK_PATH: $SDK_PATH"

export OHOS_SDK="$SDK_PATH"
export HNP_PERFIX= # 根据实际情况设置 HNP 前缀路径
export COMPILER_TOOLCHAIN="${OHOS_SDK}/native/llvm/bin/"

# 设置编译工具链变量
export CC="${COMPILER_TOOLCHAIN}clang" && echo "CC : ${CC}"
export CXX="${COMPILER_TOOLCHAIN}clang++" && echo "CXX : ${CXX}"
export HOSTCC="${CC}" && echo "HOSTCC : ${HOSTCC}"
export HOSTCXX="${CXX}" && echo "HOSTCXX : ${HOSTCXX}"
export CPP="${CXX} -E" && echo "CPP : ${CPP}"
export AS="${COMPILER_TOOLCHAIN}llvm-as" && echo "AS : ${AS}"
export LD="${COMPILER_TOOLCHAIN}ld.lld" && echo "LD : ${LD}"
export STRIP="${COMPILER_TOOLCHAIN}llvm-strip" && echo "STRIP : ${STRIP}"
export RANLIB="${COMPILER_TOOLCHAIN}llvm-ranlib" && echo "RANLIB : ${RANLIB}"
export OBJDUMP="${COMPILER_TOOLCHAIN}llvm-objdump" && echo "OBJDUMP : ${OBJDUMP}"
export OBJCOPY="${COMPILER_TOOLCHAIN}llvm-objcopy" && echo "OBJCOPY : ${OBJCOPY}"
export NM="${COMPILER_TOOLCHAIN}llvm-nm" && echo "NM : ${NM}"
export AR="${COMPILER_TOOLCHAIN}llvm-ar" && echo "AR : ${AR}"

# 设置系统根目录和包配置
export SYSROOT="${OHOS_SDK}/native/sysroot"
export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}/usr/lib/aarch64-linux-ohos"
export PKG_CONFIG_PATH="${PKG_CONFIG_SYSROOT_DIR}"
export PKG_CONFIG_EXECUTABLE="${PKG_CONFIG_SYSROOT_DIR}" # 注意：通常指向 pkg‑config 可执行文件路径

# 设置构建工具路径
export HNP_TOOL="${OHOS_SDK}/toolchains/hnpcli"
export CMAKE="${OHOS_SDK}/native/build-tools/cmake/bin/cmake"
export TOOLCHAIN_FILE="${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake"

# 设置工作路径和输出目录
export WORK_ROOT="${PWD}"
export ARCHIVE_PATH="${WORK_ROOT}/output"
export COMM_DEP_PATH="${WORK_ROOT}/deps_install"
mkdir -p "${ARCHIVE_PATH}"

# 设置 HNP 公共路径和构建静默参数
export HNP_PUBLIC_PATH="${HNP_PERFIX}/data/service/hnp/"
mkdir -p "${HNP_PUBLIC_PATH}"
chmod 777 -R "${HNP_PUBLIC_PATH}" # 谨慎使用，确保安全
export MAKE_QUITE_PARAM="-s"
export CONFIGURE_QUITE_PARAM="--quiet"

# 设置目标平台
export TARGET_PLATFORM="aarch64-linux-ohos"
export TARGET="aarch64-linux-ohos"

# 设置编译和链接标志（关键：必须包含 --target 参数）
export CFLAGS="-fPIC -D__MUSL__=1 -D__OHOS__ -fstack-protector-strong --target=${TARGET_PLATFORM} --ld-path=${LD} --sysroot=${SYSROOT} -stdlib=libc++"
export CXXFLAGS="${CFLAGS}"
export LD_LIBRARY_PATH="${SYSROOT}/usr/lib:${LD_LIBRARY_PATH}"
export LDFLAGS="--ld-path=${LD} --target=${TARGET_PLATFORM} --sysroot=${SYSROOT} -fuse-ld=lld"
export HOST_TYPE="--host=aarch64-linux --build=aarch64-linux" # 用于 configure 脚本

echo "环境配置完成。LDFLAGS: ${LDFLAGS}"
```

运行脚本以加载环境：
```bash
source exports.sh
```

---

## 🛠 4. 编译 libiconv
### 4.1 配置
```bash
# 进入 libiconv 源码目录
cd libiconv-1.18

# 加载环境（若尚未加载）
source ../exports.sh

# 运行 configure，指定 host 为目标平台
./configure --host=aarch64-linux-ohos --prefix=${COMM_DEP_PATH} --enable-static=yes --enable-shared=no
```
> 说明：`--enable-static=yes --enable-shared=no` 通常适用于 TDLib 的依赖库，如需动态库可改为 `--enable-shared=yes`。

### 4.2 解决链接问题
若出现 `libtool` 丢失 `--target` 参数导致链接到 glibc 的错误，需确保 `CFLAGS` 和 `LDFLAGS` 中已正确包含 `--target=aarch64-linux-ohos`[reference:1]。检查编译命令中是否包含该参数，若缺失，可手动修改 `libtool` 脚本或直接传递 `CC` 和 `LD` 环境变量。

### 4.3 执行编译
```bash
make -j$(nproc)
```

### 4.4 安装到指定目录
```bash
make install
```
安装后，库文件将位于 `${COMM_DEP_PATH}/lib`，头文件位于 `${COMM_DEP_PATH}/include`。

---

## 📚 5. 在 TDLib 中使用编译好的 libiconv
### 5.1 获取 TDLib 源码
```bash
git clone https://github.com/tdlib/td.git
cd td
```

### 5.2 配置 CMake 使用 HarmonyOS 工具链
创建 CMake 工具链文件 `ohos.toolchain.cmake`（若已存在可直接使用 SDK 提供的）。关键是指定编译器和 sysroot：
```cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER ${OHOS_SDK}/native/llvm/bin/clang)
set(CMAKE_CXX_COMPILER ${OHOS_SDK}/native/llvm/bin/clang++)

set(CMAKE_SYSROOT ${OHOS_SDK}/native/sysroot)
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# 指定 libiconv 的安装路径
set(ICONV_ROOT ${COMM_DEP_PATH})
set(ICONV_INCLUDE_DIR ${ICONV_ROOT}/include)
set(ICONV_LIBRARY ${ICONV_ROOT}/lib/libiconv.a)
```

### 5.3 编译 TDLib
```bash
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/ohos.toolchain.cmake \
  -DICONV_INCLUDE_DIR=${ICONV_INCLUDE_DIR} \
  -DICONV_LIBRARY=${ICONV_LIBRARY} \
  -DCMAKE_BUILD_TYPE=Release

make -j$(nproc)
```
> 若 TDLib 的 CMakeLists.txt 已自动检测 iconv，则可能无需手动指定 `ICONV_INCLUDE_DIR` 和 `ICONV_LIBRARY`。

---

## 💡 6. 注意事项
- **musl libc 兼容性**：HarmonyOS 使用 musl libc，其 iconv 实现可能较 glibc 功能少。若遇到 `iconv_open` 返回 -1，可尝试将字符集名称改为 `USC_2LE` 等 musl 支持的格式[reference:2]。
- **静态库与动态库**：TDLib 默认可能链接动态库，若希望静态链接，可在 CMake 中设置 `-DBUILD_SHARED_LIBS=OFF`。
- **调试符号**：若需调试，可在 `CFLAGS` 中添加 `-g`，但发布版本建议去掉以减小体积。

---

## 🧪 7. 常见问题
**Q1：编译 libiconv 时提示 “undefined reference to `__libc_*`”**
A：这是因为链接器仍尝试链接 glibc。请确保 `CFLAGS` 和 `LDFLAGS` 中已正确设置 `--target=aarch64-linux-ohos` 和 `--sysroot=${SYSROOT}`，并已定义 `-D__MUSL__=1`。

**Q2：TDLib 找不到 iconv 函数**
A：请检查 `ICONV_LIBRARY` 路径是否正确，并确保在 CMake 中已添加 `target_link_libraries(td PUBLIC ${ICONV_LIBRARY})`。

**Q3：如何验证编译出的库是否正确？**
A：使用 `file` 命令检查库文件格式：
```bash
file ${COMM_DEP_PATH}/lib/libiconv.a
```
输出应显示 “ELF 64-bit LSB relocatable, ARM aarch64, version 1 (SYSV)” 等类似信息。

---

遵循以上步骤，你应能成功为 HarmonyOS 编译 libiconv，并将其用于 TDLib 的构建。如果在具体操作中遇到问题，欢迎提供更多细节以便进一步排查。

六.protocol buffers for HarmonyOS

在 TDLib 中为 HarmonyOS 编译 Protocol Buffers 涉及两个层面的工作：**首先需要为 HarmonyOS 交叉编译 Protobuf 库本身**，**然后才能让 TDLib 在 HarmonyOS 环境中正常使用 Protobuf**。由于 TDLib 官方并未直接提供 HarmonyOS 的构建脚本，因此需要手动配置交叉编译工具链。

以下是详细步骤及关键配置。

---

## 1. 环境准备

### 1.1 安装 HarmonyOS Native SDK
- 从 [HarmonyOS 开发者网站](https://developer.harmonyos.com/cn/develop/deveco-studio) 下载 **Command Line Tools For HarmonyOS NEXT**（Linux/macOS/Windows）。
- 解压后，设置环境变量（以 Linux/macOS 为例）：
  ```bash
  export OHOS_SDK=/path/to/ohos-sdk/linux  # 根据实际路径调整
  export PATH=$OHOS_SDK/native/llvm/bin:$PATH
  ```

### 1.2 安装构建工具
- **CMake**：建议使用 DevEco Studio 自带的 CMake（通常位于 `{OHOS_SDK}/native/build-tools/cmake/bin/cmake`），或安装 3.16 以上版本。
- **Ninja**（推荐）：SDK 中已包含，也可自行安装。
- 其他基础工具：`make`、`tar`、`gzip` 等。

---

## 2. 为 HarmonyOS 编译 Protocol Buffers 库

TDLib 的 C++ 接口依赖 Protobuf 进行数据序列化。你需要先为 HarmonyOS 交叉编译 Protobuf（这里以 3.25.2 为例）。

### 2.1 获取源码
```bash
git clone https://github.com/protocolbuffers/protobuf.git
cd protobuf
git checkout v3.25.2
```

### 2.2 配置交叉编译环境
HarmonyOS 使用 **clang** 作为编译器，目标架构一般为 `aarch64`。创建一个编译脚本 `build_ohos.sh`，内容如下（关键配置参考自 HarmonyOS 适配指南）[reference:0]：

```bash
#!/bin/bash

# 设置 HarmonyOS SDK 路径
OHOS_SDK="/path/to/ohos-sdk/linux"

# 设置安装路径（遵循 HNP 规范）
export PROTOBUF_INSTALL_HNP_PATH=${HNP_PUBLIC_PATH}/protobuf.org/protobuf_3.25.2

# 工具链变量
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=arm-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=arm-linux-ohos"
export LD="${OHOS_SDK}/native/llvm/bin/ld.lld"
export AR="${OHOS_SDK}/native/llvm/bin/llvm-ar"
export STRIP="${OHOS_SDK}/native/llvm/bin/llvm-strip"

# 编译 flags
export CFLAGS="-fPIC -D__MUSL__=1"
export CXXFLAGS="-fPIC -D__MUSL__=1"
export LDFLAGS=""

# CMake 检测（优先使用 SDK 自带的 CMake）
CMAKE_CMD="${OHOS_SDK}/native/build-tools/cmake/bin/cmake"

# 创建构建目录
mkdir -p build_ohos
cd build_ohos

# 配置 CMake
${CMAKE_CMD} .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=${PROTOBUF_INSTALL_HNP_PATH} \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER="${CC}" \
  -DCMAKE_CXX_COMPILER="${CXX}" \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
  -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_SYSROOT="${OHOS_SDK}/native/sysroot" \
  -Dprotobuf_BUILD_TESTS=OFF \
  -Dprotobuf_BUILD_EXAMPLES=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON

# 编译并安装
${CMAKE_CMD} --build . --config Release --parallel $(nproc)
${CMAKE_CMD} --install . --config Release
```

### 2.3 执行编译
```bash
chmod +x build_ohos.sh
./build_ohos.sh
```
编译完成后，Protobuf 的库和头文件会安装到 `PROTOBUF_INSTALL_HNP_PATH` 目录中。

---

## 3. 编译 TDLib（使用已编译的 Protobuf）

TDLib 的构建依赖 Protobuf，因此需要在 CMake 配置中指定刚才编译的 Protobuf 路径。

### 3.1 获取 TDLib 源码
```bash
git clone https://github.com/tdlib/td.git
cd td
```

### 3.2 配置 CMake 工具链
创建 `ohos.toolchain.cmake` 文件（或直接使用 SDK 提供的 `ohos.toolchain.cmake`）。以下是一个简化版本[reference:1]：

```cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER "${OHOS_SDK}/native/llvm/bin/clang")
set(CMAKE_CXX_COMPILER "${OHOS_SDK}/native/llvm/bin/clang++")
set(CMAKE_SYSROOT "${OHOS_SDK}/native/sysroot")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
```

### 3.3 创建构建脚本 `build_td_ohos.sh`
```bash
#!/bin/bash

OHOS_SDK="/path/to/ohos-sdk/linux"
PROTOBUF_ROOT="/path/to/install/protobuf_3.25.2"  # 上一步安装的 Protobuf 路径

mkdir -p build_ohos
cd build_ohos

${OHOS_SDK}/native/build-tools/cmake/bin/cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="../ohos.toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${PROTOBUF_ROOT}" \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DOPENSSL_ROOT_DIR="${OHOS_SDK}/native/usr/openssl" \
  -DZLIB_ROOT="${OHOS_SDK}/native/usr/zlib" \
  -DTD_ENABLE_JNI=OFF \
  -DTD_ENABLE_DOTNET=OFF

# 编译
${OHOS_SDK}/native/build-tools/cmake/bin/cmake --build . --config Release --parallel $(nproc)
```

### 3.4 执行编译
```bash
chmod +x build_td_ohos.sh
./build_td_ohos.sh
```
编译成功后，会在 `build_ohos` 目录下生成 TDLib 的静态库（如 `libtdjson_static.a`、`libtdclient.a` 等）。

---

## 4. 常见问题与解决方案

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| CMake 找不到 Protobuf | `CMAKE_PREFIX_PATH` 未正确设置 | 确保 `-DCMAKE_PREFIX_PATH` 指向 Protobuf 的安装目录。 |
| 链接时缺少 Protobuf 符号 | Protobuf 库未正确链接 | 在 CMake 中手动指定 Protobuf 库路径：`-DProtobuf_LIBRARIES=${PROTOBUF_ROOT}/lib/libprotobuf.a`。 |
| 编译器不支持 C++17 | HarmonyOS 工具链版本过低 | 检查 `clang++ --version`，确保支持 `-std=c++17`。 |
| 依赖库（OpenSSL、zlib）缺失 | SDK 中未包含或路径错误 | 使用 `-DOPENSSL_ROOT_DIR` 和 `-DZLIB_ROOT` 明确指定 SDK 中的路径。 |

---

## 5. 后续步骤

- **集成到 HarmonyOS 应用**：将编译得到的 TDLib 静态库及头文件添加到您的 HarmonyOS Native 项目中，并在 `CMakeLists.txt` 中链接 `libtdjson_static.a`、`libtdclient.a` 等库。
- **测试**：编写简单的测试程序，调用 `td_json_client_create` 等接口，验证库是否正常工作。
- **调试**：若遇到运行时错误，请检查系统库依赖、堆栈大小等环境配置。

---

## 参考资料

1. [Protocol Buffers (protobuf) HarmonyOS 适配指南](https://llllyyyy.blog.csdn.net/article/details/155000267) – 提供了 Protobuf 在 HarmonyOS 上的完整交叉编译配置。
2. [开源三方库 HarmonyOS NEXT 适配指导](https://my.oschina.net/u/9174168/blog/18444120) – 介绍了 HarmonyOS NEXT 的 CMake 工具链使用和第三方库编译方法。
3. [TDLib 官方构建说明](https://github.com/tdlib/td) – 列出了 TDLib 的依赖和基本构建命令[reference:2]。
4. [HarmonyOS 官方 NDK 文档](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/ndk-overview-000000130508) – 关于 Native 开发工具链的详细说明。

> 以上步骤基于 2025‑11‑18 的 Protobuf 适配指南和 TDLib 最新源码编写，实际操作时请根据您的 HarmonyOS SDK 版本和目标架构（arm64‑v8a/armeabi‑v7a）适当调整路径和编译选项。

七.re2 for HarmonyOS

在 HarmonyOS（OpenHarmony）上为 TDLib 编译 **re2**（Google 正则表达式库）需要**使用 HarmonyOS NDK 进行交叉编译**。以下是详细步骤，涵盖环境配置、编译、安装以及 TDLib 中的链接方法。

---

## 1. 准备工作
### 1.1 获取 HarmonyOS NDK（SDK）
- 从 [华为开发者联盟](https://developer.harmonyos.com/cn/develop/deveco-studio#download) 下载 **Command Line Tools For HarmonyOS NEXT**（或 OpenHarmony SDK）。
- 解压后，记下 SDK 根目录路径，例如：
  ```bash
  export OHOS_SDK=/home/yourname/OH_SDK/ohos-sdk/linux
  ```

### 1.2 获取 re2 源码
- 可以直接从 OpenHarmony 的第三方仓库克隆（已包含基本的 HarmonyOS 适配）：
  ```bash
  git clone https://gitee.com/openharmony-sync/third_party_re2.git
  cd third_party_re2
  ```
- 或从 Google 官方仓库下载（可能需要手动适配）：
  ```bash
  git clone https://github.com/google/re2.git
  cd re2
  ```

---

## 2. 配置交叉编译环境
re2 使用 **Makefile** 构建，因此需要通过环境变量指定 HarmonyOS NDK 提供的 Clang 工具链。

### 2.1 设置环境变量
根据 HarmonyOS 三方库适配指南[reference:0]，在终端中执行以下命令（以 **arm64-v8a** 为例）：

```bash
export OHOS_SDK=/home/yourname/OH_SDK/ohos-sdk/linux
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=arm-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=arm-linux-ohos"
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export CFLAGS="-fPIC -D__MUSL__=1"
export CXXFLAGS="-fPIC -D__MUSL__=1"
```

**参数说明**：
- `--target=arm-linux-ohos`：指定目标为 HarmonyOS 的 ARM 平台。如需其他架构（如 x86_64），可改为 `--target=x86_64-linux-ohos`。
- `-fPIC`：生成位置无关代码，便于后续链接为动态库。
- `-D__MUSL__=1`：HarmonyOS 使用 musl libc，需定义该宏。

### 2.2（可选）调整 Makefile
如果编译时出现标准库或编译器选项问题，可以修改 re2 根目录的 **Makefile**：
- 确保 `CXX` 变量被上述环境变量覆盖。
- 检查 `CXXFLAGS` 中是否包含 `-std=c++11`（或更高版本），HarmonyOS NDK 的 Clang 支持 C++11。

---

## 3. 编译 re2
在配置好环境变量的终端中，直接执行 `make`：

```bash
make
```

如果顺利，将生成 **静态库（libre2.a）** 和 **动态库（libre2.so）**（取决于 Makefile 规则）。

---

## 4. 安装库文件
### 4.1 安装到系统目录（可选）
```bash
make install DESTDIR=/path/to/your/harmonyos/sysroot
```
或手动将头文件（`re2/*.h`）和库文件（`libre2.a`/`libre2.so`）复制到你的 HarmonyOS 项目目录中。

### 4.2 验证编译结果
使用 `file` 命令检查生成的库文件是否正确指向 HarmonyOS 目标：
```bash
file libre2.so
```
输出应显示 **ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, for OpenHarmony** 类似信息。

---

## 5. 在 TDLib 中链接 re2
### 5.1 编译 TDLib 时指定 re2 路径
在编译 TDLib 时，需要通过 `CMake` 或 `Make` 参数指定 re2 的头文件和库路径：

```bash
cd td
mkdir build && cd build
cmake .. \
  -DRE2_INCLUDE_DIR=/path/to/re2/include \
  -DRE2_LIBRARY=/path/to/re2/lib/libre2.a \
  -DCMAKE_TOOLCHAIN_FILE=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static
make -j
```

### 5.2 直接修改 TDLib 的构建脚本
如果 TDLib 的 `CMakeLists.txt` 或 `Makefile` 中已经检测 re2，只需确保上述环境变量（`CC`、`CXX` 等）在编译 TDLib 时同样生效。

---

## 6. 常见问题与解决
| 问题 | 可能原因 | 解决 |
|------|----------|------|
| 编译时报 `undefined reference to `std::__throw_bad_alloc` | C++ 标准库链接问题 | 在 `CXXFLAGS` 中添加 `-D_GLIBCXX_USE_CXX11_ABI=0`，或确保 `-std=c++11` 一致 |
| 找不到 `#include <string>` 等头文件 | sysroot 路径未设置 | 在 `CFLAGS`/`CXXFLAGS` 中添加 `--sysroot=${OHOS_SDK}/native/sysroot` |
| 链接时提示 `musl` 相关符号缺失 | 未定义 `__MUSL__` | 在 `CFLAGS`/`CXXFLAGS` 中明确添加 `-D__MUSL__=1` |
| 编译通过但运行时崩溃 | 架构不匹配 | 检查 `--target` 是否与设备架构（arm64-v8a/armeabi-v7a/x86_64）一致 |

---

## 7. 参考资源
1. **OpenHarmony 三方库适配指导**（非 CMake 编译部分）：[reference:1]
2. **OpenHarmony 第三方 re2 仓库**：https://gitee.com/openharmony-sync/third_party_re2
3. **HarmonyOS NDK 官方文档**：https://docs.openharmony.cn/pages/v5.0/zh-cn/application-dev/ndk/ndk-overview/
4. **TDLib 官方编译指南**：https://github.com/tdlib/td#building

按照以上步骤，你应该能够成功为 HarmonyOS 编译 re2，并将其用于 TDLib 的构建。如果在具体操作中遇到问题，可以查阅 HarmonyOS NDK 的文档或社区论坛获取更多架构相关的编译选项。

八.libphonenumber for HarmonyOS

在 HarmonyOS（OpenHarmony）上为 **TDLib** 编译 **libphonenumber**，本质上是完成一次针对 HarmonyOS NDK 的 C++ 三方库交叉编译。下面将基于官方适配指导与社区实践，详细介绍完整步骤。

---

## 🔧 1. 环境准备
### 1.1 安装 HarmonyOS NDK（Native Development Kit）
- 从 [HarmonyOS SDK 下载页](https://developer.harmonyos.com/cn/develop/deveco-studio#download) 获取 **Command Line Tools For HarmonyOS NEXT**。
- 解压后，重点关注 `native` 目录，其中包含：
    - `build/cmake/ohos.toolchain.cmake` – 专为 HarmonyOS 预定义的 CMake 工具链文件。
    - `build‑tools/cmake/bin/cmake`、`ninja` – 构建工具。
    - `llvm/bin/clang++` – HarmonyOS 使用的 Clang 编译器。

### 1.2 配置环境变量
在 Linux（或 WSL）环境下，设置 SDK 路径及工具链：
```bash
export OHOS_SDK=/path/to/ohos-sdk/linux
export CC="$OHOS_SDK/native/llvm/bin/clang --target=arm-linux-ohos"
export CXX="$OHOS_SDK/native/llvm/bin/clang++ --target=arm-linux-ohos"
export CMAKE_TOOLCHAIN_FILE="$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake"
```
（以上环境变量设置方式参考了开源三方库适配指导中“非CMake编译”部分的配置[reference:0]。）

---

## 📦 2. 获取 libphonenumber 源码
```bash
git clone https://github.com/google/libphonenumber.git
cd libphonenumber/cpp  # 编译 C++ 版本
```
> 建议使用稳定版本（如 `v8.13.0`），避免主线分支可能存在的兼容性问题。

---

## ⚙️ 3. 配置 CMake 编译脚本
由于 libphonenumber 默认使用 CMake，我们可以直接利用 HarmonyOS NDK 提供的工具链文件。创建 `cmake_exec.sh` 脚本：

```bash
#!/bin/bash
OHOS_SDK_PATH="/path/to/ohos-sdk/linux"
BUILD_DIR="build_harmony"
INSTALL_DIR="install_harmony"

${OHOS_SDK_PATH}/native/build-tools/cmake/bin/cmake -GNinja \
    -DOHOS_STL=c++_static \
    -DOHOS_ARCH=arm64-v8a \
    -DOHOS_PLATFORM=OHOS \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_TOOLCHAIN_FILE="${OHOS_SDK_PATH}/native/build/cmake/ohos.toolchain.cmake" \
    -B ${BUILD_DIR}
```
**参数说明**（参考官方指导[reference:1]）：
- `OHOS_STL`：选择 C++ 库链接方式，静态链接（`c++_static`）更适合集成到 TDLib。
- `OHOS_ARCH`：目标架构，可根据需求改为 `armeabi-v7a`。
- `CMAKE_TOOLCHAIN_FILE`：指定 HarmonyOS 工具链文件。

---

## 🏗️ 4. 编译与安装
### 4.1 执行配置脚本
```bash
chmod +x cmake_exec.sh
./cmake_exec.sh
```

### 4.2 执行构建
创建 `ninja_exec.sh` 脚本：
```bash
#!/bin/bash
OHOS_SDK_PATH="/path/to/ohos-sdk/linux"
BUILD_DIR="build_harmony"

${OHOS_SDK_PATH}/native/build-tools/cmake/bin/ninja -C ${BUILD_DIR}
```
运行：
```bash
chmod +x ninja_exec.sh
./ninja_exec.sh
```

### 4.3 安装库文件
```bash
cd build_harmony
make install  # 或 ninja install
```
编译生成的静态库（`.a`）或动态库（`.so`）将位于 `install_harmony/lib` 目录，头文件在 `install_harmony/include`。

---

## 🔗 5. 在 TDLib 中集成
### 5.1 修改 TDLib 的 CMakeLists.txt
在 TDLib 的 CMake 配置中，添加 libphonenumber 的查找路径：
```cmake
# 设置 libphonenumber 的安装路径
set(LIBPHONENUMBER_INSTALL_DIR "/path/to/libphonenumber/cpp/install_harmony")

# 包含头文件
include_directories(${LIBPHONENUMBER_INSTALL_DIR}/include)

# 链接库
target_link_libraries(td PRIVATE ${LIBPHONENUMBER_INSTALL_DIR}/lib/libphonenumber.a)
```
若 libphonenumber 依赖其他库（如 protobuf），同样需要先为 HarmonyOS 编译并链接。

### 5.2 交叉编译 TDLib
参照上述同样的工具链配置，为 TDLib 编写类似的 CMake 脚本，确保其与 libphonenumber 使用相同的 STL 和架构。

---

## 💡 6. 常见问题与解决方法
| 问题 | 可能原因 | 解决方法 |
|------|----------|----------|
| 链接错误：未找到 C++ 标准库符号 | STL 链接方式不匹配 | 确保 libphonenumber 与 TDLib 都使用 `c++_static`（或都使用 `c++_shared`）。 |
| 头文件找不到 | 安装路径未正确设置 | 检查 `CMAKE_INSTALL_PREFIX` 是否指向正确的安装目录。 |
| 编译失败：未知的 target | 工具链未正确设置 | 确认 `CMAKE_TOOLCHAIN_FILE` 指向正确的 `ohos.toolchain.cmake`。 |
| 运行时崩溃：符号冲突 | 不同编译器版本导致 ABI 不兼容 | 统一使用 HarmonyOS NDK 中的 Clang 编译器，避免混用系统编译器。 |

---

## 📚 7. 替代方案：使用已适配的三方库仓库
OpenHarmony 社区维护了一个 **C/C++ 三方库适配仓库**（[OpenHarmony-SIG/tpc_c_cplusplus](https://gitee.com/openharmony-sig/tpc_c_cplusplus)）。你可以在此查找是否已有适配好的 libphonenumber 版本：
```bash
cd tpc_c_cplusplus/thirdparty
./build libphonenumber  # 若有对应脚本
```
这可以省去手动配置工具链的步骤。

---

## 🎯 总结
为 TDLib 编译 libphonenumber for HarmonyOS 的关键步骤包括：
1.  **准备 HarmonyOS NDK 工具链**，配置环境变量。
2.  **获取 libphonenumber 源码**，使用 `ohos.toolchain.cmake` 进行交叉编译。
3.  **编写 CMake 脚本**，指定正确的架构、STL 和工具链文件。
4.  **编译并安装**，得到静态库/动态库。
5.  **在 TDLib 中链接**，确保两者使用相同的编译选项。
6.  **测试集成**，解决可能出现的链接或运行时问题。

若遇到问题，可参考 [开源三方库HarmonyOS NEXT适配指导](https://my.oschina.net/u/9174168/blog/18444120) 中的详细示例，或查阅 [〖鸿蒙〗跨平台三方框架（一）-迁移三方库到鸿蒙](https://blog.csdn.net/weixin_60917883/article/details/142362364) 中的交叉编译流程。

> 以上步骤基于 2025‑2026 年的 HarmonyOS NEXT SDK 及开源三方库适配最佳实践，具体细节可能随版本更新而调整。

九.crc32c for HarmonyOS

在 TDLib 中为 HarmonyOS 编译 `crc32c` 库，核心是利用 HarmonyOS NDK 提供的 **跨编译工具链**，将 `crc32c`（通常是 Google 维护的 CRC32C 实现）编译为 HarmonyOS 可用的静态库或动态库，再将其集成到 TDLib 的构建系统中。下面是详细步骤与关键要点。

## 🔍 1. 理解需求
- **crc32c 在 TDLib 中的作用**：TDLib 可能使用 `crc32c` 进行数据完整性校验（如网络包、本地存储）。其源码可能直接包含在 TDLib 的 `third-party` 目录中，也可能依赖系统的 `libcrc32c`。
- **HarmonyOS 编译的特殊性**：HarmonyOS 使用 **Clang/LLVM** 工具链，且提供了专门的 `ohos.toolchain.cmake` 文件来定义交叉编译参数[reference:0]。因此，任何第三方 C/C++ 库都需要使用该工具链重新编译。

## 📦 2. 准备工作
### 2.1 安装 HarmonyOS NDK
- 下载 **Command Line Tools for HarmonyOS NEXT**（即 NDK），解压后得到 `native` 目录，其中包含 `build/cmake/ohos.toolchain.cmake`、编译工具链和头文件[reference:1]。
- 设置环境变量（以 Linux 为例）：
  ```bash
  export OHOS_SDK=/path/to/ohos-sdk/linux
  export PATH=$OHOS_SDK/native/build-tools/cmake/bin:$PATH
  ```

### 2.2 获取源码
- **crc32c 源码**：推荐使用 Google 维护的版本，该版本支持 CMake 构建，且性能较好[reference:2]。
  ```bash
  git clone https://github.com/google/crc32c.git
  cd crc32c
  ```
- **TDLib 源码**：从官方仓库克隆。
  ```bash
  git clone https://github.com/tdlib/td.git
  ```

## 🛠 3. 编译 crc32c 库
### 3.1 配置 CMake 工具链
在 `crc32c` 目录下创建 `build_ohos` 目录，并使用 `ohos.toolchain.cmake` 进行配置。关键参数包括：
- `-DCMAKE_TOOLCHAIN_FILE`：指定工具链文件路径。
- `-DOHOS_ARCH`：设置目标架构（如 `arm64-v8a`）。
- `-DOHOS_STL`：选择 C++ 库链接方式（如 `c++_static`）。
- `-DCMAKE_INSTALL_PREFIX`：指定安装路径，便于后续集成。

示例配置脚本 `cmake_exec.sh`（参考 HarmonyOS 三方库编译指南）[reference:3]：
```bash
#!/bin/bash
OHOS_SDK_PATH="/path/to/ohos-sdk/linux"
$OHOS_SDK_PATH/native/build-tools/cmake/bin/cmake -GNinja \
  -DOHOS_STL=c++_static \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_PLATFORM=OHOS \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DCMAKE_TOOLCHAIN_FILE="$OHOS_SDK_PATH/native/build/cmake/ohos.toolchain.cmake" \
  -B build_ohos
```

### 3.2 执行编译
```bash
# 生成构建文件
./cmake_exec.sh
# 执行编译（使用 ninja 或 make）
$OHOS_SDK_PATH/native/build-tools/cmake/bin/ninja -C build_ohos
# 安装到指定目录
$OHOS_SDK_PATH/native/build-tools/cmake/bin/ninja -C build_ohos install
```
编译完成后，在 `install` 目录下会得到 `libcrc32c.a`（静态库）或 `libcrc32c.so`（动态库）以及对应的头文件。

## 🔗 4. 将 crc32c 集成到 TDLib
### 4.1 修改 TDLib 的 CMakeLists.txt
在 TDLib 的 `CMakeLists.txt` 中，需要让编译系统找到上一步编译的 `crc32c` 库。主要添加以下内容：
```cmake
# 添加 crc32c 的头文件路径
include_directories(/path/to/crc32c/install/include)
# 添加 crc32c 的库路径
link_directories(/path/to/crc32c/install/lib)

# 在 target_link_libraries 中链接 crc32c
target_link_libraries(tdlib crc32c)
```
如果 TDLib 原本通过 `find_package` 查找 `crc32c`，可以改为直接指定库路径。

### 4.2 为 TDLib 配置 HarmonyOS 工具链
在编译 TDLib 时，同样需要指定 `ohos.toolchain.cmake`。可以在 TDLib 根目录下创建 `build_ohos` 目录，并使用类似的 CMake 命令：
```bash
$OHOS_SDK_PATH/native/build-tools/cmake/bin/cmake -GNinja \
  -DOHOS_STL=c++_static \
  -DOHOS_ARCH=arm64-v8a \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$OHOS_SDK_PATH/native/build/cmake/ohos.toolchain.cmake" \
  -B build_ohos
```
之后执行 `ninja -C build_ohos` 即可编译 TDLib。

## ✅ 5. 验证与调试
- **检查链接结果**：使用 `readelf -d libtdlib.so` 查看是否依赖 `libcrc32c.so`（动态链接情况）。
- **运行简单测试**：编写一个调用 `crc32c` 函数的小程序，确认库能正常被调用。
- **常见问题**：
  - **符号未找到**：确保 `crc32c` 库的版本与 TDLib 需要的接口一致。
  - **编译错误**：检查 `OHOS_ARCH` 是否与设备架构匹配（如 `arm64-v8a` 或 `armeabi-v7a`）。
  - **工具链路径错误**：确认 `CMAKE_TOOLCHAIN_FILE` 的路径正确。

## 💎 总结
为 HarmonyOS 编译 `crc32c` 并集成到 TDLib 的关键步骤包括：
1.  **准备 HarmonyOS NDK 工具链**，特别是 `ohos.toolchain.cmake`。
2.  **使用该工具链编译 Google 的 crc32c 库**，得到适合 HarmonyOS 的静态库或动态库。
3.  **修改 TDLib 的构建配置**，让其链接刚才编译的 `crc32c` 库。
4.  **使用同样的工具链编译 TDLib**，生成最终可在 HarmonyOS 上运行的库文件。

整个过程与在 Android NDK 下编译第三方库类似，主要区别在于工具链文件的使用。如果遇到问题，可参考 HarmonyOS 官方关于三方库适配的文档[reference:4]以及 CMake 工具链的详细说明[reference:5]。

> 以上步骤基于 HarmonyOS NEXT NDK 和 Google crc32c 库的 CMake 构建方式。若 TDLib 内部已包含 crc32c 实现，则只需在 TDLib 的 CMakeLists.txt 中直接启用 HarmonyOS 工具链即可。

十.xxhash，cityhash，farmhash，highwayhash for HarmonyOS

在 HarmonyOS 上为 TDLib 编译 **xxHash、CityHash、FarmHash、HighwayHash** 等高性能哈希库，推荐使用 OpenHarmony SIG 维护的 **lycium** 交叉编译框架。以下流程已在 RK3568 开发板（OpenHarmony 3.2 Release）验证，适用于 HarmonyOS 标准系统。

---

## 1. 环境准备
### 1.1 安装 HarmonyOS Native SDK
从 [HarmonyOS 开发者官网](https://developer.huawei.com/consumer/cn/doc/hardware-guides/V5/sdk-download-V5) 下载 **OHOS Native SDK**（例如 `ohos-sdk-linux-*.tar.gz`），解压并配置环境变量：
```bash
# 解压 SDK
tar -zxvf ohos-sdk-linux-*.tar.gz -C ~/ohos-sdk/

# 设置环境变量（以 bash 为例）
export OHOS_SDK=~/ohos-sdk/linux
export PATH=$OHOS_SDK/native/llvm/bin:$PATH
```

### 1.2 获取 lycium 编译框架
lycium 是 OpenHarmony SIG 提供的 C/C++ 三方库交叉编译工具，可自动处理依赖、交叉编译和打包。
```bash
git clone https://gitee.com/openharmony-sig/tpc_c_cplusplus.git --depth=1
cd tpc_c_cplusplus/lycium
```

### 1.3 部署编译工具链
将 lycium 自带的工具链拷贝到 SDK 的 `native/llvm/bin` 目录：
```bash
cd Buildtools
sha512sum -c SHA512SUM  # 校验工具包
tar -zxvf toolchain.tar.gz
cp toolchain/* $OHOS_SDK/native/llvm/bin/
```

> **提示**：以上步骤参考了《HarmonyOS 开发实践 —— 基于 lycium 的开源 C 库编译与集成》中的环境准备部分[reference:0]。

---

## 2. 获取已移植的库源码
`tpc_c_cplusplus` 仓库的 `thirdparty` 目录已包含多个常用哈希库的移植配置：
- **xxHash**：已有完整的 HPKBUILD 脚本[reference:1]。
- **FarmHash**：已有完整的 HPKBUILD 与集成文档[reference:2]。
- **CityHash、HighwayHash**：尚未提供官方移植，需要手动创建 HPKBUILD。

若需编译 CityHash 或 HighwayHash，可参考下一节手动创建编译脚本。

---

## 3. 编译各个哈希库
### 3.1 编译 xxHash
xxHash 已配置好，直接运行 lycium 编译即可：
```bash
./build.sh xxHash
```
编译完成后，库文件会输出到 `lycium/usr/xxHash/{arm64-v8a,armeabi-v7a}/` 目录。

### 3.2 编译 FarmHash
FarmHash 的编译步骤类似，lycium 会自动下载源码并编译：
```bash
./build.sh farmhash
```
编译结果同样位于 `lycium/usr/farmhash/{arm64-v8a,armeabi-v7a}/`。

### 3.3 编译 CityHash（手动创建 HPKBUILD）
若仓库未提供 CityHash，可手动创建 `thirdparty/cityhash/HPKBUILD`，参考以下模板：
```bash
pkgname=cityhash
pkgver=1.1.1
source="https://github.com/google/cityhash/archive/refs/tags/v${pkgver}.tar.gz"
buildtools="cmake"
builddir=cityhash-${pkgver}

prepare() {
    mkdir -p $builddir/$ARCH-build
}

build() {
    cd $builddir/$ARCH-build
    cmake .. -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/llvm/cmake/ohos.toolchain.cmake \
             -DOHOS_ARCH=$ARCH
    make -j4
}

package() {
    mkdir -p $pkgdir/usr/lib $pkgdir/usr/include
    cp $builddir/$ARCH-build/libcityhash.so $pkgdir/usr/lib/
    cp $builddir/src/city.h $pkgdir/usr/include/
}
```
然后执行：
```bash
./build.sh cityhash
```

### 3.4 编译 HighwayHash（手动创建 HPKBUILD）
类似地，为 HighwayHash 创建 `thirdparty/highwayhash/HPKBUILD`：
```bash
pkgname=highwayhash
pkgver=1.0
source="https://github.com/google/highwayhash/archive/refs/tags/${pkgver}.tar.gz"
buildtools="cmake"
builddir=highwayhash-${pkgver}

prepare() {
    mkdir -p $builddir/$ARCH-build
}

build() {
    cd $builddir/$ARCH-build
    cmake .. -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/llvm/cmake/ohos.toolchain.cmake \
             -DOHOS_ARCH=$ARCH -DBUILD_TESTING=OFF
    make -j4
}

package() {
    mkdir -p $pkgdir/usr/lib $pkgdir/usr/include
    cp $builddir/$ARCH-build/libhighwayhash.so $pkgdir/usr/lib/
    cp $builddir/highwayhash/*.h $pkgdir/usr/include/
}
```
然后执行：
```bash
./build.sh highwayhash
```

> **说明**：手动创建 HPKBUILD 的方法参考了 lycium 官方文档中关于 `HPKBUILD` 变量与函数的定义[reference:3]。

---

## 4. 将编译好的库集成到 TDLib
### 4.1 组织库文件
将编译生成的库文件与头文件拷贝到 TDLib 工程的 `thirdparty` 目录中，保持如下结构：
```
tdlib/
├── thirdparty/
│   ├── xxhash/
│   │   ├── arm64-v8a/
│   │   │   ├── include/xxhash.h
│   │   │   └── lib/libxxhash.so
│   │   └── armeabi-v7a/
│   │       ├── include/xxhash.h
│   │       └── lib/libxxhash.so
│   ├── cityhash/
│   ├── farmhash/
│   └── highwayhash/
└── CMakeLists.txt
```

### 4.2 修改 TDLib 的 CMakeLists.txt
在 TDLib 的顶层 `CMakeLists.txt` 中，添加对这些库的查找与链接：
```cmake
# 根据目标架构选择路径
set(OHOS_ARCH arm64-v8a)  # 或 armeabi-v7a

# xxHash
find_library(XXHASH_LIB xxhash PATHS ${CMAKE_SOURCE_DIR}/thirdparty/xxhash/${OHOS_ARCH}/lib REQUIRED)
include_directories(${CMAKE_SOURCE_DIR}/thirdparty/xxhash/${OHOS_ARCH}/include)

# CityHash
find_library(CITYHASH_LIB cityhash PATHS ${CMAKE_SOURCE_DIR}/thirdparty/cityhash/${OHOS_ARCH}/lib REQUIRED)
include_directories(${CMAKE_SOURCE_DIR}/thirdparty/cityhash/${OHOS_ARCH}/include)

# FarmHash
find_library(FARMHASH_LIB farmhash PATHS ${CMAKE_SOURCE_DIR}/thirdparty/farmhash/${OHOS_ARCH}/lib REQUIRED)
include_directories(${CMAKE_SOURCE_DIR}/thirdparty/farmhash/${OHOS_ARCH}/include)

# HighwayHash
find_library(HIGHWAYHASH_LIB highwayhash PATHS ${CMAKE_SOURCE_DIR}/thirdparty/highwayhash/${OHOS_ARCH}/lib REQUIRED)
include_directories(${CMAKE_SOURCE_DIR}/thirdparty/highwayhash/${OHOS_ARCH}/include)

# 在目标中链接
target_link_libraries(your_target PRIVATE
    ${XXHASH_LIB}
    ${CITYHASH_LIB}
    ${FARMHASH_LIB}
    ${HIGHWAYHASH_LIB}
)
```

### 4.3 编译 TDLib
使用 HarmonyOS 的 CMake 工具链编译 TDLib：
```bash
cd tdlib
mkdir build && cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/llvm/cmake/ohos.toolchain.cmake \
         -DOHOS_ARCH=arm64-v8a
make
```

---

## 5. 注意事项
- **架构匹配**：确保编译的库架构（arm64-v8a/armeabi-v7a）与目标设备一致。
- **版本兼容**：若 TDLib 对哈希库有特定版本要求，需在 HPKBUILD 中指定对应版本。
- **网络问题**：lycium 会自动下载源码，若遇到网络问题，可手动下载源码包并放置到 `thirdparty/库名/` 目录下。
- **调试**：若运行时出现 `dlopen` 错误，检查库文件是否已打包到 HAP 中，并确认 `soname` 是否正确。

---

## 总结
通过 **lycium** 交叉编译框架，可以高效地为 HarmonyOS 编译 xxHash、FarmHash 等哈希库；对于尚未官方移植的库（如 CityHash、HighwayHash），手动编写 HPKBUILD 脚本即可完成编译。最后将编译好的库集成到 TDLib 的 CMake 工程中，即可在 HarmonyOS 上正常使用这些高性能哈希函数。

> 以上步骤基于 OpenHarmony SIG 提供的 lycium 工具及相关文档[reference:4][reference:5][reference:6]。实际操作时请根据所用的 HarmonyOS SDK 版本与设备架构进行适当调整。

十一.libevent for HarmonyOS

为 HarmonyOS 编译 TDLib 所依赖的 libevent，本质是为 OpenHarmony NDK 目标进行交叉编译。以下将分步详解，并提供两种主流方案。

## 📦 方案一：手动使用 CMake 交叉编译（推荐）
此方案直接利用 OpenHarmony NDK 提供的 CMake 工具链文件，流程清晰，适合需要自定义编译选项的场景。

### 1. 环境准备
- **安装 HarmonyOS NDK**（通常随 DevEco Studio 安装，也可单独下载）。确保 `OHOS_SDK` 环境变量已正确指向 SDK 根目录。
- **工具链文件**：NDK 提供了 `ohos.toolchain.cmake`，其中预定义了交叉编译所需的所有参数[reference:0]。
- **基础依赖**：确保系统已安装 `cmake`、`git`、`make` 等基础构建工具。

### 2. 获取 libevent 源码
推荐使用 OpenHarmony-SIG 维护的版本（已包含一些适配补丁）：
```bash
git clone https://gitee.com/openharmony-sig/libevent.git
cd libevent
```
也可以从官方仓库（https://github.com/libevent/libevent）下载，但可能需要额外适配。

### 3. 配置与编译 libevent
在 libevent 源码目录中，使用 CMake 配置交叉编译：
```bash
mkdir build_ohos && cd build_ohos
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake \
    -DOHOS_ARCH=arm64-v8a \          # 根据目标架构调整：armeabi-v7a、arm64-v8a、x86_64
    -DOHOS_STL=c++_shared \          # 使用动态链接的 C++ 运行时
    -DCMAKE_INSTALL_PREFIX=./install \
    -DEVENT__DISABLE_OPENSSL=ON      # 若不需要 OpenSSL 可关闭
```
参数说明：
- `CMAKE_TOOLCHAIN_FILE`：指定 OpenHarmony 的工具链文件，这是交叉编译的关键[reference:1]。
- `OHOS_ARCH`：目标架构，需与最终运行的设备一致[reference:2]。
- `OHOS_STL`：C++ 运行时链接方式，通常使用 `c++_shared`[reference:3]。
- `CMAKE_INSTALL_PREFIX`：指定安装路径，方便后续查找库文件。

执行编译与安装：
```bash
cmake --build . --parallel $(nproc)
cmake --install .
```
编译完成后，库文件将位于 `./install/lib`，头文件位于 `./install/include`。

## ⚙️ 方案二：使用 lycium 自动化编译框架
lycium 是 OpenHarmony 社区提供的自动化交叉编译框架，可简化第三方库的编译过程[reference:4]。

### 1. 环境准备
- 下载并解压 HarmonyOS SDK，配置 `OHOS_SDK` 环境变量。
- 获取 lycium 工具包，将其中的编译工具拷贝到 SDK 的 `native/llvm/bin` 目录[reference:5]。

### 2. 编译 libevent
进入 lycium 目录，执行：
```bash
./build.sh libevent
```
lycium 会自动从配置的仓库（如 OpenHarmony-SIG/libevent）下载源码并完成编译[reference:6]。编译后的库文件通常位于 `lycium/usr` 目录下。

## 🔗 将 libevent 集成到 TDLib
无论采用哪种方案编译 libevent，后续集成到 TDLib 的步骤是相似的。

### 1. 获取 TDLib 源码
```bash
git clone https://github.com/tdlib/td.git
cd td
```

### 2. 配置 TDLib 的 CMake
在 TDLib 的 CMake 配置中，需要指向已编译的 libevent 路径。可以通过设置 `CMAKE_PREFIX_PATH` 或直接指定库路径来实现：
```bash
mkdir build_ohos && cd build_ohos
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake \
    -DOHOS_ARCH=arm64-v8a \
    -DOHOS_STL=c++_shared \
    -DCMAKE_PREFIX_PATH=/path/to/libevent/install \  # 指向 libevent 的安装目录
    -DOPENSSL_ROOT_DIR=/path/to/openssl \            # 如果 TDLib 需要 OpenSSL
    -DCMAKE_BUILD_TYPE=Release
```
如果 TDLib 的 CMakeLists.txt 无法自动找到 libevent，可以手动指定：
```cmake
# 在 CMakeLists.txt 中添加（或通过命令行传递）
set(LibEvent_INCLUDE_DIR /path/to/libevent/install/include)
set(LibEvent_LIBRARY /path/to/libevent/install/lib/libevent.so)
```

### 3. 编译 TDLib
```bash
cmake --build . --parallel $(nproc)
```
编译成功后，即可在 `build_ohos` 目录下得到适用于 HarmonyOS 的 TDLib 库文件。

## 💡 常见问题与注意事项
1.  **架构匹配**：确保 `OHOS_ARCH` 与目标设备架构一致，否则可能导致无法运行。
2.  **C++ 运行时**：同一个应用中的所有 Native 库必须采用相同的 C++ 运行时链接方式（均为 `c++_shared` 或均为 `c++_static`）[reference:7]。
3.  **依赖库**：TDLib 可能还依赖 OpenSSL、zlib 等，这些库也需要用相同的工具链预先编译。
4.  **版本兼容**：建议使用 OpenHarmony-SIG 维护的 libevent 版本，以减少系统适配问题[reference:8]。
5.  **调试**：若遇到链接错误，可检查编译日志，确保 libevent 的库路径和头文件路径已正确传递给 TDLib 的 CMake。

## 📚 参考资源
- OpenHarmony-SIG/libevent 仓库：https://gitee.com/openharmony-sig/libevent[reference:9]
- OpenHarmony NDK 构建概述：https://docs.openharmony.cn/pages/v5.0/zh-cn/application-dev/napi/build-with-ndk-overview.md[reference:10]
- 基于 lycium 的 C 库编译与集成：https://cloud.tencent.com/developer/article/2470239[reference:11]
- 在 Windows 平台使用 OpenHarmony SDK 编译三方库：https://blog.csdn.net/MrJoice/article/details/149406310[reference:12]

按照上述步骤，你应该能够成功为 HarmonyOS 编译 libevent，并将其集成到 TDLib 中。如果在具体操作中遇到问题，可以查阅相关文档或社区讨论。

十二.libuv for HarmonyOS

在 TDLib 中为 HarmonyOS 编译 libuv，本质上是先完成 libuv 的交叉编译，再将其集成到 TDLib 的构建系统中。以下是详细步骤和关键注意事项。

## 1. 前提条件
| 项目 | 说明 |
|------|------|
| **HarmonyOS NDK** | 包含 `ohos.toolchain.cmake` 工具链文件。可从 [HarmonyOS SDK 下载](https://developer.harmonyos.com/cn/develop/deveco-studio#download) 的 “Native” 部分获取。 |
| **CMake ≥ 3.27** | 建议使用 HarmonyOS NDK 自带的 `cmake`（位于 `{OHOS_SDK}/native/build-tools/cmake/bin/`）。 |
| **Ninja** | 构建工具，通常已包含在 NDK 中。 |
| **libuv 源码** | 推荐使用 OpenHarmony 已适配的版本：<br> `git clone https://gitee.com/openharmony/third_party_libuv.git`<br>（也可使用上游 libuv，但可能需要额外补丁）。 |
| **TDLib 源码** | 从官方仓库克隆：`git clone https://github.com/tdlib/td.git`。 |

## 2. 编译 libuv for HarmonyOS
### 2.1 配置环境变量
```bash
# 假设 HarmonyOS NDK 解压到 /home/ohos/OH_SDK
export OHOS_SDK=/home/ohos/OH_SDK/ohos-sdk/linux
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=arm-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=arm-linux-ohos"
export LD="${OHOS_SDK}/native/llvm/bin/ld.lld"
export AR="${OHOS_SDK}/native/llvm/bin/llvm-ar"
export CFLAGS="-fPIC -D__MUSL__=1"
export CXXFLAGS="-fPIC -D__MUSL__=1"
```
> 这些环境变量确保了使用 HarmonyOS 的 Clang 编译器以及必要的编译标志[reference:0]。

### 2.2 使用 CMake 构建
进入 libuv 源码目录，执行以下命令：
```bash
mkdir build && cd build
# 指定工具链文件、目标架构等参数
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake" \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=./install \
  -GNinja

# 编译并安装
ninja && ninja install
```
编译成功后，`install` 目录下会包含 `libuv.a`（静态库）和 `include` 头文件。

### 2.3 常见错误与解决
- **编译器兼容性问题**：HarmonyOS NEXT 的 Clang 版本可能较新，若遇到未知的编译器选项或语法错误，可尝试在 `CMakeLists.txt` 中添加 `-Wno-error` 或降低 `-std` 版本[reference:1]。
- **系统库依赖缺失**：libuv 依赖 `pthread`、`librt` 等库，在 HarmonyOS 中可能名称不同。可通过在 `CMakeLists.txt` 中显式链接 `-lpthread -lrt` 解决[reference:2]。
- **平台宏定义缺失**：在 `CFLAGS`/`CXXFLAGS` 中添加 `-D__MUSL__=1` 可避免某些宏定义错误[reference:3]。

## 3. 将编译好的 libuv 集成到 TDLib
### 3.1 修改 TDLib 的 CMakeLists.txt
在 TDLib 的 `CMakeLists.txt` 中，找到关于 libuv 的配置部分（通常是通过 `find_package(libuv)` 或 `add_subdirectory` 引入），将其改为直接引用已编译的库：
```cmake
# 设置 libuv 的路径
set(LIBUV_ROOT /path/to/libuv/install)
include_directories(${LIBUV_ROOT}/include)
link_directories(${LIBUV_ROOT}/lib)

# 在目标链接中添加 libuv
target_link_libraries(your_target libuv)
```
### 3.2 使用 CMake 参数指定库路径
也可以在配置 TDLib 时通过 CMake 参数传递 libuv 的位置：
```bash
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake" \
  -DOHOS_ARCH=arm64-v8a \
  -DLIBUV_INCLUDE_DIR=/path/to/libuv/install/include \
  -DLIBUV_LIBRARY=/path/to/libuv/install/lib/libuv.a
```

## 4. 完整流程示例
```bash
# 1. 准备环境
export OHOS_SDK=/home/ohos/OH_SDK/ohos-sdk/linux
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=arm-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=arm-linux-ohos"

# 2. 编译 libuv
cd third_party_libuv
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake" \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=./install \
  -GNinja
ninja install

# 3. 编译 TDLib
cd ../../td
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake" \
  -DOHOS_ARCH=arm64-v8a \
  -DLIBUV_INCLUDE_DIR=../../third_party_libuv/build/install/include \
  -DLIBUV_LIBRARY=../../third_party_libuv/build/install/lib/libuv.a
cmake --build .
```

## 5. 参考资料
1. [开源三方库HarmonyOS NEXT适配指导](https://my.oschina.net/u/9174168/blog/18444120) – 详细介绍了 HarmonyOS NEXT 上编译 C/C++ 库的通用方法。
2. [HarmonyOS NEXT系列之编译三方C/C++库](https://blog.csdn.net/qq_42896653/article/details/150148305) – 提供了 CMake 工具链的具体使用示例。
3. [HarmonyOS 鸿蒙Next编译libuv第三方C库出错](https://bbs.itying.com/topic/67b6885a36bb8501316f4664) – 列出了编译 libuv 时常见的错误及解决思路。
4. [OpenHarmony third_party_libuv 仓库](https://gitee.com/openharmony/third_party_libuv) – 官方适配的 libuv 源码。

## 总结
关键步骤为：**配置 HarmonyOS 工具链 → 交叉编译 libuv → 将编译好的 libuv 链接到 TDLib**。若遇到编译错误，请仔细检查编译器版本、系统库依赖以及平台宏定义。建议优先使用 OpenHarmony 已适配的 libuv 版本，以降低适配难度。

十三.utf8proc for HarmonyOS

在 TDLib 中编译 **utf8proc** 用于 HarmonyOS（鸿蒙）平台，需要先为鸿蒙交叉编译该 C 库，再将其集成到 TDLib 的构建系统中。以下是详细步骤。

## 📦 1. 编译前的准备
### 1.1 安装 HarmonyOS NDK（原生开发工具包）
- 从 [HarmonyOS SDK 下载页面](https://developer.harmonyos.com/cn/develop/deveco-studio#download) 获取并安装 **DevEco Studio**，其中包含 NDK。
- 解压后，设置环境变量（以 macOS/Linux 为例）：
  ```bash
  export OHOS_SDK=/path/to/ohos-sdk
  export PATH=$OHOS_SDK/native/llvm/bin:$PATH
  ```

### 1.2 获取 utf8proc 源码
utf8proc 是一个用于 UTF-8 文本处理的轻量级 C 库，TDLib 依赖它进行 Unicode 规范化等操作。您可以从其官方仓库下载源码：
```bash
git clone https://github.com/JuliaStrings/utf8proc.git
cd utf8proc
# 或直接下载发布包（如 v2.8.0）
wget https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v2.8.0.tar.gz
tar -xzf v2.8.0.tar.gz
cd utf8proc-2.8.0
```

## 🔧 2. 编译 utf8proc for HarmonyOS
### 方法一：使用 Lycium 自动化编译（推荐）
Lycium 是鸿蒙官方提供的开源 C 库交叉编译框架，可简化编译过程[reference:0]。

1. **克隆 Lycium 仓库**
   ```bash
   git clone https://gitee.com/openharmony-sig/tpc_c_cplusplus.git
   cd tpc_c_cplusplus/lycium
   ```

2. **配置编译环境**
   - 将 NDK 工具链复制到 Lycium 目录：
     ```bash
     cp $OHOS_SDK/native/llvm/bin/* ./Buildtools/
     ```
   - 运行环境校验：
     ```bash
     ./Buildtools/sha512sum -c SHA512SUM
     ```

3. **编译 utf8proc**
   - 将 utf8proc 源码目录复制到 `thirdparty` 下。
   - 编辑 `HPKBUILD` 文件（若需要，可调整架构等选项）。
   - 执行编译：
     ```bash
     ./build.sh utf8proc
     ```
   - 编译后的库文件会生成在 `lycium/usr/${OHOS_ARCH}/lib/` 下，头文件在 `lycium/usr/include/`。

### 方法二：手动 CMake 编译
如果希望更精细地控制编译选项，可以使用 CMake 直接编译。

1. **创建构建目录**
   ```bash
   mkdir build_hmos && cd build_hmos
   ```

2. **配置 CMake**
   使用鸿蒙提供的 `ohos.toolchain.cmake` 工具链文件[reference:1]：
   ```bash
   cmake .. \
     -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake \
     -DOHOS_ARCH=arm64-v8a \
     -DCMAKE_INSTALL_PREFIX=./install \
     -DUTF8PROC_STATIC=ON   # 若需要静态库
   ```

3. **编译并安装**
   ```bash
   make -j$(nproc)
   make install
   ```
   - 编译后的静态库（`.a`）或动态库（`.so`）会位于 `install/lib/`，头文件在 `install/include/`。

## 📚 3. 将编译好的 utf8proc 集成到 TDLib
TDLib 默认通过 CMake 查找 utf8proc。您可以通过以下方式让 TDLib 使用刚编译的鸿蒙版本。

1. **在 TDLib 的 CMake 中指定 utf8proc 路径**
   在 TDLib 的 CMake 配置中，添加：
   ```cmake
   set(UTF8PROC_INCLUDE_DIR /path/to/utf8proc/install/include)
   set(UTF8PROC_LIBRARY /path/to/utf8proc/install/lib/libutf8proc.a)
   ```

2. **重新配置并编译 TDLib**
   ```bash
   cd td
   mkdir build && cd build
   cmake .. \
     -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake \
     -DOHOS_ARCH=arm64-v8a \
     -DUTF8PROC_INCLUDE_DIR=/path/to/utf8proc/install/include \
     -DUTF8PROC_LIBRARY=/path/to/utf8proc/install/lib/libutf8proc.a
   make -j$(nproc)
   ```

## 💡 4. 常见问题与注意事项
| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 编译时提示 “找不到工具链” | `OHOS_SDK` 环境变量未正确设置 | 检查 `$OHOS_SDK/native/llvm/bin` 是否存在，并确保 PATH 包含该目录。 |
| 链接时出现 “undefined reference to utf8proc_xxx” | 库文件未正确链接 | 确认 `UTF8PROC_LIBRARY` 路径指向正确的静态库或动态库。 |
| 运行时报 “libutf8proc.so not found” | 动态库未打包到 HAP 中 | 将 `.so` 文件放入 `entry/libs/${OHOS_ARCH}/` 目录，并在 CMake 中设置 `SET_TARGET_PROPERTIES(... LIBRARY_OUTPUT_DIRECTORY ...)`[reference:2]。 |
| 需要其他架构（如 x86_64） | 默认只编译 arm64-v8a | 在 CMake 或 HPKBUILD 中修改 `OHOS_ARCH`，如 `-DOHOS_ARCH=x86_64`[reference:3]。 |

## 📖 5. 总结
为 HarmonyOS 编译 utf8proc 主要涉及：
1.  **准备鸿蒙 NDK 环境**。
2.  **获取 utf8proc 源码**。
3.  **选择 Lycium 自动化编译或手动 CMake 编译**，得到适用于鸿蒙的库文件。
4.  **在 TDLib 的 CMake 配置中指定该库的路径**，完成集成。

> 以上步骤基于 HarmonyOS NDK 提供的标准工具链，若遇到版本差异，可参考 [HarmonyOS 官方 NDK 文档](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/build-third-party-library-0000001333320913) 或 [Lycium 使用指南](https://gitee.com/openharmony-sig/tpc_c_cplusplus)。

十四.double-conversion for HarmonyOS

在 TDLib 中编译 `double‑conversion` 库（用于高精度浮点数字符串转换）并移植到 HarmonyOS（OpenHarmony）平台，主要分为 **交叉编译 double‑conversion** 与 **将其集成到 TDLib** 两步。以下是详细操作指南。

---

## 🔧 一、为 HarmonyOS 交叉编译 double‑conversion

### 1. 获取源码
从官方仓库下载（或克隆）double‑conversion 源码：
```bash
git clone https://github.com/google/double-conversion.git
cd double-conversion
```
源码目录结构如表1所示[reference:0]。

### 2. 配置交叉编译工具链
OpenHarmony 使用 Clang 工具链进行交叉编译。需要将以下工具链配置添加到 `double‑conversion` 顶层 `CMakeLists.txt` 中（也可通过 `-D` 参数传递）[reference:1]：

```cmake
set(CMAKE_CROSSCOMPILING TRUE)
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_CXX_COMPILER_ID Clang)
set(CMAKE_TOOLCHAIN_PREFIX llvm-)

# C 编译器及标志（必须指定 --target）
set(CMAKE_C_COMPILER clang)
set(CMAKE_C_FLAGS "--target=arm-liteos -D__clang__ -march=armv7-a -w -mfloat-abi=softfp -mcpu=cortex-a7 -mfpu=neon-vfpv4")

# C++ 编译器及标志
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_CXX_FLAGS "--target=arm-liteos -D__clang__ -march=armv7-a -w -mfloat-abi=softfp -mcpu=cortex-a7 -mfpu=neon-vfpv4")

# 链接器及链接标志（必须指定 --target 和 --sysroot）
set(MY_LINK_FLAGS "--target=arm-liteos --sysroot=${OHOS_SYSROOT_PATH}")
set(CMAKE_LINKER clang)
set(CMAKE_CXX_LINKER clang++)
set(CMAKE_C_LINKER clang)
set(CMAKE_C_LINK_EXECUTABLE "${CMAKE_C_LINKER} ${MY_LINK_FLAGS} <FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_CXX_LINKER} ${MY_LINK_FLAGS} <FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")

# 指定 sysroot
set(CMAKE_SYSROOT ${OHOS_SYSROOT_PATH})
```

### 3. 执行交叉编译
在 `double‑conversion` 源码目录下创建 `build` 目录并执行 CMake 配置和编译：
```bash
mkdir build && cd build
cmake .. -DBUILD_TESTING=ON -DOHOS_SYSROOT_PATH="/path/to/ohos/sysroot"
make -j
```
> **关键参数说明**：
> - `OHOS_SYSROOT_PATH` 需指定为 OpenHarmony 全量编译后生成的 `sysroot` 目录的绝对路径（例如 `out/hispark_xxx/ipcamera_hispark_xxx/sysroot`）[reference:2]。
> - `BUILD_TESTING=ON` 可选，用于生成测试用例。

### 4. 查看编译结果
编译完成后，在 `build` 目录下会生成静态库文件 `libdouble‑conversion.a` 以及测试用例（位于 `test/` 目录）[reference:3]。

### 5. 测试（可选）
将生成的测试可执行文件 `cctest` 推入开发板，运行测试以验证库的正确性[reference:4]。

---

## 📦 二、将编译好的 double‑conversion 集成到 TDLib

TDLib 通常通过 CMake 的 `find_package` 或 `add_subdirectory` 来引入 double‑conversion。根据你的集成方式，可选择以下任一方法：

### 方法一：通过 CMAKE_PREFIX_PATH 指向已编译的库
1. 将编译得到的 `libdouble‑conversion.a` 及其头文件（位于 `double‑conversion/double‑conversion/`）安装到某个目录，例如 `/path/to/ohos‑double‑conversion/`。
2. 在编译 TDLib 时，通过 `CMAKE_PREFIX_PATH` 指定该目录：
   ```bash
   cd tdlib
   mkdir build && cd build
   cmake .. -DCMAKE_PREFIX_PATH=/path/to/ohos‑double‑conversion \
            -DCMAKE_TOOLCHAIN_FILE=/path/to/ohos‑toolchain.cmake
   make
   ```

### 方法二：替换 TDLib 子模块中的 double‑conversion
如果 TDLib 将 double‑conversion 作为子模块（通常在 `third‑party/` 目录），可以直接替换为已编译的库：
1. 将 `libdouble‑conversion.a` 和头文件拷贝到 TDLib 的 `third‑party/double‑conversion/` 目录。
2. 修改 TDLib 的 CMakeLists.txt，确保链接时使用该静态库。

### 方法三：直接作为静态库链接
在 TDLib 的 CMakeLists.txt 中，通过 `target_link_libraries` 直接指定静态库路径：
```cmake
target_link_libraries(tdlib
    /path/to/ohos‑double‑conversion/build/libdouble‑conversion.a
)
```

---

## 💎 总结
| 步骤 | 关键操作 |
|------|----------|
| 1. 获取源码 | 从 GitHub 克隆 double‑conversion 仓库 |
| 2. 配置工具链 | 在 CMakeLists.txt 中添加 OpenHarmony Clang 工具链配置[reference:5] |
| 3. 执行交叉编译 | 使用 `cmake` 指定 `OHOS_SYSROOT_PATH` 并 `make` 编译[reference:6] |
| 4. 集成到 TDLib | 通过 `CMAKE_PREFIX_PATH`、替换子模块或直接链接静态库 |

> **注意事项**：
> - 工具链中的 `--target=arm-liteos` 和 `--sysroot` 必须正确设置，否则链接会失败。
> - 若 TDLib 依赖其他第三方库，需同样为 HarmonyOS 交叉编译并集成。
> - 建议先单独测试 double‑conversion 的编译结果，再集成到 TDLib 中。

按照上述步骤，你可以在 HarmonyOS（OpenHarmony）平台上成功编译 double‑conversion 库，并将其用于 TDLib 的构建。如果在集成过程中遇到问题，请检查工具链配置及库的路径是否正确。

十五.snappy for HarmonyOS

在 TDLib 中为 HarmonyOS 编译 Snappy，核心是**使用 HarmonyOS NDK 提供的 CMake 工具链对 Snappy 进行交叉编译**，随后在编译 TDLib 时正确链接生成的库。下面将分步详细说明。

## 🔧 1. 环境准备
### 1.1 安装 HarmonyOS NEXT SDK（NDK）
从华为官方下载 [Command Line Tools For HarmonyOS NEXT](https://developer.huawei.com/consumer/cn/deveco-studio)，解压后得到 SDK 目录，其中 `native/` 文件夹包含 NDK 所需的编译工具、工具链文件等。

### 1.2 配置环境变量
在 Linux 环境下，可以设置以下变量以便后续使用：
```bash
export OHOS_SDK=/path/to/ohos-sdk/linux
export CC="$OHOS_SDK/native/llvm/bin/clang --target=arm-linux-ohos"
export CXX="$OHOS_SDK/native/llvm/bin/clang++ --target=arm-linux-ohos"
export AR="$OHOS_SDK/native/llvm/bin/llvm-ar"
export LD="$OHOS_SDK/native/llvm/bin/ld.lld"
export CMAKE_TOOLCHAIN_FILE="$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake"
```

## 📦 2. 编译 Snappy
Snappy 是 Google 开源的压缩库，**采用 CMake 构建系统**[reference:0]。以下是针对 HarmonyOS 的编译步骤。

### 2.1 获取源码
```bash
git clone https://github.com/google/snappy.git
cd snappy
git checkout 1.1.9  # 建议使用稳定版本
```

### 2.2 编写 CMake 编译脚本
在 Snappy 源码根目录创建 `cmake_exec.sh`，内容参考 HarmonyOS 官方提供的模板[reference:1]：
```bash
#!/bin/bash
OHOS_SDK_PATH="/path/to/ohos-sdk/linux"
$OHOS_SDK_PATH/native/build-tools/cmake/bin/cmake -GNinja \
  -DOHOS_STL=c++_static \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_PLATFORM=OHOS \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DCMAKE_TOOLCHAIN_FILE="$OHOS_SDK_PATH/native/build/cmake/ohos.toolchain.cmake" \
  -B build
```
参数说明：
- `OHOS_ARCH`：目标架构，可选 `armeabi-v7a`、`arm64-v8a`、`x86_64`。
- `OHOS_STL`：C++ 库链接方式，`c++_static`（静态）或 `c++_shared`（动态）。
- `CMAKE_TOOLCHAIN_FILE`：指定 HarmonyOS 的工具链文件。

### 2.3 执行编译
```bash
# 生成构建文件
bash cmake_exec.sh

# 使用 ninja 进行编译
$OHOS_SDK_PATH/native/build-tools/cmake/bin/ninja -C build

# 安装到 install 目录（可选）
$OHOS_SDK_PATH/native/build-tools/cmake/bin/ninja -C build install
```
编译完成后，在 `build/` 或 `install/` 目录下会得到 `libsnappy.a`（静态库）或 `libsnappy.so`（动态库）。

## 🔗 3. 将 Snappy 集成到 TDLib
TDLib 本身是一个跨平台库，其编译依赖 OpenSSL、zlib 等[reference:2]。若需使用自定义的 Snappy 库，需在编译 TDLib 时指定 Snappy 的路径。

### 3.1 修改 TDLib 的 CMake 配置
在 TDLib 的 `CMakeLists.txt` 或通过 `cmake` 命令参数中设置 Snappy 的查找路径：
```bash
cd tdlib
mkdir build
cd build
# 指定 Snappy 的安装路径
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="$OHOS_SDK_PATH/native/build/cmake/ohos.toolchain.cmake" \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static \
  -DSNAPPY_ROOT=/path/to/snappy/install \
  -DSNAPPY_LIBRARY=/path/to/snappy/install/lib/libsnappy.a \
  -DSNAPPY_INCLUDE_DIR=/path/to/snappy/install/include
```
如果 TDLib 使用 `find_package(Snappy)`，则需确保 `SnappyConfig.cmake` 在 `SNAPPY_ROOT` 下；若没有，可手动设置 `SNAPPY_LIBRARY` 和 `SNAPPY_INCLUDE_DIR`。

### 3.2 编译 TDLib
```bash
$OHOS_SDK_PATH/native/build-tools/cmake/bin/ninja -C build
```
编译成功后，即可得到适用于 HarmonyOS 的 TDLib 库文件。

## 💡 4. 注意事项
1.  **架构匹配**：确保 `OHOS_ARCH` 与目标设备架构一致（如 `arm64-v8a`）。
2.  **C++ 库链接**：若使用 `c++_shared`，需将对应的 `libc++_shared.so` 打包到应用中。
3.  **工具链版本**：HarmonyOS NDK 会更新，建议使用与 SDK 版本匹配的工具链。
4.  **调试与发布**：调试时可使用 `-DCMAKE_BUILD_TYPE=Debug` 以保留符号信息。
5.  **依赖传递**：若 TDLib 还依赖其他第三方库（如 OpenSSL、zlib），同样需先用 HarmonyOS 工具链编译。

## 📚 参考资源
- **开源三方库 HarmonyOS NEXT 适配指导**[reference:3] – 详细介绍了如何使用 HarmonyOS NDK 的 CMake 工具链编译第三方库。
- **HarmonyOS NEXT 系列之编译三方 C/C++ 库**[reference:4] – 提供了从创建项目到编译成 .so 的完整流程。
- **Snappy 百度百科**[reference:5] – 说明 Snappy 采用 CMake 构建系统。
- **TDLib 编译与使用博客**[reference:6] – 列出了 TDLib 的主要依赖项。

按照上述步骤，即可为 HarmonyOS 编译 Snappy 并将其集成到 TDLib 中。如果在编译过程中遇到具体错误，可进一步调整 CMake 参数或修改源码中的平台相关宏定义。

十六.lz4 for HarmonyOS

在 HarmonyOS 上编译 TDLib 时，需要先为其依赖的 **lz4** 压缩库进行交叉编译。下面将分步介绍如何完成 lz4 的编译，并将其集成到 TDLib 的构建中。

## 📦 1. 环境准备
首先需要搭建 HarmonyOS 的交叉编译环境。

| 所需组件 | 说明 | 参考 |
|:----------|:------|:------|
| **HarmonyOS SDK** | 提供 LLVM 工具链、系统头文件及库。 | 官方文档[reference:0] |
| **CMake** (≥3.14) | 构建系统生成工具。 | 通常包含在 SDK 中 |
| **LLVM/clang** | HarmonyOS 使用的编译器。 | SDK 中的 `toolchains/llvm` |
| **Termony** (可选) | 开源鸿蒙终端工具，可简化第三方库的构建。 | 本文第 2 步使用其脚本 |

> 建议将 `OHOS_SDK_HOME` 环境变量指向 SDK 根目录，并将 `$OHOS_SDK_HOME/toolchains/llvm/bin` 加入 `PATH`。

## 🔧 2. 为 HarmonyOS 编译 lz4
### 方法一：使用 Termony 脚本（推荐）
Termony 提供了专门的 `create-hnp.sh` 脚本，可自动完成 lz4 的下载、配置、编译和打包。关键步骤包括：

1. **获取脚本**（通常位于 Termony 项目的 `build-hnp` 目录）。
2. **设置环境变量**并执行构建：
   ```bash
   export OHOS_ARCH=aarch64   # 根据目标设备选择
   export OHOS_ABI=arm64-v8a
   sh ./create-hnp.sh
   ```
3. **验证产物**。脚本会在 `build-hnp/sysroot` 下生成 lz4 的库文件（`liblz4.so` 或 `liblz4.a`）和头文件[reference:1][reference:2]。

### 方法二：手动使用 CMake 交叉编译
若希望更手动地控制编译过程，可以使用 CMake 直接交叉编译 lz4。

1. **下载 lz4 源码**（以 v1.10.0 为例）：
   ```bash
   wget https://github.com/lz4/lz4/releases/download/v1.10.0/lz4-1.10.0.tar.gz
   tar xzf lz4-1.10.0.tar.gz
   cd lz4-1.10.0
   ```

2. **创建 CMake 工具链文件**（如 `ohos.toolchain.cmake`），内容参考：
   ```cmake
   set(CMAKE_SYSTEM_NAME Linux)
   set(CMAKE_SYSTEM_PROCESSOR aarch64)
   set(CMAKE_C_COMPILER ${OHOS_SDK_HOME}/toolchains/llvm/bin/clang)
   set(CMAKE_CXX_COMPILER ${OHOS_SDK_HOME}/toolchains/llvm/bin/clang++)
   set(CMAKE_SYSROOT ${OHOS_SDK_HOME}/sysroot)
   ```

3. **配置并编译**：
   ```bash
   mkdir build && cd build
   cmake .. \
     -DCMAKE_TOOLCHAIN_FILE=../ohos.toolchain.cmake \
     -DCMAKE_INSTALL_PREFIX=./install \
     -DBUILD_SHARED_LIBS=OFF   # 建议静态库，便于后续链接
   make -j$(nproc)
   make install
   ```
   编译后的库文件位于 `install/lib`，头文件位于 `install/include`。

## 📚 3. 将 lz4 集成到 TDLib
TDLib 的 CMake 构建系统会自动查找 lz4，但需要确保它能在交叉编译环境下找到正确的版本。

### 方式一：通过 CMake 变量指定路径
在配置 TDLib 时，直接指定 lz4 的安装路径：
```bash
cd td  # TDLib 源码目录
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=../ohos.toolchain.cmake \
  -DLZ4_INCLUDE_DIR=/path/to/lz4/install/include \
  -DLZ4_LIBRARY=/path/to/lz4/install/lib/liblz4.a
```

### 方式二：将 lz4 作为子模块嵌入
1. 将 lz4 源码复制到 TDLib 源码树的 `third_party/lz4` 目录。
2. 在 TDLib 的 `CMakeLists.txt` 中增加类似以下代码，将 lz4 作为子目录添加：
   ```cmake
   add_subdirectory(third_party/lz4)
   include_directories(third_party/lz4/include)
   target_link_libraries(tdlib PRIVATE lz4)
   ```

## 🏗 4. 编译 TDLib
完成 lz4 集成后，即可开始编译 TDLib。

1. **进入 TDLib 构建目录**，使用相同的 CMake 工具链文件进行配置：
   ```bash
   cd td/build
   cmake .. \
     -DCMAKE_TOOLCHAIN_FILE=../ohos.toolchain.cmake \
     -DCMAKE_BUILD_TYPE=Release \
     -DENABLE_LTO=ON
   ```

2. **执行编译**：
   ```bash
   make -j$(nproc)
   ```
   编译成功后，会在 `lib` 目录下生成 `libtdjson.so`（或 `libtdjson.a`）。

## ✅ 5. 验证与测试
- **检查产物**：使用 `file` 命令确认生成的库文件是否为 HarmonyOS 架构：
  ```bash
  file libtdjson.so
  ```
  应显示 `ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked`。

- **简单测试**：若有 HarmonyOS 设备或模拟器，可将库文件推送到设备，并编写一个简单的 C 程序调用 `td_json_client_create` 等接口，验证库能否正常加载。

## 💎 总结
在 HarmonyOS 上编译 TDLib 的关键在于先为其依赖的 **lz4** 完成交叉编译。推荐使用 Termony 脚本自动完成这一步骤，随后通过 CMake 变量或子模块方式将 lz4 集成到 TDLib 的构建中。最后，使用 HarmonyOS SDK 提供的 LLVM 工具链编译 TDLib，即可得到可在 HarmonyOS 上运行的库文件。

> 以上步骤基于公开的 HarmonyOS 构建文档[reference:3]及 Termony 的 lz4 构建指南[reference:4]。实际操作时请根据所用的 SDK 版本和目标设备架构（`OHOS_ARCH`、`OHOS_ABI`）适当调整参数。

十七.tdutils for HarmonyOS

为 HarmonyOS 编译 TDLib 的 **tdutils**（即 TDLib 的基础工具库）属于典型的“C++ 三方库移植”任务，其核心是**使用 HarmonyOS Native SDK 提供的 CMake 工具链进行交叉编译**。以下是详细步骤与关键注意事项。

---

## 🛠️ 环境准备
| 项目 | 说明 |
|------|------|
| **HarmonyOS Native SDK** | 用于交叉编译的 NDK，内含 `ohos.toolchain.cmake` 工具链文件。可从 [HarmonyOS SDK 下载页面](https://developer.harmonyos.com/cn/develop/deveco-studio#download) 获取。 |
| **CMake** ≥ 3.0.2 | 建议使用 SDK 自带的 CMake（位于 `{OHOS_SDK_PATH}/native/build-tools/cmake/bin/`），或系统安装的版本。 |
| **Ninja**（推荐） | 构建速度更快，SDK 中已包含。也可用 `make` 替代。 |
| **Linux/macOS 开发机** | 建议在 Linux 环境下进行交叉编译，Windows 可通过 WSL 或虚拟机操作。 |
| **TDLib 依赖** | OpenSSL、zlib、gperf（仅编译时需要）。这些库需提前为 HarmonyOS 架构编译好，或直接使用 SDK 中已提供的版本。 |

> 注：本文以 **HarmonyOS NEXT**（OpenHarmony 内核）为例，其他 HarmonyOS 版本（如 LiteOS）的编译步骤类似，但工具链路径可能略有不同。

---

## 📦 获取 TDLib 源代码
```bash
git clone https://github.com/tdlib/td.git
cd td
```
TDLib 的代码结构中，`tdutils` 模块位于 `tdutils/` 目录下，但通常需要整体编译 TDLib 后再提取所需库文件。

---

## ⚙️ 配置 HarmonyOS 编译工具链
HarmonyOS Native SDK 提供了 **ohos.toolchain.cmake** 工具链文件，用于预定义交叉编译参数。关键变量如下：

| 变量 | 说明 |
|------|------|
| `OHOS_ARCH` | 目标架构，可选 `arm64-v8a`、`armeabi-v7a`、`x86_64`。 |
| `OHOS_STL` | C++ 库链接方式，可选 `c++_shared`（动态）或 `c++_static`（静态）。 |
| `OHOS_PLATFORM` | 平台，固定为 `OHOS`。 |
| `CMAKE_TOOLCHAIN_FILE` | 指定工具链文件的路径。 |

**示例编译脚本（`cmake_exec.sh`）**：
```bash
#!/bin/bash
# 设置 HarmonyOS SDK 路径
OHOS_SDK_PATH="/path/to/harmonyos/sdk"

# 创建构建目录
mkdir -p build && cd build

# 调用 CMake，指定工具链和参数
$OHOS_SDK_PATH/native/build-tools/cmake/bin/cmake -GNinja \
  -DOHOS_STL=c++_static \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_PLATFORM=OHOS \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DCMAKE_TOOLCHAIN_FILE="$OHOS_SDK_PATH/native/build/cmake/ohos.toolchain.cmake" \
  ..
```
> 以上脚本参考了 HarmonyOS NEXT 适配指导中的 CMake 编译示例[reference:0]。

---

## 🔨 编译 tdutils
### 1. 整体编译 TDLib
在配置好 CMake 后，直接使用 Ninja 或 make 进行编译：
```bash
# 使用 Ninja（推荐）
$OHOS_SDK_PATH/native/build-tools/cmake/bin/ninja -j4

# 或使用 make
make -j4
```
编译完成后，会在 `build/` 目录下生成所有库文件，包括 **libtdutils.a**（静态库）或 **libtdutils.so**（动态库）。

### 2. 单独编译 tdutils（可选）
如果只需编译 tdutils 模块，可以在 CMake 配置后指定目标：
```bash
$OHOS_SDK_PATH/native/build-tools/cmake/bin/ninja tdutils
# 或
make tdutils
```

### 3. 安装库文件
```bash
$OHOS_SDK_PATH/native/build-tools/cmake/bin/ninja install
# 或
make install
```
库文件将被复制到 `install/` 目录下，方便后续集成。

---

## 📝 常见问题与解决方案
| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| **找不到 OpenSSL/zlib** | 依赖库未为 HarmonyOS 架构编译。 | 1. 使用 SDK 中已编译好的版本；<br>2. 自行交叉编译这些依赖，并通过 `-DOPENSSL_ROOT_DIR=`、`-DZLIB_ROOT=` 等 CMake 参数指定路径。 |
| **链接时缺少 C++ 符号** | `OHOS_STL` 设置与依赖库不一致。 | 确保所有依赖库都使用相同的 `OHOS_STL`（全静态或全动态）。 |
| **编译过程中内存不足** | TDLib 编译需要较大内存（≥8GB）。 | 增加 swap 空间，或减少并行编译线程数（`-j2`）。 |
| **工具链文件找不到** | `CMAKE_TOOLCHAIN_FILE` 路径错误。 | 确认 `{OHOS_SDK_PATH}/native/build/cmake/ohos.toolchain.cmake` 是否存在。 |

---

## 📚 参考资料
1.  **OpenHarmony C/C++ 三方库移植适配指导说明**（2026-01-17 更新）—— 提供了 Lycium 交叉编译工具的使用指南[reference:1]。
2.  **NDK 工程构建概述**—— 详细介绍了 `ohos.toolchain.cmake` 的使用方法[reference:2]。
3.  **开源三方库 HarmonyOS NEXT 适配指导**（2025-05-21）—— 包含 CMake 编译脚本示例[reference:3]。
4.  **TDLib 官方编译指南**（非 HarmonyOS）—— 列出了依赖项和基本编译步骤[reference:4]。

---

## 💎 总结
为 HarmonyOS 编译 **tdutils** 的关键在于：
1.  **使用正确的工具链**：通过 `ohos.toolchain.cmake` 配置交叉编译参数。
2.  **处理依赖库**：确保 OpenSSL、zlib 等已针对目标架构（如 `arm64-v8a`）编译。
3.  **统一 C++ 运行时**：所有库的 `OHOS_STL` 设置需一致。

如果遇到问题，建议参考上述官方移植指导，或搜索“HarmonyOS 交叉编译 + 具体错误信息”获取更多社区支持。祝编译顺利！

十八.tdactor for HarmonyOS

在TDLib中编译tdactor for HarmonyOS需要一些适配工作，以下是详细步骤和注意事项：

## 一、环境准备

### 1. **开发环境要求**
```
- HarmonyOS SDK 3.0+
- DevEco Studio 3.0+
- HarmonyOS NDK (Native Development Kit)
- CMake 3.10+
- Ninja 或 Make
- Git
```

### 2. **获取TDLib源码**
```bash
git clone https://github.com/tdlib/td.git
cd td
```

## 二、HarmonyOS适配关键点

### 1. **系统接口差异**
- 替换Linux/Android特定API为HarmonyOS API
- 文件系统路径适配
- 网络接口适配

### 2. **创建HarmonyOS编译配置**
在`td/CMakeLists.txt`中添加HarmonyOS支持：

```cmake
# 检测HarmonyOS
if(HARMONYOS)
    set(CMAKE_SYSTEM_NAME HarmonyOS)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DOHOS_PLATFORM")
    
    # HarmonyOS特定设置
    add_definitions(-DTD_HARMONYOS)
    
    # 替换pthread相关实现
    list(APPEND TD_SYSTEM_SOURCES 
        ${CMAKE_CURRENT_SOURCE_DIR}/harmonyos/thread.cpp
    )
endif()
```

## 三、tdactor适配详解

### 1. **Actor系统核心组件**
```cpp
// harmonyos/actor/ConcurrentScheduler_ohos.cpp
#include "td/actor/ConcurrentScheduler.h"
#include <thread>
#include <mutex>
#include "ohos_init.h"
#include "cmsis_os2.h"

namespace td {

class HarmonyOSThread {
private:
    osThreadId_t thread_id_;
    
public:
    void init() {
        osThreadAttr_t attr = {
            .name = "tdactor",
            .attr_bits = 0U,
            .cb_mem = NULL,
            .cb_size = 0U,
            .stack_mem = NULL,
            .stack_size = 8192,
            .priority = osPriorityNormal,
        };
        
        thread_id_ = osThreadNew(
            [](void* arg) {
                auto scheduler = static_cast<ConcurrentScheduler*>(arg);
                scheduler->start();
                while (scheduler->run_main(10)) {
                    osDelay(1);
                }
            },
            scheduler_,
            &attr
        );
    }
    
    void join() {
        osThreadJoin(thread_id_);
    }
};
}
```

### 2. **网络适配层**
```cpp
// harmonyos/net/TcpSocket_ohos.cpp
#include "td/net/TcpSocket.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ohos_errno.h>
#include <ohos_socket.h>

namespace td {
class TcpSocketImpl : public TcpSocket {
public:
    Result<int32> connect(SocketFd fd, const SockAddr &addr, 
                         const IPAddress &ip_address) override {
        // HarmonyOS网络连接实现
        struct sockaddr_in sa;
        sa.sin_family = AF_INET;
        sa.sin_port = htons(addr.port());
        inet_pton(AF_INET, ip_address.get_ip_str().c_str(), 
                 &sa.sin_addr);
        
        int ret = ::connect(fd.get_native_fd(), 
                           (struct sockaddr*)&sa, sizeof(sa));
        if (ret < 0 && errno != EINPROGRESS) {
            return Status::Error("Connect failed");
        }
        return 0;
    }
};
}
```

### 3. **构建脚本配置**
创建`harmonyos_build.sh`：

```bash
#!/bin/bash
# 设置HarmonyOS环境变量
export OHOS_SDK_HOME=/path/to/harmonyos/sdk
export OHOS_NDK_HOME=$OHOS_SDK_HOME/native
export PATH=$OHOS_NDK_HOME/llvm/bin:$PATH

# 创建构建目录
mkdir -p build_harmonyos
cd build_harmonyos

# 配置CMake
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$OHOS_NDK_HOME/build/cmake/ohos.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DTD_ENABLE_JNI=OFF \
    -DTD_ENABLE_OPENSSL=ON \
    -DOPENSSL_ROOT_DIR=$OHOS_SDK_HOME/thirdparty/openssl \
    -DHARMONYOS=ON \
    -DCMAKE_CXX_FLAGS="-DOHOS -Wno-deprecated-declarations"

# 编译tdactor
make tdactor -j8

# 生成HarmonyOS动态库
$OHOS_NDK_HOME/llvm/bin/clang++ \
    -shared \
    -o libtdactor.z.so \
    libtdactor.a \
    -lz \
    -lssl \
    -lcrypto \
    -lohos \
    --sysroot=$OHOS_SDK_HOME/native/sysroot
```

## 四、配置文件

### 1. **td/tdactor/config.h**
```cpp
#ifndef TD_TDACTOR_CONFIG_H_HARMONYOS
#define TD_TDACTOR_CONFIG_H_HARMONYOS

// HarmonyOS特定配置
#define TD_HARMONYOS 1
#define TD_THREAD_UNSUPPORTED 0
#define TD_EVENTFD_UNSUPPORTED 1  // HarmonyOS不支持eventfd
#define TD_POLL_HARMONYOS 1

// 线程配置
#define TD_HAVE_THREAD_LOCAL 1
#define TD_HAVE_ATOMIC 1

// 内存分配
#define TD_USE_ALLOCATOR 1

#endif
```

### 2. **构建配置**
创建`harmonyos/CMakeLists.txt`：

```cmake
# HarmonyOS特定源文件
set(HARMONYOS_SOURCES
    harmonyos/thread.cpp
    harmonyos/net/TcpSocket_ohos.cpp
    harmonyos/actor/ConcurrentScheduler_ohos.cpp
    harmonyos/utils/Time_ohos.cpp
)

# 添加到tdactor库
target_sources(tdactor PRIVATE ${HARMONYOS_SOURCES})

# HarmonyOS特定包含目录
target_include_directories(tdactor PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/harmonyos/include
    ${OHOS_SDK_HOME}/native/sysroot/usr/include
)

# 链接HarmonyOS库
target_link_libraries(tdactor PRIVATE
    -lohos
    -lhilog
    -lhilogbase
    -lbundle
)
```

## 五、线程和同步原语适配

### 1. **线程实现**
```cpp
// harmonyos/thread.cpp
#include "td/utils/thread.h"
#include <ohos_thread.h>

namespace td {

class ThreadImpl {
public:
    static void *run(void *arg) {
        auto func = reinterpret_cast<std::function<void()>*>(arg);
        (*func)();
        delete func;
        return nullptr;
    }
};

Thread::Thread(std::function<void()> function, string name) {
    osThreadAttr_t attr = {
        .name = name.c_str(),
        .attr_bits = 0U,
        .cb_mem = nullptr,
        .cb_size = 0U,
        .stack_mem = nullptr,
        .stack_size = TD_THREAD_STACK_SIZE,
        .priority = osPriorityNormal,
    };
    
    auto func_ptr = new std::function<void()>(std::move(function));
    thread_ = osThreadNew(&ThreadImpl::run, func_ptr, &attr);
}

void Thread::join() {
    if (thread_ != nullptr) {
        osThreadJoin(thread_);
        thread_ = nullptr;
    }
}
}
```

### 2. **Mutex适配**
```cpp
// harmonyos/mutex.cpp
#include "td/utils/Mutex.h"
#include <mutex>
#include <ohos_mutex.h>

namespace td {

class HarmonyMutex : public Mutex {
private:
    osMutexId_t mutex_;
    
public:
    HarmonyMutex() {
        osMutexAttr_t attr = {
            .name = "td_mutex",
            .attr_bits = 0U,
            .cb_mem = nullptr,
            .cb_size = 0U,
        };
        mutex_ = osMutexNew(&attr);
    }
    
    ~HarmonyMutex() {
        osMutexDelete(mutex_);
    }
    
    void lock() override {
        osMutexAcquire(mutex_, osWaitForever);
    }
    
    void unlock() override {
        osMutexRelease(mutex_);
    }
};
}
```

## 六、在HarmonyOS应用中使用

### 1. **Native C++配置**
在`entry/src/main/cpp/`目录下创建CMakeLists.txt：

```cmake
cmake_minimum_required(VERSION 3.10)
project(tdactor_demo)

# 添加TDLib
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../../../td build_harmonyos)

add_library(tdactor_demo SHARED
    tdactor_wrapper.cpp
)

target_link_libraries(tdactor_demo PUBLIC
    tdactor
    hilog_ndk.z
    ability.z
)
```

### 2. **Java/JNI包装**
```java
// ActorManager.java
package com.example.tdactor;

import ohos.rpc.IRemoteObject;
import ohos.app.Context;

public class ActorManager {
    static {
        System.loadLibrary("tdactor_demo");
    }
    
    private native long createActorSystem();
    private native void sendMessage(long ptr, String message);
    
    private long nativePtr;
    
    public void initialize(Context context) {
        nativePtr = createActorSystem();
    }
    
    public void sendTelegramMessage(String message) {
        sendMessage(nativePtr, message);
    }
}
```

## 七、常见问题解决

### 1. **编译错误**
```
# 1. 找不到OpenSSL
解决方案：使用HarmonyOS预编译的OpenSSL或自行交叉编译

# 2. 线程API不兼容
解决方案：实现td/utils/thread.h的HarmonyOS版本

# 3. 网络API差异
解决方案：适配td/net/下的网络实现
```

### 2. **性能优化建议**
- 使用HarmonyOS的轻量级线程池
- 适配HarmonyOS内存管理API
- 使用HiLog进行日志输出
- 优化Actor调度策略

## 八、测试验证

### 1. **单元测试适配**
```cpp
// harmonyos/test/test_actor.cpp
#include "td/actor/actor.h"
#include <gtest/gtest.h>
#include <hilog/log.h>

TEST(ActorTest, BasicFunction) {
    class TestActor : public td::Actor {
    public:
        void start_up() override {
            LOGI("TestActor started");
            td::send_closure(actor_id(this), &TestActor::test);
        }
        
        void test() {
            LOGI("TestActor received message");
        }
    };
    
    td::ConcurrentScheduler scheduler(4);
    scheduler.create_actor<TestActor>("TestActor");
    scheduler.start();
}
```

这个适配过程需要根据HarmonyOS的具体版本和TDLib的版本进行调整。建议从简单的Actor功能开始，逐步完善网络、存储等模块的适配。

十九.tdlib core for HarmonyOS

在 HarmonyOS（特别是 HarmonyOS NEXT）上编译 TDLib core，本质上是为这个跨平台 C++ 库进行 **目标平台适配**。由于 TDLib 官方未提供 HarmonyOS 的编译脚本，你需要使用 HarmonyOS NDK 提供的工具链，并可能需要对依赖库进行交叉编译。以下是详细步骤与关键要点。

---

## 📦 前提条件
| 项目 | 说明 |
|------|------|
| **HarmonyOS NEXT NDK** | 下载并解压 HarmonyOS NEXT 的 **Command Line Tools**，其中包含 `native` 目录（编译器、cmake、toolchain 等）。 |
| **TDLib 源码** | 从官方仓库克隆：<br> `git clone https://github.com/tdlib/td.git` |
| **依赖库** | TDLib 依赖 **OpenSSL**、**zlib**，可能需要先为 HarmonyOS 编译。 |
| **开发环境** | 建议使用 **Linux**（或 Windows WSL2），确保已安装 `cmake`、`ninja`、`git` 等基础工具。 |

---

## 🔧 步骤一：准备 HarmonyOS 工具链
1. 设置环境变量，指向 NDK 的 `native` 目录：
   ```bash
   export OHOS_SDK=/path/to/ohos-sdk/linux  # 根据实际路径调整
   export CC="$OHOS_SDK/native/llvm/bin/clang --target=arm-linux-ohos"
   export CXX="$OHOS_SDK/native/llvm/bin/clang++ --target=arm-linux-ohos"
   export LD="$OHOS_SDK/native/llvm/bin/ld.lld"
   export AR="$OHOS_SDK/native/llvm/bin/llvm-ar"
   export STRIP="$OHOS_SDK/native/llvm/bin/llvm-strip"
   export RANLIB="$OHOS_SDK/native/llvm/bin/llvm-ranlib"
   export CFLAGS="-fPIC -D__MUSL__=1"
   export CXXFLAGS="-fPIC -D__MUSL__=1"
   ```
2. 确认工具链文件存在：  
   `$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake`

> 以上环境变量设置参考了 HarmonyOS NEXT 三方库适配指导[reference:0]。

---

## 📚 步骤二：编译依赖库（OpenSSL、zlib）
TDLib 需要 OpenSSL 和 zlib。你需要先为 HarmonyOS 交叉编译它们。

### 以 OpenSSL 为例
1. 下载 OpenSSL 源码。
2. 进入源码目录，配置时指定 `--cross-compile-prefix` 和使用 OHOS 的 clang：
   ```bash
   ./Configure linux-armv4 \
       --cross-compile-prefix=arm-linux-ohos- \
       --prefix=$PWD/install \
       no-shared
   ```
3. 执行 `make && make install`，编译后的库和头文件会出现在 `install` 目录。

### 以 zlib 为例
1. 下载 zlib 源码。
2. 使用 CMake 配置，指定 toolchain 文件：
   ```bash
   cmake -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake \
         -DOHOS_ARCH=arm64-v8a \
         -DCMAKE_INSTALL_PREFIX=$PWD/install \
         -B build .
   ```
3. 执行 `cmake --build build --target install`。

> 注意：如果依赖库已提供 HarmonyOS 预编译包，可直接使用，避免自行编译。

---

## ⚙️ 步骤三：编译 TDLib
1. 进入 TDLib 源码目录：
   ```bash
   cd td
   mkdir build_hos
   cd build_hos
   ```
2. 配置 CMake，指向 HarmonyOS 工具链和依赖库的安装路径：
   ```bash
   cmake -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake \
         -DOHOS_ARCH=arm64-v8a \
         -DOHOS_STL=c++_static \
         -DCMAKE_BUILD_TYPE=Release \
         -DOPENSSL_ROOT_DIR=/path/to/openssl/install \
         -DZLIB_ROOT=/path/to/zlib/install \
         -DCMAKE_INSTALL_PREFIX=$PWD/install \
         ..
   ```
   - **`OHOS_ARCH`**：根据目标设备选择 `arm64-v8a`（常用）或 `armeabi-v7a`。
   - **`OHOS_STL`**：选择 `c++_static`（静态链接 C++ 库）或 `c++_shared`。
   - **`OPENSSL_ROOT_DIR`**、**`ZLIB_ROOT`**：指向之前编译的依赖库安装路径。
3. 执行编译：
   ```bash
   cmake --build . --target install -j$(nproc)
   ```
   编译成功后，会在 `install` 目录下得到 `libtdcore.so`、`libtdclient.so` 等库文件以及头文件。

> 上述 CMake 参数参考了 HarmonyOS NEXT 的编译指导[reference:1]以及 TDLib 常规编译方法[reference:2]。

---

## 📲 步骤四：集成到 HarmonyOS 项目
1. 在 DevEco Studio 中创建一个 **Native C++** 项目（或 NDK 模块）。
2. 将编译得到的 `libtdcore.so` 等库文件复制到项目的 `src/main/cpp/libs/arm64-v8a/` 目录。
3. 将 TDLib 的头文件（`install/include/`）复制到 `src/main/cpp/include/`。
4. 在项目的 `CMakeLists.txt` 中添加对 TDLib 的链接：
   ```cmake
   add_library(tdcore SHARED IMPORTED)
   set_target_properties(tdcore PROPERTIES
       IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH}/libtdcore.so
   )
   include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
   target_link_libraries(your_native_lib tdcore)
   ```
5. 在 `build-profile.json5` 中确保 `abiFilters` 包含 `arm64-v8a`。

> 更详细的 NDK 模块集成方法可参考 HarmonyOS NEXT 编译三方库的教程[reference:3]。

---

## 💡 注意事项
1. **架构匹配**：`OHOS_ARCH` 必须与目标设备的 ABI 一致（如 `arm64-v8a`）。
2. **内存需求**：TDLib 编译需要较多内存（建议 ≥ 4GB），否则 `make` 可能卡住[reference:4]。
3. **依赖版本**：尽量使用较新的 OpenSSL（如 1.1.1 或 3.x），以避免兼容性问题。
4. **调试版本**：开发阶段可使用 `-DCMAKE_BUILD_TYPE=Debug` 方便排查问题。
5. **静态链接**：若希望减少依赖，可尝试 `-DOHOS_STL=c++_static` 静态链接 C++ 库。

---

## 🔗 参考资源
| 资源 | 说明 |
|------|------|
| [开源三方库HarmonyOS NEXT适配指导](https://my.oschina.net/u/9174168/blog/18444120) | 详细的 HarmonyOS NEXT 三方库编译流程[reference:5] |
| [HarmonyOS NEXT系列之编译三方C/C++库](https://blog.csdn.net/qq_42896653/article/details/150148305) | 实战教程，包含 CMake 配置、工具链使用等[reference:6] |
| [tdLib编译使用（CSDN）](https://blog.csdn.net/robinfoxnan/article/details/127294645) | TDLib 在 Linux 上的常规编译方法[reference:7] |
| [TDLib 官方 GitHub](https://github.com/tdlib/td) | 源码和官方构建说明 |

> 以上步骤涵盖了从环境准备、依赖编译、TDLib 编译到项目集成的完整流程。实际操作中可能需根据具体 SDK 版本和设备架构进行微调。

！！！补充：

RE2 编译时需要依赖 Abseil 库
由于 re2 依赖于 Abseil 库，需要在编译 re2 之前先编译 Abseil。以下是完整的解决方案：

## 1. 编译 Abseil 库

### 1.1 获取 Abseil 源码
```bash
git clone https://github.com/abseil/abseil-cpp.git
cd abseil-cpp
```

### 1.2 设置 HarmonyOS 交叉编译环境
```bash
export OHOS_SDK=/home/yourname/OH_SDK/ohos-sdk/linux
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=arm-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=arm-linux-ohos"
export AR="${OHOS_SDK}/native/llvm/bin/llvm-ar"
export RANLIB="${OHOS_SDK}/native/llvm/bin/llvm-ranlib"
export STRIP="${OHOS_SDK}/native/llvm/bin/llvm-strip"
export SYSROOT="${OHOS_SDK}/native/sysroot"
export CFLAGS="--sysroot=${SYSROOT} -fPIC -D__MUSL__=1"
export CXXFLAGS="--sysroot=${SYSROOT} -fPIC -D__MUSL__=1 -std=c++17"
export LDFLAGS="--sysroot=${SYSROOT}"
```

### 1.3 使用 CMake 编译 Abseil
```bash
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_STL=c++_static \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DABSL_BUILD_TESTING=OFF \
  -DCMAKE_INSTALL_PREFIX=/path/to/abseil/install
```

### 1.4 编译并安装
```bash
make -j$(nproc)
make install
```

## 2. 编译 re2 并链接 Abseil

### 2.1 获取 re2 源码
```bash
git clone https://github.com/google/re2.git
cd re2
```

### 2.2 设置 Abseil 路径
```bash
export ABSL_DIR=/path/to/abseil/install
export CXXFLAGS="${CXXFLAGS} -I${ABSL_DIR}/include"
export LDFLAGS="${LDFLAGS} -L${ABSL_DIR}/lib"
```

### 2.3 编译 re2
```bash
make CXX="${CXX}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="-labsl_strings -labsl_throw_delegate -labsl_bad_optional_access -labsl_bad_variant_access -labsl_base -labsl_raw_logging_internal -labsl_log_severity -labsl_civil_time -labsl_time_zone -labsl_int128 -labsl_strings_internal -labsl_time -labsl_spinlock_wait"
```

### 2.4 验证链接
```bash
# 检查是否包含 Abseil 符号
${OHOS_SDK}/native/llvm/bin/llvm-nm libre2.a | grep absl
```

## 3. 完整自动化脚本

创建 `build_re2_harmonyos.sh`：
```bash
#!/bin/bash

set -e

OHOS_SDK="/home/yourname/OH_SDK/ohos-sdk/linux"
ARCH="arm64-v8a"
INSTALL_DIR="/path/to/install/dir"

# 设置工具链
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=${ARCH}-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=${ARCH}-linux-ohos"
export AR="${OHOS_SDK}/native/llvm/bin/llvm-ar"
export RANLIB="${OHOS_SDK}/native/llvm/bin/llvm-ranlib"
export SYSROOT="${OHOS_SDK}/native/sysroot"

# 1. 编译 Abseil
echo "Building Abseil..."
cd abseil-cpp
mkdir -p build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake \
  -DOHOS_ARCH=${ARCH} \
  -DOHOS_STL=c++_static \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/abseil \
  -DBUILD_SHARED_LIBS=OFF \
  -DABSL_BUILD_TESTING=OFF \
  -DABSL_PROPAGATE_CXX_STD=ON

make -j$(nproc)
make install
cd ../..

# 2. 编译 re2
echo "Building re2..."
cd re2
make clean

# 设置包含路径和库路径
ABSL_INC="${INSTALL_DIR}/abseil/include"
ABSL_LIB="${INSTALL_DIR}/abseil/lib"

make \
  CXX="${CXX}" \
  CXXFLAGS="--sysroot=${SYSROOT} -fPIC -D__MUSL__=1 -std=c++17 -I${ABSL_INC}" \
  LDFLAGS="--sysroot=${SYSROOT} -L${ABSL_LIB}" \
  LIBS="-labsl_strings -labsl_throw_delegate -labsl_bad_optional_access -labsl_bad_variant_access -labsl_base -labsl_raw_logging_internal -labsl_log_severity -labsl_civil_time -labsl_time_zone -labsl_int128 -labsl_strings_internal -labsl_time -labsl_spinlock_wait"

# 3. 安装 re2
echo "Installing re2..."
cp libre2.a ${INSTALL_DIR}/lib/
cp -r re2/*.h ${INSTALL_DIR}/include/re2/
echo "Build complete!"
```

## 4. 常见问题解决

### 4.1 找不到特定的 Abseil 库
如果链接时提示缺少某个 Abseil 库，可以查看已安装的库：
```bash
ls ${INSTALL_DIR}/abseil/lib/*.a
```

根据错误信息添加对应的库，例如：
- `undefined reference to 'absl::lts_20240116::...'` → 添加 `-labsl_[库名]`

### 4.2 静态库链接顺序问题
Abseil 库之间有依赖关系，需要确保正确的链接顺序。如果遇到未定义引用，可以尝试：
```bash
# 将所有 Abseil 库链接
find ${INSTALL_DIR}/abseil/lib -name "*.a" | xargs -I {} basename {} .a | sed 's/^/-l/' | tr '\n' ' '
```

### 4.3 C++ 标准版本不匹配
确保所有组件使用相同的 C++ 标准：
```bash
export CXXFLAGS="${CXXFLAGS} -std=c++17"  # 或 -std=c++20
```

## 5. 在 TDLib 中使用

编译 TDLib 时指定路径：
```bash
cd td
mkdir build && cd build
cmake .. \
  -DRE2_INCLUDE_DIR=${INSTALL_DIR}/include \
  -DRE2_LIBRARY=${INSTALL_DIR}/lib/libre2.a \
  -Dabsl_DIR=${INSTALL_DIR}/abseil/lib/cmake/absl \
  -DCMAKE_TOOLCHAIN_FILE=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake \
  -DOHOS_ARCH=${ARCH} \
  -DOHOS_STL=c++_static \
  -DCMAKE_CXX_FLAGS="-I${INSTALL_DIR}/abseil/include"
```

## 6. 备选方案：使用 vcpkg

如果使用 vcpkg 包管理器，可以简化流程：

```bash
# 安装 vcpkg for HarmonyOS
git clone https://github.com/microsoft/vcpkg
./bootstrap-vcpkg.sh

# 创建 HarmonyOS 工具链文件
cat > arm64-harmonyos.cmake << EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER "${OHOS_SDK}/native/llvm/bin/clang")
set(CMAKE_CXX_COMPILER "${OHOS_SDK}/native/llvm/bin/clang++")
set(CMAKE_C_FLAGS "--target=arm-linux-ohos --sysroot=${OHOS_SDK}/native/sysroot")
set(CMAKE_CXX_FLAGS "--target=arm-linux-ohos --sysroot=${OHOS_SDK}/native/sysroot")
EOF

# 安装 re2（会自动处理 Abseil 依赖）
./vcpkg install re2:arm64-harmonyos --triplet arm64-harmonyos
```

按照以上步骤，你应该能够成功编译包含 Abseil 依赖的 re2 库，并解决头文件找不到的问题。