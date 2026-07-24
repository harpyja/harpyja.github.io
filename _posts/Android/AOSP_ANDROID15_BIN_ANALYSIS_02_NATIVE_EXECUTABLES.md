# AOSP Android15 GSI Native & Rust Executables 分析（上篇）

本文档分析 AOSP Android15 中 system/core、system/vold、system/apex、frameworks/native 等目录下的核心原生守护进程和工具。

---

## 1. `init` — 系统初始化守护进程

**源码位置**: `system/core/init/init.cpp`

### 功能概述

`init` 是 Linux 内核启动后的第一个用户空间进程（PID 1），负责启动和管理整个 Android 系统。

### 架构原理

```
内核启动 → init (PID 1)
              │
              ├── First Stage Init (setup selinux, mount partitions)
              │
              ├── Second Stage Load (parse init.rc, start services)
              │     ├── LoadBootScripts() → ParseConfig("/system/etc/init/hw/init.rc")
              │     ├── PropertyInit() → 初始化属性系统
              │     ├── StartServices() → 启动 zygote, surfaceflinger, etc.
              │     └── MainLoop()
              │           ├── Epoll 等待事件
              │           ├── 处理属性变更 (PropertyChanged)
              │           ├── 处理服务重启 (HandleProcessActions)
              │           ├── 处理关机请求 (HandlePowerctlMessage)
              │           └── 执行 Action Queue 中的命令
              │
              └── 永不退出（系统运行期间持续运行）
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **init.rc 脚本** | 定义服务和动作 | 解析 `.rc` 文件，构建 Service 和 Action 对象 |
| **属性服务** | 系统属性管理 | 通过 `/dev/__properties__` 实现跨进程共享属性 |
| **SELinux** | 安全策略加载 | 加载 `sepolicy`，设置文件上下文 |
| **Service 管理** | 启动/重启/停止服务 | 监控进程状态，超时自动重启 |
| **Action Queue** | 条件触发执行 | 基于属性变化或触发器执行命令 |
| **Epoll 事件循环** | 异步事件处理 | 监听属性变更、子进程信号、控制消息 |

### init.rc 服务示例

```rc
service zygote /system/bin/app_process -Xzygote ...
    class main
    priority -20
    user root
    group root readproc
    onrestart write /sys/android_power/request_state wait
```

### 关键功能

- **Cold Boot**: 冷启动时触发 `on boot` 动作链
- **Property Triggers**: 属性变化触发动作（如 `on property:sys.powerctl=*`）
- **Service Restart**: 监控服务状态，异常退出后自动重启
- **Shutdown/Reboot**: 处理 `sys.powerctl` 属性触发关机/重启
- **APEX 管理**: 加载/卸载 APEX 模块时更新 linker 配置
- **Subcontext**: 支持不同 mount namespace 下的服务隔离

### 相关内核特性

- **进程信号处理**: SIGCHLD 监控子进程退出
- **signalfd**: 异步信号处理
- **eventfd**: 唤醒主线程
- **inotify**: 监控文件变化

---

## 2. `vold` — Volume Daemon（存储卷守护进程）

**源码位置**: `system/vold/main.cpp`

### 功能概述

`vold` 是 Android 存储卷管理守护进程，负责磁盘检测、卷挂载/卸载、加密/解密、文件系统等操作。

### 架构原理

```
vold (main)
  │
  ├── VolumeManager::Instance() → 管理所有卷和磁盘
  │     ├── process_config() → 解析 fstab，创建 DiskSource
  │     ├── addDiskSource() → 添加磁盘源
  │     └── handleBlockDeviceEvent() → 处理块设备热插拔
  │
  ├── NetlinkManager::start() → 监听内核 Netlink 事件
  │     ├── handleUsbEvent() → USB 设备事件
  │     ├── handleBlockEvent() → 块设备事件
  │     └── 发送 uevent 给用户空间
  │
  ├── VoldNativeService::start() → 注册 Binder 服务
  │
  └── coldboot("/sys/block") → 触发冷启动扫描
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **VolumeManager** | 卷管理 | 管理所有存储卷的生命周期 |
| **NetlinkManager** | 网络链接事件 | 监听内核 Netlink 消息获取设备热插拔事件 |
| **Cryptfs** | 文件加密 | FBE (File-Based Encryption) 和 FDE (Full Disk Encryption) |
| **Metadata Encryption** | 元数据加密 | dm-crypt 加密元数据分区 |
| **Cold Boot** | 冷启动扫描 | 遍历 `/sys/block` 触发 uevent |
| **DiskSource** | 磁盘源管理 | 管理物理磁盘和属性 |

