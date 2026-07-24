# AOSP Android15 APEX Binaries 分析

本文档分析 AOSP Android15 中 APEX (Android Pony EXpress) 模块包含的可执行文件。APEX 是 Android 10 引入的系统组件模块化机制，允许系统组件独立更新。

---

## APEX 概述

APEX 是一种只读的系统组件镜像格式，包含系统库、二进制文件、配置文件等。APEX 通过 `apexd` 守护进程管理，挂载到 `/apex/<name>@<version>`。

### 主要 APEX 模块

| APEX | 内容 | 说明 |
|------|------|------|
| `com.android.art` | ART 虚拟机、dex2oat、profman 等 | Android Runtime |
| `com.android.adbd` | adbd | ADB 守护进程 |
| `com.android.runtime` | linker, crash_dump | 运行时链接器 |
| `com.android.media` | mediatranscoding, mediaswcodec | 媒体编解码器 |
| `com.android.media.swcodec` | 软件编解码器 | 媒体软件编解码 |
| `com.android.tethering` | clatd, netbpfload, ot-daemon | 网络共享相关 |
| `com.android.conscrypt` | boringssl_self_test | 密码学库自测 |
| `com.android.os.statsd` | statsd | 统计守护进程 |
| `com.android.sdkext` | derive_classpath, derive_sdk | SDK 扩展 |
| `com.android.virt` | crosvm, virtualizationservice | 虚拟化 (AVF) |

---

## 1. ART (Android Runtime) APEX (`com.android.art`)

ART APEX 包含 Android 运行时环境的核心组件。

### 1.1 `dalvikvm` / `dalvikvm32` / `dalvikvm64`

**源码位置**: `art/dalvikvm/dalvikvm.cc`

**功能**: 启动 Dalvik 虚拟机并执行 Java 方法。

**原理**:
```
dalvikvm [options] class [args]
  │
  ├── 初始化 JNI 环境
  ├── 创建 JavaVM
  ├── 查找并加载指定类
  ├── 调用 main(String[]) 方法
  └── 等待执行完成
```

**用途**: 命令行启动 Java 程序（在 Android 上通过 app_process 间接使用）。

### 1.2 `dex2oat` / `dex2oat32` / `dex2oat64`

**源码位置**: `art/dex2oat/`

**功能**: DEX 到 OAT 的编译工具，将 DEX 字节码编译为本地机器码（AOT 编译）。

**原理**:
```
dex2oat [options] --dex-file=... --oat-file=...
  │
  ├── 读取 DEX 文件
  ├── 解析 DEX 字节码
  ├── 执行编译优化
  │     ├── 内联优化
  │     ├── 常量折叠
  │     ├── 死代码消除
  │     └── 更多...
  ├── 生成 OAT 文件（包含本地机器码）
  └── 生成 VDEX 文件（包含验证信息）
```

**编译模式**:
- `speed`: 最高性能编译
- `verify`: 仅验证
- `everything`: 编译所有
- `profile`: 基于 profile 的编译

### 1.3 `artd` — ART 守护进程

**源码位置**: `art/artd/artd_main.cc`

**功能**: ART 守护进程，管理 ART 相关的后台操作。

**原理**:
```
artd [--pre-reboot]
  │
  ├── 初始化 Binder 服务
  ├── 注册 ART 服务
  │     ├── 管理 dexopt 操作
  │     ├── 处理 Pre-reboot 操作
  │     └── 管理 ART 文件
  └── 处理 Binder 请求
```

### 1.4 `odrefresh` — OD 刷新

**功能**: 管理 OAT/DEX/VEX 文件的刷新和清理。

**原理**:
- 检查已编译文件是否需要更新
- 触发重新编译
- 清理过期的编译产物

### 1.5 `profman` — Profile 管理器

**功能**: 管理 ART 的 profile 文件。

**子命令**:
- `profman --profile-file=...`: 处理 profile 文件
- `profman --dex-location=...`: 指定 DEX 位置
- `profman --dump-only`: 仅 dump 信息

