# AOSP Android15 Bin 文件分析汇总

本文档是 AOSP Android15 所有 bin 文件分析的汇总索引。

---

## 分析范围

本分析覆盖了 `AOSP_ANDROID15_BIN_SOURCE_INDEX.md` 中列出的所有可执行文件，共 **5 份分析文档**：

| 文档 | 内容 | 文件数 |
|------|------|--------|
| [AOSP_ANDROID15_BIN_ANALYSIS_01_FRAMEWORK_SHELL_COMMANDS.md](AOSP_ANDROID15_BIN_ANALYSIS_01_FRAMEWORK_SHELL_COMMANDS.md) | GSI Framework Shell Commands | ~30 |
| [AOSP_ANDROID15_BIN_ANALYSIS_02_NATIVE_EXECUTABLES.md](AOSP_ANDROID15_BIN_ANALYSIS_02_NATIVE_EXECUTABLES.md) | GSI Native & Rust Executables | ~40 |
| [AOSP_ANDROID15_BIN_ANALYSIS_03_APEX_BINARIES.md](AOSP_ANDROID15_BIN_ANALYSIS_03_APEX_BINARIES.md) | APEX Binaries | ~20 |
| [AOSP_ANDROID15_BIN_ANALYSIS_04_TOYBOX_TOOLBOX_USERDEBUG.md](AOSP_ANDROID15_BIN_ANALYSIS_04_TOYBOX_TOOLBOX_USERDEBUG.md) | OTA Helpers, Toybox/Toolbox, userdebug/eng | ~150+ |
| [AOSP_ANDROID15_BIN_ANALYSIS_05_EMULATOR_PIXEL_LINARO.md](AOSP_ANDROID15_BIN_ANALYSIS_05_EMULATOR_PIXEL_LINARO.md) | 模拟器组件、Pixel 特有组件、Linaro 设备组件 | ~50 |

---

## 系统架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│                      Android 系统架构                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Framework   │  │   System     │  │   APEX       │          │
│  │  Shell Cmds  │  │   Services   │  │   Modules    │          │
│  │              │  │              │  │              │          │
│  │ am, pm, svc  │  │ init, vold   │  │ art, adbd    │          │
│  │ wm, input    │  │ surfaceflinger│  │ mediacodec   │          │
│  │ content, sm  │  │ lmkd, logd   │  │ statsd       │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         └─────────────────┼─────────────────┘                   │
│                           │                                     │
│                    ┌──────┴───────┐                             │
│                    │  Binder IPC  │                             │
│                    └──────┬───────┘                             │
│                           │                                     │
│  ┌────────────────────────┼────────────────────────────┐       │
│  │                        │                            │       │
│  │  ┌─────────────────────┴──────────────────────┐    │       │
│  │  │            Linux Kernel                     │    │       │
│  │  │  Binder, Netlink, BPF, VFS, DM, ION        │    │       │
│  │  └────────────────────────────────────────────┘    │       │
│  └────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 核心守护进程关系图

```
init (PID 1)
  │
  ├── zygote → app_process → Java 应用
  │
  ├── system_server
  │     ├── ActivityManagerService (am)
  │     ├── PackageManagerService (pm)
  │     ├── WindowManagerService (wm)
  │     ├── InputManagerService (input)
  │     ├── PowerManagerService
  │     ├── ...
  │
  ├── surfaceflinger → 图形合成
  │
  ├── vold → 存储管理
  │     └── Netlink → 内核块设备事件
  │
  ├── lmkd → 内存管理
  │     └── PSI → 内核压力监控
  │
  ├── logd → 日志管理
  │
  ├── servicemanager → 服务注册
  │
  ├── gatekeeperd → 用户认证
  │     └── TEE → 可信执行环境
  │
  ├── apexd → APEX 模块管理
  │     └── dm-verity → 完整性验证
  │
  ├── bpfloader → BPF 程序加载
  │     └── BPF 系统调用 → eBPF
  │
  ├── netd → 网络管理
  │     └── Netfilter → 防火墙
  │
  ├── debuggerd → 崩溃处理
  │     └── ptrace → 进程追踪
  │
  ├── tombstoned → Tombstone 管理
  │
  ├── keystore2 → 密钥存储
  │     └── TEE → 可信执行环境
  │
  ├── llkd → 活锁检测
  │
  ├── watchdogd → 硬件看门狗
  │
  ├── bootstat → 启动统计
  │
  └── 更多...
```

---

## 与 Linux 内核强相关的组件