### 支持的文件系统

- ext4, f2fs, vfat, exfat, erofs

### 关键数据结构

```cpp
struct VoldConfigs {
    bool has_adoptable : 1;   // 支持可采纳存储
    bool has_quota : 1;       // 支持配额
    bool has_reserved : 1;    // 支持保留空间
    bool has_compress : 1;    // 支持压缩
};
```

### 相关内核特性

- **Netlink**: 内核与用户空间通信，传递设备热插拔事件
- **uevent**: 设备模型事件通知
- **dm-crypt**: 磁盘加密映射
- **loop device**: 回环设备（用于挂载镜像文件）

---

## 3. `apexd` — APEX 守护进程

**源码位置**: `system/apex/apexd/apexd.cpp`

### 功能概述

`apexd` 是 Android Pony EXpress (APEX) 模块管理守护进程，负责 APEX 模块的激活、卸载、回滚等生命周期管理。

### 架构原理

```
apexd (main)
  │
  ├── ApexdStartup() → 初始化
  │     ├── 扫描 /apex 目录
  │     ├── 验证 APEX 签名 (AVB)
  │     └── 激活 APEX 模块
  │
  ├── Binder 服务注册 (IApexService)
  │     ├── activatePackage() → 激活 APEX
  │     ├── deactivatePackage() → 停用 APEX
  │     ├── notifyPackagesReady() → 通知包就绪
  │     └── 处理回滚
  │
  ├── DM 设备管理 (ApexdDm)
  │     ├── 创建 dm-linear 映射
  │     └── 设置 verity 保护
  │
  └── 监控 /apex 目录变化 (inotify)
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **APEX 模块** | 可更新系统组件 | 包含系统库/模块的只读镜像 |
| **AVB 验证** | 镜像签名验证 | 使用 libavb 验证 APEX 签名 |
| **DM 设备映射** | 块设备映射 | dm-linear 映射 APEX 镜像到块设备 |
| **Verity 保护** | 完整性保护 | dm-verity 验证块设备完整性 |
| **回滚保护** | 防回滚 | 防止降级到不安全版本 |
| **激活流程** | 激活 APEX | 验证 → 创建 dm 设备 → 挂载 → 执行激活 |

### APEX 激活流程

1. 扫描 `/apex` 目录
2. 验证 APEX 文件签名 (AVB)
3. 创建 dm-linear 映射
4. 设置 dm-verity 保护
5. 挂载到 `/apex/<name>@<version>`
6. 更新 linker 配置
7. 执行 APEX 自定义激活脚本

### 相关内核特性

- **dm-linear**: 线性块设备映射
- **dm-verity**: 块设备完整性验证
- **inotify**: 文件系统监控
- **AVB (Android Verified Boot)**: 验证启动镜像签名

---

## 4. `bpfloader` — BPF 程序加载器

**源码位置**: `system/bpf/loader/Loader.cpp`

### 功能概述

`bpfloader` 负责加载 BPF (Berkeley Packet Filter) 程序到内核，用于网络监控、资源追踪等。

### 架构原理

```
bpfloader
  │
  ├── 扫描 /system/etc/bpf/ 目录
  │
  ├── 解析 ELF 格式的 BPF 对象文件
  │     ├── 读取 section headers
  │     ├── 识别 BPF 程序 section
  │     └── 提取 BPF maps 定义
  │
  ├── 加载 BPF maps
  │     └── bpf(BPF_MAP_CREATE)
  │
  ├── 加载 BPF 程序
  │     ├── 重定位处理
  │     ├── bpf(BPF_PROG_LOAD)
  │     └── 验证器检查
  │
  ├── 固定 BPF 对象到 BPF 文件系统
  │     └── bpf(BPF_OBJ_PIN, "/sys/fs/bpf/...")
  │
  └── 等待所有 BPF 程序加载完成