### 1.6 `dexdump` — DEX 转储

**功能**: 解析和显示 DEX 文件的内容。

### 1.7 `dexlist` — DEX 列表

**功能**: 列出 DEX 文件中引用的方法。

### 1.8 `dexoptanalyzer` — Dexopt 分析器

**功能**: 分析 dexopt 是否需要重新编译。

### 1.9 `dexopt_chroot_setup` — Dexopt Chroot 设置

**功能**: 在 chroot 环境中设置 dexopt。

### 1.10 `oatdump` — OAT 转储

**功能**: 解析和显示 OAT 文件的内容。

### 1.11 ART Debug APEX 附加

| 工具 | 功能 |
|------|------|
| `dex2oatd` | dex2oat 的调试版本 |
| `dexanalyze` | DEX 分析工具 |
| `dexoptanalyzerd` | dexoptanalyzer 的调试版本 |
| `imgdiag` / `imgdiagd` | 镜像诊断工具 |
| `oatdumpd` | oatdump 的调试版本 |
| `profmand` | profman 的调试版本 |

---

## 2. `adbd` — ADB 守护进程

**源码位置**: `packages/modules/adb/daemon/main.cpp` (APEX: `com.android.adbd`)

**功能**: ADB (Android Debug Bridge) 守护进程，处理来自主机的 ADB 命令。

**原理**:
```
adbd
  │
  ├── 初始化
  │     ├── 检查 ro.secure 和 ro.debuggable
  │     ├── 决定是否降权（从 root 到 shell）
  │     └── 初始化 USB 和网络连接
  │
  ├── 主循环
  │     ├── 监听 USB 连接
  │     ├── 监听网络连接（adb connect）
  │     └── 处理来自主机的命令
  │
  └── 服务
        ├── file_sync_service: 文件同步（push/pull）
        ├── shell_service: shell 命令执行
        ├── framebuffer_service: 屏幕截图
        ├── jdwp_service: JDWP 调试
        ├── restart_service: 重启服务
        └── adb_wifi: WiFi ADB
```

**权限模型**:
- `ro.secure=1`: 默认降权到 shell 用户
- `ro.debuggable=1`: 可以通过 `adb root` 恢复 root 权限

---

## 3. Runtime APEX (`com.android.runtime`)

### 3.1 `linker` / `linker64` — 动态链接器

**功能**: Android 的动态链接器，负责加载和链接共享库。

**原理**:
- 解析 ELF 文件
- 加载共享库
- 重定位符号
- 处理 `LD_PRELOAD` 等环境变量

### 3.2 `crash_dump32` / `crash_dump64` — 崩溃转储

**功能**: 生成进程崩溃时的内存转储。

---

## 4. Media APEX

### 4.1 `mediatranscoding` — 媒体转码

**APEX**: `com.android.media`

**功能**: 媒体文件转码服务，支持格式转换。

### 4.2 `mediaswcodec` — 软件编解码器

**APEX**: `com.android.media.swcodec`

**功能**: 软件实现的媒体编解码器。

---

## 5. Tethering APEX (`com.android.tethering`)

### 5.1 `clatd` — CLAT 守护进程

**源码位置**: `packages/modules/Connectivity/clatd/clatd.c`

**功能**: CLAT (Customer-side Translator) 守护进程，实现 IPv4/IPv6 转换。

**原理**:
```
clatd
  │
  ├── 创建 TUN 接口
  ├── 创建 AF_PACKET socket
  │
  ├── 主循环
  │     ├── 从 AF_PACKET 读取 IPv6 包
  │     ├── 执行 IPv6→IPv4 转换
  │     │     ├── 修改 IP 头
  │     │     └── 重新计算校验和
  │     ├── 写入 TUN 接口
  │     │
  │     ├── 从 TUN 读取 IPv4 包
  │     ├── 执行 IPv4→IPv6 转换
  │     └── 写入 AF_PACKET socket
  │
  └── 使用 BPF 过滤器优化数据包处理
```