| 组件 | 内核特性 | 说明 |
|------|----------|------|
| `bpfloader` | BPF 系统调用, kprobe, tracepoint, BPF Maps | eBPF 程序加载 |
| `lmkd` | PSI (Pressure Stall Information), eBPF | 内存压力监控 |
| `vold` | Netlink, uevent, dm-crypt, loop device | 存储管理 |
| `apexd` | dm-linear, dm-verity, inotify | APEX 模块管理 |
| `surfaceflinger` | dma-buf, sync_file, ION/DMA-BUF | 图形合成 |
| `servicemanager` | Binder 驱动 | IPC 通信 |
| `debuggerd` | ptrace, signal | 进程追踪 |
| `gatekeeperd` | TEE, TrustZone | 安全认证 |
| `llkd` | 调度器监控 | 活锁检测 |
| `watchdogd` | watchdog 驱动 | 硬件看门狗 |
| `netd` | Netfilter, iptables, TC | 网络管理 |
| `snapuserd` | dm-snapshot, dm-user | 快照管理 |
| `logd` | socket, SELinux | 日志管理 |
| `init` | signalfd, eventfd, epoll, inotify | 系统初始化 |
| `clatd` | TUN/TAP, AF_PACKET, BPF | IPv4/IPv6 转换 |
| `mac80211_create_radios` | mac80211_hwsim, netlink | 虚拟 WiFi |
| `keystore2` | TEE, Keymint | 密钥存储 |

---

## 关键 Android 机制

| 机制 | 涉及组件 | 说明 |
|------|----------|------|
| **Binder IPC** | 所有系统服务 | Android 进程间通信 |
| **APEX** | apexd, art, adbd | 系统组件模块化 |
| **SELinux** | init, installd, vold | 强制访问控制 |
| **AVB** | apexd, init | Android Verified Boot |
| **FBE** | vold | File-Based Encryption |
| **PSI** | lmkd | Pressure Stall Information |
| **eBPF** | bpfloader, lmkd, netd | 扩展 BPF |
| **TEE** | gatekeeperd, keystore2 | 可信执行环境 |
| **Device Mapper** | apexd, vold, snapuserd | 设备映射 |
| **HIDL/AIDL** | 所有 HAL 服务 | 硬件抽象层接口 |
| **init.rc** | init | 初始化脚本 |
| **app_process** | zygote, Java 服务 | Java 进程启动 |
| **ART** | dalvikvm, dex2oat | Android 运行时 |

---

## 按功能分类索引

### 进程管理
- `am` — Activity/进程控制
- `lmkd` — 低内存杀手
- `llkd` — 活锁检测
- `init` — 进程初始化

### 包管理
- `pm` — 包管理
- `installd` — 安装守护进程
- `apexd` — APEX 模块管理
- `artd` — ART 守护进程

### 存储管理
- `vold` — 存储卷管理
- `sm` — 存储管理命令
- `snapuserd` — 快照管理

### 图形和显示
- `surfaceflinger` — 图形合成
- `wm` — 窗口管理
- `screencap` — 屏幕截图
- `screenrecord` — 屏幕录制

### 网络
- `netd` — 网络守护进程
- `clatd` — IPv4/IPv6 转换
- `ndc` — 网络控制

### 安全
- `gatekeeperd` — 门禁
- `keystore2` — 密钥存储
- `credstore` — 凭证存储
- `odsign` — 设备端签名

### 调试和日志
- `logd` / `logcat` — 日志
- `debuggerd` / `tombstoned` — 崩溃处理
- `bugreport` / `bugreportz` — Bugreport
- `dumpsys` / `dumpstate` — 状态转储
- `strace` — 系统调用追踪
- `perfetto` / `traced` — 性能追踪

### 媒体
- `drmserver` — DRM
- `mediaextractor` — 媒体解析
- `cameraserver` — 相机服务
- `audioserver` — 音频服务

### 虚拟化
- `crosvm` — 虚拟机监视器
- `virtualizationservice` — 虚拟化服务
- `virtmgr` — 虚拟机管理

---

## 文档使用指南

1. **查找特定命令**: 使用本索引定位到对应的分析文档
2. **理解系统交互**: 参考"核心守护进程关系图"理解组件间关系
3. **内核特性**: 参考"与 Linux 内核强相关的组件"了解内核交互
4. **开发调试**: 参考"按功能分类索引"找到相关工具

---

## 分析方法论

本分析基于以下步骤：

1. **源码阅读**: 读取每个二进制的主源文件
2. **架构分析**: 分析程序的入口、主循环、事件处理
3. **交互分析**: 分析与其他组件的交互方式（Binder、Netlink、ioctl 等）
4. **内核关联**: 识别与 Linux 内核特性的关联
5. **功能总结**: 归纳核心功能和子功能

---

*分析完成于 2026-07-24*