```

### BPF 程序类型

| 前缀 | 类型 | 用途 |
|------|------|------|
| `kprobe/` | BPF_PROG_TYPE_KPROBE | 内核探针 |
| `kretprobe/` | BPF_PROG_TYPE_KPROBE | 内核返回探针 |
| `tracepoint/` | BPF_PROG_TYPE_TRACEPOINT | 内核追踪点 |
| `skfilter/` | BPF_PROG_TYPE_SOCKET_FILTER | 套接字过滤 |
| `uprobe/` | BPF_PROG_TYPE_KPROBE | 用户空间探针 |
| `uretprobe/` | BPF_PROG_TYPE_KPROBE | 用户空间返回探针 |

### ELF Section 命名规范

```
SECTION("tracepoint/sched_switch_func")
SECTION("maps/my_map")
SECTION("license/GPL")
```

### 核心机制

1. **ELF 解析**: 解析 BPF 对象文件的 ELF 格式
2. **Map 创建**: 调用 `bpf(BPF_MAP_CREATE)` 创建 BPF maps
3. **程序加载**: 调用 `bpf(BPF_PROG_LOAD)` 加载 BPF 程序
4. **重定位**: 处理 BPF 程序中对 map 的引用
5. **Pin 固定**: 将 BPF 对象固定到 BPF 文件系统持久化
6. **版本支持**: 支持内核版本相关的多版本程序选择

### 相关内核特性

- **BPF 系统调用**: `bpf()` 系统调用加载程序和 maps
- **BPF 验证器**: 内核中的 BPF 程序安全验证器
- **BPF Maps**: 内核中的键值对数据结构
- **BPF 文件系统**: `/sys/fs/bpf/` 用于持久化 BPF 对象
- **kprobe/tracepoint**: 内核动态追踪机制
- **BTF (BPF Type Format)**: BPF 类型信息格式

---

## 5. `installd` — 安装守护进程

**源码位置**: `frameworks/native/cmds/installd/installd.cpp`

### 功能概述

`installd` 是应用安装守护进程，负责 APK 安装、卸载、数据目录管理、dex 优化等。

### 架构原理

```
installd (main)
  │
  ├── InstalldNativeService → Binder 服务
  │     ├── createAppData() → 创建应用数据目录
  │     ├── restoreconAppData() → 恢复 SELinux 上下文
  │     ├── destroyAppData() → 删除应用数据
  │     ├── rmDex() → 删除 dex 文件
  │     ├── cleanupInvalidPackageDirs() → 清理无效目录
  │     └── 更多...
  │
  ├── dexopt → dex 优化
  │     ├── 调用 dex2oat 进行 AOT 编译
  │     ├── 生成 odex/vdex/oat 文件
  │     └── 支持不同编译模式 (speed, verify, etc.)
  │
  └── initialize_directories() → 初始化目录结构
```

### 核心功能

| 功能 | 原理 |
|------|------|
| **APK 安装** | 创建数据目录，设置 SELinux 上下文 |
| **Dex 优化** | 调用 dex2oat 进行 AOT 编译 |
| **数据目录管理** | 创建/删除/清理应用数据目录 |
| **多用户支持** | 为每个用户创建独立数据目录 |
| **SELinux** | 恢复文件安全上下文 |

### 相关内核特性

- **SELinux**: 文件安全上下文管理
- **Mount Namespace**: 挂载命名空间隔离
- **文件权限**: UID/GID 管理

---

## 6. `surfaceflinger` — 表面合成器

**源码位置**: `frameworks/native/services/surfaceflinger/main_surfaceflinger.cpp`

### 功能概述

`surfaceflinger` 是 Android 图形系统的核心，负责合成各个 Surface 到屏幕上显示。

### 架构原理

```
surfaceflinger (main)
  │
  ├── 启动 Graphics Allocator Service
  │
  ├── 启动 DisplayService
  │
  ├── SurfaceFlinger::init()
  │     ├── 初始化 EGL
  │     ├── 设置 Display
  │     ├── 创建 RenderEngine
  │     └── 初始化 Layer 列表
  │
  ├── SurfaceFlinger::run()
  │     └── 主循环
  │           ├── onFrameAvailable() → 收到新帧
  │           ├── traverseLayers() → 遍历所有 Layer
  │           ├── composite() → 合成并显示
  │           └── 等待下一个 VSync
  │
  └── 通过 HIDL/AIDL 与硬件合成器通信
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **Layer** | 图层管理 | 每个 Window 对应一个 Layer |
| **VSync** | 垂直同步 | 与显示刷新率同步 |
| **Triple Buffering** | 三缓冲 | 减少画面撕裂 |
| **HWComposer** | 硬件合成 | 硬件加速合成 |
| **EGL** | OpenGL ES 上下文 | GPU 渲染 |
| **BufferQueue** | 缓冲区队列 | 生产者-消费者模型 |
| **Fence** | 同步机制 | GPU/CPU 同步 |