**相关内核特性**:
- **TUN/TAP**: 网络设备
- **AF_PACKET**: 原始套接字
- **BPF**: 包过滤器
- **NAT**: 网络地址转换

### 5.2 `netbpfload` — 网络 BPF 加载器

**功能**: 加载网络相关的 BPF 程序。

### 5.3 `ot-daemon` — OpenThread 守护进程

**功能**: OpenThread (IoT 协议) 守护进程。

---

## 6. StatsD APEX (`com.android.os.statsd`)

### `statsd` — 统计守护进程

**功能**: Android 统计守护进程，收集系统指标数据。

**原理**:
```
statsd
  │
  ├── 接收指标数据
  │     ├── 来自应用的 atom 上报
  │     └── 来自系统服务的指标
  │
  ├── 处理指标
  │     ├── 聚合
  │     ├── 条件触发
  │     └── 异常检测
  │
  └── 上报
        ├── 上传到服务器
        └── 持久化存储
```

---

## 7. SdkExtensions APEX (`com.android.sdkext`)

### 7.1 `derive_classpath` — 类路径推导

**功能**: 推导应用的类路径。

**原理**:
- 扫描 APEX 和系统目录
- 生成类路径
- 写入 `/data/misc/apexdata/com.android.sdkext/`

### 7.2 `derive_sdk` — SDK 推导

**功能**: 推导 SDK 相关信息。

---

## 8. Virt APEX (`com.android.virt`) — Android Virtualization Framework

### 8.1 `crosvm` — Chrome OS Virtual Machine Monitor

**功能**: 虚拟机监视器，运行虚拟机。

### 8.2 `virtualizationservice` — 虚拟化服务

**功能**: 管理虚拟机的创建和生命周期。

### 8.3 `virtmgr` / `early_virtmgr` — 虚拟机管理器

**功能**: 虚拟机管理。

### 8.4 `vm` — 虚拟机

**功能**: 虚拟机实例。

### 8.5 `fd_server` — 文件描述符服务器

**功能**: 在虚拟机之间传递文件描述符。

### 8.6 `vfio_handler` / `vmnic` — VFIO 处理

**功能**: VFIO 设备处理，虚拟机网络设备。

---

## 9. 其他 APEX 二进制

### 9.1 `odsign` — 设备端签名

**APEX**: `com.android.sdkext` (或独立)

**功能**: 设备端签名验证。

**原理**:
- 验证 APEX 和 APK 签名
- 使用 Keystore HMAC 密钥
- 上报签名状态

### 9.2 `boringssl_self_test32` / `boringssl_self_test64`

**APEX**: `com.android.conscrypt`

**功能**: BoringSSL 加密库自测。

### 9.3 `linkerconfig` — 链接器配置

**APEX**: `com.android.runtime`

**功能**: 生成 linker 配置，定义命名空间。

---

## 10. APEX 生命周期

```
APEX 文件 (*.apex)
  │
  ├── apexd 验证签名 (AVB)
  │
  ├── 创建 dm-linear 映射
  │
  ├── 设置 dm-verity 保护
  │
  ├── 挂载到 /apex/<name>@<version>
  │
  ├── 更新 linker 配置
  │
  ├── 执行激活脚本
  │
  └── 服务可用
```

---

## 总结

| APEX | 核心二进制 | 功能 |
|------|-----------|------|
| `com.android.art` | dalvikvm, dex2oat, artd, profman | Android 运行时 |
| `com.android.adbd` | adbd | ADB 调试桥 |
| `com.android.runtime` | linker, crash_dump | 运行时链接器 |
| `com.android.media` | mediatranscoding, mediaswcodec | 媒体编解码 |
| `com.android.tethering` | clatd, netbpfload, ot-daemon | 网络共享 |
| `com.android.os.statsd` | statsd | 系统统计 |
| `com.android.sdkext` | derive_classpath, derive_sdk, odsign | SDK 扩展 |
| `com.android.virt` | crosvm, virtualizationservice, vm | 虚拟化 |
| `com.android.conscrypt` | boringssl_self_test | 密码学自测 |