### 相关内核特性

- **dma-buf**: DMA 缓冲区共享
- **sync_file**: 同步文件（Fence）
- **eventfd**: 事件通知
- **ION/DMA-BUF**: 内存分配器

---

## 7. `servicemanager` — 服务管理器

**源码位置**: `frameworks/native/cmds/servicemanager/main.cpp`

### 功能概述

`serticemanager` 是 Android Binder 系统的服务注册中心，管理系统服务的注册和查找。

### 架构原理

```
servicemanager (main)
  │
  ├── Access → 访问控制检查
  │
  ├── ServiceManager → 服务注册表
  │     ├── addService() → 注册服务
  │     ├── getService() → 查找服务
  │     ├── listServices() → 列出所有服务
  │     └── 更多...
  │
  ├── BinderCallback → Binder 事件处理
  │     └── IPCThreadState::handlePolledCommands()
  │
  └── Looper 事件循环
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **服务注册** | 添加服务到注册表 | `addService(name, binder)` |
| **服务查找** | 按名称查找服务 | `getService(name)` → IBinder |
| **访问控制** | 权限验证 | 检查调用方是否有权限访问服务 |
| **Binder 驱动** | IPC 通信 | 通过 `/dev/binder` 进行进程间通信 |
| **死亡通知** | 监听服务死亡 | `linkToDeath()` 注册死亡回调 |

### 相关内核特性

- **Binder 驱动**: `/dev/binder` 内核驱动
- **ioctl**: 与 Binder 驱动通信
- **Looper/epoll**: 事件循环

---

## 8. `lmkd` — Low Memory Killer Daemon

**源码位置**: `system/memory/lmkd/lmkd.cpp`

### 功能概述

`lmkd` 是低内存杀手守护进程，负责在系统内存不足时杀死进程以释放内存。

### 架构原理

```
lmkd (main)
  │
  ├── lmkInit() → 初始化
  │     ├── 设置 oom_adj 级别
  │     ├── 初始化 PSI 监控
  │     └── 设置 BPF 程序
  │
  ├── 主循环
  │     ├── lmkCheck() → 检查内存压力
  │     │     ├── 读取 /proc/meminfo
  │     │     ├── 检查 PSI 状态
  │     │     └── 获取进程列表
  │     │
  │     ├── 计算 oom_adj 分数
  │     │     ├── 根据进程状态计算
  │     │     └── 考虑 cgroup 和 BPF
  │     │
  │     ├── kill 选中进程
  │     │     └── 发送 SIGKILL
  │     │
  │     └── 等待下一次检查
  │
  └── 支持 IPC（liblmkd_utils）
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **PSI** | 压力停滞信息 | 监控 CPU/IO/内存压力 |
| **BPF** | eBPF 程序 | 使用 BPF 辅助内存管理 |
| **oom_adj** | 进程优先级 | 根据进程类型设置 oom_adj 值 |
| **Process Reaper** | 进程收割 | 监控被杀进程是否真正退出 |
| **PSI 监控** | 内存压力监控 | `/proc/pressure/memory` |

### 相关内核特性

- **PSI (Pressure Stall Information)**: `/proc/pressure/*`
- **eBPF**: 内核中的 BPF 程序辅助决策
- **SIGKILL**: 进程杀死信号
- **cgroups**: 进程分组管理
- **process_reaper**: 进程收割机制

---

## 9. `debuggerd` — 调试器守护进程

**源码位置**: `system/core/debuggerd/debuggerd.cpp`

### 功能概述

`debuggerd` 是进程崩溃处理守护进程，当进程崩溃时生成 tombstone 文件记录崩溃信息。

### 架构原理

```
debuggerd [-b|-j] PID
  │
  ├── 解析参数
  │     ├── -b → 仅 native backtrace
  │     ├── -j → 包含 Java trace
  │     └── 默认 → 完整 tombstone
  │
  ├── 检查进程状态
  │     ├── 检查进程是否存在
  │     └── 检查是否 zombie
  │
  ├── 附加到目标进程 (ptrace)
  │     ├── PTRACE_ATTACH
  │     └── 等待进程停止
  │
  ├── 收集崩溃信息
  │     ├── 读取 /proc/<pid>/maps
  │     ├── 读取寄存器状态
  │     ├── 遍历线程
  │     ├── unwind backtrace
  │     └── 读取内存内容
  │
  ├── 生成 tombstone 文件
  │     ├── 写入 /data/tombstones/
  │     └── 包含 fault address, backtrace, memory map
  │
  └── 恢复目标进程
        └── PTRACE_DETACH
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **ptrace** | 进程追踪 | 附加到目标进程获取状态 |
| **unwind** | 栈回溯 | 解析调用栈 |
| **signal** | 信号注入 | 向目标进程发送信号 |
| **tombstone** | 崩溃记录 | 记录崩溃时的完整状态 |
| **ucontext** | 上下文信息 | 寄存器、程序计数器等 |

### 相关内核特性

- **ptrace**: 进程追踪系统调用
- **signal**: 信号处理
- **/proc/<pid>/maps**: 进程内存映射
- **unwinding**: 栈展开

---

## 10. `gatekeeperd` — 门禁守护进程

**源码位置**: `system/core/gatekeeperd/main.cpp`

### 功能概述

`gatekeeperd` 是 Android 门禁系统守护进程，负责用户认证（密码/图案/PIN 验证）。

### 架构原理

```
gatekeeperd <directory>
  │
  ├── chdir(argv[1]) → 切换到指定目录
  │
  ├── GateKeeperProxy → 封装 GateKeeper 操作
  │     ├── enroll() → 注册凭证
  │     ├── verify() → 验证凭证
  │     └── 更多...
  │
  ├── 注册 Binder 服务
  │     └── "android.service.gatekeeper.IGateKeeperService"
  │
  └── joinThreadPool() → 处理 Binder 请求
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **凭证注册** | 注册用户密码 | 生成 salt，哈希密码，存储 |
| **凭证验证** | 验证用户输入 | 比较哈希值 |
| **GateKeeper TA** | 可信执行环境 | 在 TEE 中处理敏感操作 |
| **Anti-hammering** | 防暴力破解 | 限制尝试次数，增加延迟 |

### 相关内核特性

- **TEE (Trusted Execution Environment)**: 可信执行环境
- **TrustZone**: ARM 安全扩展

---

## 11. `llkd` — Live Lock Detector

**源码位置**: `system/core/llkd/llkd.cpp`

### 功能概述

`llkd` 是活锁检测守护进程，用于检测系统是否陷入活锁状态。

### 架构原理

```
llkd (main)
  │
  ├── llkInit() → 初始化
  │     ├── 设置检测参数
  │     └── 初始化监控线程
  │
  ├── 主循环
  │     ├── llkCheck() → 检查活锁
  │     │     ├── 检查关键线程是否运行
  │     │     ├── 检查调度器状态
  │     │     └── 检查 CPU 使用率
  │     │
  │     ├── 如果检测到活锁
  │     │     ├── 记录日志
  │     │     └── 触发 kernel panic
  │     │
  │     └── usleep(检查间隔)
  │
  └── 永不退出
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **线程监控** | 监控关键线程 | 检查线程是否在运行 |
| **调度器监控** | 检查调度状态 | 检查 CPU 是否被占用 |
| **活锁检测** | 检测活锁状态 | 判断系统是否陷入死循环 |
| **kernel panic** | 触发崩溃 | 记录信息后触发重启 |

### 相关内核特性

- **调度器**: 进程调度
- **内核线程**: 内核线程监控
- **kernel panic**: 内核崩溃

---

## 12. `watchdogd` — 看门狗守护进程

**源码位置**: `system/core/watchdogd/watchdogd.cpp`

### 功能概述

`watchdogd` 是硬件看门狗守护进程，定期喂狗防止系统死锁。

### 架构原理

```
watchdogd [interval] [margin]
  │
  ├── 打开 /dev/watchdog
  │
  ├── 设置超时时间
  │     └── ioctl(WDIOC_SETTIMEOUT)
  │
  ├── 主循环
  │     ├── 喂狗 (write /dev/watchdog)
  │     └── sleep(interval)
  │
  └── 如果系统死锁 → 看门狗超时 → 系统重启
```

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **硬件看门狗** | 硬件定时器 | 独立于 CPU 的硬件定时器 |
| **喂狗** | 定期重置定时器 | 防止看门狗超时 |
| **超时重启** | 系统死锁恢复 | 看门狗超时触发硬件复位 |

### 相关内核特性

- **Watchdog 驱动**: `/dev/watchdog`
- **ioctl**: 设备控制

---

## 13. `bootstat` — 启动统计

**源码位置**: `system/core/bootstat/bootstat.cpp`

### 功能概述

`bootstat` 是启动统计工具，记录启动时间事件并上报到 statsd。

### 核心功能

| 功能 | 原理 |
|------|------|
| **记录启动事件** | 记录关键启动阶段的时间戳 |
| **上报到 statsd** | 通过 libstats 上报到 statsd |
| **持久化存储** | 将事件存储在持久存储中 |
| **事件类型** | boot_complete, boot_complete_no_encryption, factory_reset 等 |

---

## 14. `bugreport` / `bugreportz` — Bugreport 工具

**源码位置**: `frameworks/native/cmds/bugreport/bugreport.cpp`, `bugreportz/`

### 功能概述

- `bugreport`: 已废弃，提示使用 `bugreportz`
- `bugreportz`: 生成压缩格式的 bugreport

### 核心功能

| 功能 | 原理 |
|------|------|
| **收集系统状态** | 调用各系统服务 dump |
| **生成压缩文件** | 生成 zip 格式的 bugreport |
| **输出文件名** | 输出文件名供 adb pull 使用 |

---

## 15. `logd` — 日志守护进程

**源码位置**: `system/logging/logd/`

### 功能概述

`logd` 是 Android 日志系统守护进程，管理日志的读写。

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **日志缓冲区** | 管理多个日志缓冲区 | system, main, events, radio, crash |
| **Socket 通信** | 通过 socket 接收和发送日志 | `/dev/socket/logdw` |
| **SELinux** | 日志访问控制 | 检查调用方权限 |
| **日志轮转** | 日志大小管理 | 自动清理旧日志 |

### 相关内核特性

- **socket**: Unix domain socket
- **SELinux**: 访问控制

---

## 16. `logcat` — 日志查看工具

**源码位置**: `system/logging/logcat/`

### 功能概述

`logcat` 是日志查看工具，从 logd 读取日志并输出。

### 核心功能

| 功能 | 原理 |
|------|------|
| **读取日志** | 从 logd socket 读取 |
| **过滤** | 按 tag/pid/优先级过滤 |
| **格式化** | 多种输出格式 |
| **颜色** | 终端颜色高亮 |

---

## 17. `tombstoned` — Tombstone 管理

**源码位置**: `system/core/debuggerd/tombstoned.cpp`

### 功能概述

`tombstoned` 管理 tombstone 文件的创建和上传。

### 核心功能

| 功能 | 原理 |
|------|------|
| **创建 tombstone** | 接收 debuggerd 的崩溃数据 |
| **文件管理** | 管理 /data/tombstones/ 目录 |
| **上传** | 上传到服务器 |

---

## 18. `keystore2` — 密钥存储

**源码位置**: `system/security/keystore2/`

### 功能概述

`keystore2` 是 Android 密钥存储系统，管理加密密钥。

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **密钥生成** | 生成加密密钥 | 支持 RSA, AES, ECDSA 等 |
| **密钥存储** | 安全存储密钥 | 在 TEE/SE 中存储 |
| **密钥使用** | 使用密钥签名/加密 | 在 TEE 中执行 |
| **密钥删除** | 删除密钥 | 安全擦除 |

### 相关内核特性

- **TEE**: 可信执行环境
- **Keymint**: Key Master HAL

---

## 19. `drmserver` — DRM 服务

**源码位置**: `frameworks/av/drm/drmserver/`

### 功能概述

`drmserver` 是 DRM（数字版权管理）服务，管理媒体内容的 DRM 保护。

### 核心功能

| 功能 | 原理 |
|------|------|
| **DRM 会话管理** | 创建/管理 DRM 会话 |
| **许可证处理** | 处理 DRM 许可证 |
| **解密** | 解密受保护内容 |
| **插件系统** | 支持多种 DRM 方案（Widevine, PlayReady 等） |

---

## 20. `mediaextractor` / `mediaserver` / `cameraserver` / `audioserver`

### 功能概述

| 守护进程 | 功能 |
|----------|------|
| `mediaextractor` | 媒体文件解析（提取音视频轨道） |
| `mediaserver` | 媒体服务（已废弃，功能拆分到各服务） |
| `cameraserver` | 相机服务 |
| `audioserver` | 音频服务 |

### 核心机制

- **MediaCodec**: 编解码框架
- **Camera HAL**: 相机硬件抽象层
- **Audio HAL**: 音频硬件抽象层
- **BufferQueue**: 缓冲区队列

---

## 21. `credstore` — 凭证存储

**源码位置**: `system/security/identity/`

### 功能概述

`credstore` 管理用户凭证（如数字钥匙、身份证等）。

---

## 22. `prng_seeder` — 随机数种子

**源码位置**: `system/security/prng_seeder/`

### 功能概述

`prng_seeder` 从硬件随机数生成器获取随机种子，提供给系统使用。

### 相关内核特性

- **RNGD**: 硬件随机数生成器
- **/dev/urandom**: 内核随机数设备

---

## 23. `netd` / `ndc` — 网络守护进程

**源码位置**: `system/netd/`

### 功能概述

`netd` 是网络管理守护进程，`ndc` 是其控制工具。

### 核心功能

| 功能 | 原理 |
|------|------|
| **网络配置** | 配置网络接口、路由 |
| **防火墙** | 通过 iptables/nftables 配置 |
| **DNS** | DNS 解析管理 |
| **带宽控制** | 流量整形和带宽限制 |
| **Tethering** | 网络共享（热点） |

### 相关内核特性

- **Netfilter**: 网络包过滤
- **iptables/nftables**: 防火墙规则
- **TC (Traffic Control)**: 流量控制
- **socket**: 网络通信

---

## 24. `gsid` / `gsi_tool` — GSI 工具

**源码位置**: `system/gsid/`

### 功能概述

`gsid` 是 Generic System Image (GSI) 管理守护进程。

### 核心功能

| 功能 | 原理 |
|------|------|
| **GSI 安装** | 安装 GSI 到系统分区 |
| **GSI 管理** | 管理 GSI 生命周期 |
| **DSU** | Dynamic System Update |

---

## 25. `snapuserd` / `snapshotctl` — 快照管理

**源码位置**: `system/core/fs_mgr/libsnapshot/`

### 功能概述

`snapuserd` 是快照守护进程，`snapshotctl` 是快照控制工具。

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **dm-snapshot** | 设备映射快照 | 创建块设备快照 |
| **dm-user** | 用户空间设备映射 | 在用户空间处理快照 |
| **快照合并** | 合并快照数据 | 将快照合并回原始设备 |
| **OTA 更新** | 支持 A/B 更新 | 在更新时保留快照 |

### 相关内核特性

- **dm-snapshot**: 设备映射快照
- **dm-user**: 用户空间设备映射
- **dm-linear**: 线性映射

---

## 26. `update_engine` — OTA 更新引擎

**源码位置**: `system/update_engine/`

### 功能概述

`update_engine` 是 OTA 更新引擎，负责下载和安装系统更新。

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **A/B 更新** | 无缝更新 | 在后台更新非活动分区 |
| **增量更新** | 差量更新 | 仅下载差异部分 |
| **验证** | 更新包验证 | 签名验证和完整性检查 |
| **回滚** | 更新失败回滚 | 恢复到之前版本 |

---

## 27. `heapprofd` / `perfetto` — 性能分析

**源码位置**: `external/perfetto/`

### 功能概述

- `heaprofd`: 堆分析守护进程
- `perfetto`: 系统级性能追踪框架
- `traced` / `traced_probes`: 追踪守护进程

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **堆分析** | 分析 native 堆分配 | 通过 heapprofd |
| **系统追踪** | 追踪系统行为 | 通过 traced |
| **ftrace** | 内核追踪 | 通过 debugfs |
| **Perfetto UI** | 可视化追踪结果 | 在浏览器中查看 |

### 相关内核特性

- **ftrace**: 内核追踪框架
- **perf**: 性能监控
- **trace_marker**: 追踪标记

---

## 28. `aconfigd` — 配置管理

**源码位置**: `system/server_configurable_flags/aconfigd/`

### 功能概述

`aconfigd` 是 AConfig 配置管理守护进程，管理系统配置标志。

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **配置存储** | 存储配置标志 | 持久化到文件 |
| **配置读取** | 读取配置值 | 从缓存或文件读取 |
| **配置更新** | 更新配置 | 通过 Binder 更新 |

---

## 29. `dmesgd` — 内核日志守护进程

**源码位置**: `system/dmesgd/`

### 功能概述

`dmesgd` 是内核日志守护进程，定期读取和记录内核日志。

---

## 30. `storaged` — 存储统计

**源码位置**: `system/core/storaged/`

### 功能概述

`storaged` 是存储统计守护进程，收集和存储存储性能数据。

### 核心功能

| 功能 | 原理 |
|------|------|
| **I/O 统计** | 收集存储 I/O 性能数据 |
| **寿命监控** | 监控存储寿命 |
| **上报** | 上报到 statsd |

---

## 31. `usbd` — USB 守护进程

**源码位置**: `system/core/usbd/`

### 功能概述

`usbd` 是 USB 守护进程，处理 USB 设备事件。

---

## 32. `reboot` — 重启工具

**源码位置**: `system/core/reboot/`

### 功能概述

`reboot` 是重启工具，触发系统重启。

---

## 33. `run-as` — 应用身份切换

**源码位置**: `system/core/run-as/`

### 功能概述

`run-as` 允许以指定应用的身份运行命令。

### 核心机制

| 机制 | 功能 | 原理 |
|------|------|------|
| **身份切换** | 切换到应用 UID | setuid/setgid |
| **数据目录** | 切换到应用数据目录 | chdir |
| **权限检查** | 检查调用方权限 | 检查 debuggable |

---

## 34. `rss_hwm_reset` — RSS 重置

**源码位置**: `frameworks/native/cmds/rss_hwm_reset/`

### 功能概述

`rss_hwm_reset` 重置进程的 RSS（Resident Set Size）高水位标记。

---

## 35. `sfdo` — SurfaceFlinger DO

**源码位置**: `frameworks/native/cmds/sfdo/`

### 功能概述

`sfdo` 是 SurfaceFlinger 调试工具。

---

## 36. `settaskprofile` — 任务配置

**源码位置**: `system/core/libprocessgroup/tools/`

### 功能概述

`settaskprofile` 设置进程的任务配置（cgroup 属性）。

---

## 37. `pintool` — PIN 工具

**源码位置**: `system/extras/pinner/`

### 功能概述

`pintool` 用于将文件固定到内存中（防止被 swap）。

---

## 38. `snapshotctl` — 快照控制

**源码位置**: `system/core/fs_mgr/libsnapshot/`

### 功能概述

`snapshotctl` 是快照控制工具，管理 dm-snapshot 设备。

---

## 39. `idmap2` — ID 映射

**源码位置**: `frameworks/base/cmds/idmap2/`

### 功能概述

`idmap2` 是资源 ID 映射工具，用于 overlay 和 shared resource 映射。

---

## 40. `vintf` — VINTF 工具

**源码位置**: `system/libvintf/`

### 功能概述

`vintf` 是 Vendor Interface 工具，管理 HAL 和框架之间的兼容性。

---

## 总结

| 守护进程 | 核心功能 | 相关内核特性 |
|----------|----------|-------------|
| `init` | 系统初始化 | signalfd, eventfd, epoll |
| `vold` | 存储卷管理 | Netlink, uevent, dm-crypt |
| `apexd` | APEX 模块管理 | dm-linear, dm-verity, inotify |
| `bpfloader` | BPF 程序加载 | BPF 系统调用, kprobe, tracepoint |
| `installd` | 应用安装 | SELinux, mount namespace |
| `surfaceflinger` | 图形合成 | dma-buf, sync_file, ION |
| `servicemanager` | 服务注册中心 | Binder 驱动 |
| `lmkd` | 低内存杀手 | PSI, eBPF, cgroups |
| `debuggerd` | 崩溃处理 | ptrace, signal |
| `gatekeeperd` | 用户认证 | TEE, TrustZone |
| `llkd` | 活锁检测 | 调度器监控 |
| `watchdogd` | 硬件看门狗 | watchdog 驱动 |
| `logd` | 日志管理 | socket, SELinux |
| `netd` | 网络管理 | Netfilter, iptables |
| `snapuserd` | 快照管理 | dm-snapshot, dm-user |
| `update_engine` | OTA 更新 | A/B 更新 |
| `keystore2` | 密钥存储 | TEE, Keymint |
