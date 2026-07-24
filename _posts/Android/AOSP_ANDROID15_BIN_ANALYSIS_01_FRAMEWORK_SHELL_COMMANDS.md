# AOSP Android15 GSI Framework Shell Commands 分析

本文档分析 AOSP Android15 中 `frameworks/base/cmds/` 和 `development/cmds/` 下的框架 Shell 命令。

---

## 1. `am` — Activity Manager

**源码位置**: `frameworks/base/cmds/am/src/com/android/commands/am/Am.java`

### 功能概述

`am` 是 Android 中最核心的系统调试工具之一，用于控制 Activity 生命周期、服务管理、广播发送、进程管理、instrumentation 测试等。

### 架构原理

```
am [subcommand]
  │
  ├── instrument → 本地解析参数，直接调用 Instrument 类
  │
  └── 其他子命令 → runAmCmd()
                    │
                    └── mAm.asBinder().shellCommand(in, out, err, args, callback, resultReceiver)
                              │
                              └── Binder IPC → ActivityManagerService.shellCommand()
                                                  │
                                                  └── 解析并执行子命令
```

**关键设计**: 除 `instrument` 外，所有子命令通过 `IActivityManager.shellCommand()` 将参数传递给 system_server 中的 ActivityManagerService 执行。这意味着大部分逻辑在 AMS 中实现，`am` 只是一个薄壳。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `start` | 启动 Activity | 通过 AMS 解析 Intent，检查权限，找到目标 Activity 并启动 |
| `start-service` / `startservice` | 启动 Service | AMS 查找目标 Service 并调用其 onCreate/onStartCommand |
| `stopservice` | 停止 Service | AMS 调用 Service 的 onDestroy |
| `broadcast` | 发送广播 | AMS 将广播分发给匹配的 Receiver（有序/无序） |
| `force-stop` | 强制停止进程 | AMS 杀死指定包名的所有进程，清除其状态 |
| `kill` | 杀死后台进程 | AMS 杀死指定进程（仅当进程在后台且非持久） |
| `kill-all` | 杀死所有后台进程 | 遍历并杀死所有可杀死的后台进程 |
| `crash` | 使应用崩溃 | 向目标进程注入 SIGGV 信号 |
| `hang` | 使系统挂起 | 触发 system_server 死锁检测 |
| `restart` | 重启系统 | 触发有序重启 |
| `dump` | 触发 AMS dump | 请求 AMS 执行 dump 操作 |
| `stack` | 管理 Activity 栈 | 列出/移动/调整 Activity 栈 |
| `task` | 管理 Task | 操作 Task（move-to-front, remove 等） |
| `activity` | Activity 控制 | 控制 Activity 生命周期 |
| `screen-compat` | 屏幕兼容性控制 | 开启/关闭屏幕兼容模式 |
| `display` | 显示管理 | 控制 display 状态 |
| `user` | 用户管理 | 用户切换/管理 |
| `get-config` | 获取配置 | 获取设备配置信息 |
| `get-started-user-state` | 获取用户启动状态 | 查询用户是否已启动 |
| `compact` | 进程压缩 | 触发进程内存压缩 |
| `instrument` | 运行 instrumentation | **本地执行**，启动测试框架 |

### Instrument 子命令详解

`am instrument` 是唯一在本地解析执行的子命令，用于运行 Android 测试框架：

- `-p <file>`: 性能分析输出文件
- `-w`: 等待测试完成
- `-r`: 原始模式（raw mode）
- `-m`: protobuf 标准输出
- `-f <path>`: protobuf 文件输出
- `-e <key> <value>`: 传入测试参数
- `--no-window_animation`: 禁用窗口动画
- `--no-hidden-api-checks`: 禁用隐藏 API 检查
- `--no-test-api-access`: 禁用测试 API 访问
- `--no-isolated-storage`: 禁用隔离存储
- `--no-logcat`: 不捕获 logcat
- `--user <user>`: 指定用户
- `--abi <abi>`: 指定 ABI
- `--no-restart`: 不重启目标进程
- `--always-check-signature`: 始终检查签名
- `--instrument-sdk-sandbox`: 在 SDK Sandbox 中运行测试

### 关键机制

- **ShellCallback**: 处理 system_server 回调打开文件的请求（用于性能分析输出）
- **ResultReceiver**: 接收异步执行结果
- **权限**: 以 shell UID 运行，拥有调试级权限

---

## 2. `pm` — Package Manager

**源码位置**: `frameworks/base/cmds/pm/pm.sh` → `cmd package "$@"`

### 功能概述

`pm` 是包管理命令，用于安装/卸载应用、查询包信息、管理权限、用户管理等。

### 架构原理

```bash
# pm.sh
#!/system/bin/sh
cmd package "$@"
```

`pm` 是一个纯 shell 脚本，将所有参数转发给 `cmd package`。实际实现位于 system_server 中的 `PackageManagerService` 的 `onShellCommand()` 方法。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `list` | 列出包/权限/功能/库 | PMS 查询并输出 |
| `path` | 获取 APK 路径 | PMS 返回指定包的安装路径 |
| `dump` | 转储包信息 | PMS 输出包的详细状态 |
| `install` | 安装 APK | PMS 执行安装流程（复制、优化、扫描） |
| `install-write` | 写入分块安装数据 | 用于 ADB 分块安装 |
| `uninstall` | 卸载应用 | PMS 删除应用数据和应用代码 |
| `clear` | 清除应用数据 | PMS 清除指定应用的数据目录 |
| `grant` | 授予运行时权限 | PMS 修改权限状态 |
| `revoke` | 撤销运行时权限 | PMS 修改权限状态 |
| `set-install-location` | 设置默认安装位置 | 0=auto, 1=internal, 2=external |
| `get-install-location` | 获取当前安装位置 | 返回当前设置 |
| `enable/disable` | 启用/禁用组件或包 | PMS 修改组件启用状态 |
| `hide/unhide` | 隐藏/取消隐藏包 | PMS 修改隐藏状态 |
| `create-user` | 创建用户 | PMS 创建新用户 |
| `remove-user` | 删除用户 | PMS 删除用户及其数据 |
| `set-user-restriction` | 设置用户限制 | PMS 应用用户级限制 |
| `trim-caches` | 修剪缓存 | PMS 清理应用缓存 |
| `resolve-activity` | 解析 Activity | PMS 返回匹配 Intent 的 Activity |
| `query-activities` | 查询 Activities | PMS 返回匹配 Intent 的所有 Activities |
| `query-services` | 查询 Services | PMS 返回匹配 Intent 的所有 Services |
| `query-receivers` | 查询 Receivers | PMS 返回匹配 Intent 的所有 Receivers |

### 关键机制

- **安装流程**: `install` → 复制 APK → dex 优化（dex2oat）→ 扫描（更新 PMS 数据库）
- **权限模型**: Android 6.0+ 运行时权限，`grant/revoke` 直接修改权限状态
- **多用户**: 每个用户有独立的包安装状态

---

## 3. `wm` — Window Manager

**源码位置**: `frameworks/base/cmds/wm/wm.sh` → `cmd window "$@"`

### 功能概述

`wm` 是窗口管理命令，用于控制显示参数、窗口模式、兼容性等。

### 架构原理

```bash
# wm.sh
#!/system/bin/sh
cmd window "$@"
```

实际实现位于 system_server 中的 `WindowManagerService` 的 `onShellCommand()` 方法。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `size` | 设置/获取显示尺寸 | WMS 修改 display 尺寸（分辨率覆盖） |
| `density` | 设置/获取显示密度 | WMS 修改 display DPI |
| `overscan` | 设置 overscan | WMS 修改显示边距 |
| `dismiss-keyguard` | 解除锁屏 | WMS 请求解锁 |
| `scaling` | 设置显示缩放模式 | WMS 设置缩放模式（auto/uniform） |
| `user-rotation` | 设置用户旋转 | WMS 设置用户指定的屏幕旋转 |
| `set-ignore-orientation-request` | 忽略方向请求 | WMS 设置是否忽略应用的方向请求 |
| `set-fix-to-user-rotation` | 固定用户旋转 | WMS 固定屏幕旋转 |
| `set-display-windowing-mode` | 设置窗口模式 | WMS 设置 display 的窗口模式 |
| `set-ignore-ime-inset` | 忽略 IME inset | WMS 设置是否忽略输入法区域 |

### 关键机制

- **Display Size Override**: 通过 `wm size` 可以覆盖物理分辨率，用于测试不同分辨率
- **Density Override**: 通过 `wm density` 可以覆盖物理 DPI
- **兼容性**: 用于测试应用在不同显示配置下的行为

---

## 4. `input` — Input Manager

**源码位置**: `frameworks/base/cmds/input/input.sh` → `cmd input "$@"`

### 功能概述

`input` 是输入注入命令，用于模拟触摸、按键、文本输入等。

### 架构原理

```bash
# input.sh
#!/system/bin/sh
cmd input "$@"
```

实际实现位于 system_server 中的 `InputManagerService` 的 `onShellCommand()` 方法。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `text <string>` | 注入文本输入 | IMS 模拟键盘输入事件 |
| `keyevent <code>` | 注入按键事件 | IMS 发送 KeyEvent（DOWN + UP） |
| `tap <x> <y>` | 模拟点击 | IMS 注入 ACTION_DOWN + ACTION_UP |
| `swipe <x1> <y1> <x2> <y2> [duration]` | 模拟滑动 | IMS 注入 ACTION_DOWN → MOVE → UP |
| `press` | 模拟按键按下 | IMS 注入 ACTION_DOWN |
| `roll <dx> <dy>` | 模拟滚轮 | IMS 注入滚动事件 |
| `draganddrop` | 模拟拖放 | IMS 注入拖拽事件 |
| `motionevent` | 注入 MotionEvent | IMS 注入指定类型的 MotionEvent |

### 关键机制

- **InputManagerService**: 系统级输入管理服务，负责事件分发
- **注入方式**: 通过 `InputManager.injectInputEvent()` 注入事件
- **权限**: 需要 `INJECT_EVENTS` 权限（shell 拥有）

---

## 5. `svc` — Service Control

**源码位置**: `frameworks/base/cmds/svc/`

### 功能概述

`svc` 用于控制系统服务（WiFi、蓝牙、NFC、USB、电源等）。

### 架构原理

```
svc [subcommand]
  │
  ├── wifi/bt/data → svc.sh 转发至 cmd <service>
  │
  └── power/usb/nfc/system-server → Svc.java (app_process)
                                      │
                                      └── Binder IPC → 对应系统服务
```

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `power stayon` | 设置保持唤醒 | IPowerManager.setStayOnSetting() |
| `power reboot` | 重启设备 | IPowerManager.reboot() |
| `power shutdown` | 关机 | IPowerManager.shutdown() |
| `power forcesuspend` | 强制挂起 | IPowerManager.forceSuspend() |
| `usb setFunctions` | 设置 USB 功能 | IUsbManager.setCurrentFunctions() |
| `usb getFunctions` | 获取 USB 功能 | IUsbManager.getCurrentFunctions() |
| `usb setScreenUnlockedFunctions` | 设置解锁后功能 | IUsbManager.setScreenUnlockedFunctions() |
| `usb resetUsbGadget` | 重置 USB gadget | IUsbManager.resetUsbGadget() |
| `usb getUsbSpeed` | 获取 USB 速度 | IUsbManager.getCurrentUsbSpeed() |
| `usb getGadgetHalVersion` | 获取 Gadget HAL 版本 | IUsbManager.getGadgetHalVersion() |
| `usb getUsbHalVersion` | 获取 USB HAL 版本 | IUsbManager.getUsbHalVersion() |
| `usb resetUsbPort` | 重置 USB 端口 | UsbPort.resetUsbPort() |
| `nfc enable/disable` | 启用/禁用 NFC | NfcAdapter.enable()/disable() |
| `system-server wait-for-crash` | 等待 system server 崩溃 | 通过 ParcelFileDescriptor 监控进程存活 |
| `wifi enable/disable` | 启用/禁用 WiFi | 转发至 cmd wifi |
| `bluetooth enable/disable` | 启用/禁用蓝牙 | 转发至 cmd bluetooth_manager |
| `data enable/disable` | 启用/禁用移动数据 | 转发至 cmd phone data |

### 关键机制

- **进程生命监控**: `wait-for-crash` 利用 Linux fd 生命周期特性——进程死亡后内核自动关闭 fd
- **USB 功能**: 通过位掩码控制（mtp/ptp/rndis/midi/ncm）
- **HAL 版本**: 映射到 USB Gadget HAL 版本号

---

## 6. `content` — Content Provider 操作

**源码位置**: `frameworks/base/cmds/content/src/com/android/commands/content/Content.java`

### 功能概述

`content` 用于直接操作 ContentProvider，执行 CRUD 操作。

### 架构原理

```
content [subcommand] [args]
  │
  └── Content.main() → 解析子命令
        │
        ├── ActivityManager.getContentProviderExternal() 获取 Provider
        │
        └── IContentProvider.insert/update/delete/query/call/openFile/getType
                  │
                  └── Binder IPC → Provider 所在进程
```

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `insert` | 插入记录 | IContentProvider.insert() |
| `update` | 更新记录 | IContentProvider.update() |
| `delete` | 删除记录 | IContentProvider.delete() |
| `query` | 查询记录 | IContentProvider.query() → Cursor 遍历输出 |
| `call` | 调用自定义方法 | IContentProvider.call() |
| `read` | 读取文件 | IContentProvider.openFile("r") → 复制到 stdout |
| `write` | 写入文件 | IContentProvider.openFile("w") → 从 stdin 复制 |
| `gettype` | 获取 MIME 类型 | IContentProvider.getType() |

### 类型编码

- `b`=boolean, `s`=string, `i`=integer, `l`=long, `f`=float, `d`=double, `n`=null

### 关键机制

- **直接 IContentProvider 调用**: 绕过 ContentResolver，直接操作 Provider
- **AttributionSource**: 标识调用方身份（shell → "com.android.shell"）
- **外部引用管理**: 通过 `getContentProviderExternal()` 获取引用，操作完成后释放

---

## 7. `dumpsys` — 系统服务状态转储

**源码位置**: `frameworks/native/cmds/dumpsys/`

### 功能概述

`dumpsys` 用于获取系统服务的调试信息。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `dumpsys` | 列出所有服务 | ServiceManager.listServices() |
| `dumpsys <service>` | 转储指定服务 | IBinder.dump() |
| `dumpsys -l` | 列出服务名 | ServiceManager.listServices() |
| `dumpsys -c` | 清除服务缓存 | 清除服务缓存 |
| `dumpsys -t <secs>` | 超时设置 | 设置 dump 超时 |
| `dumpsys --priority LEVEL` | 设置优先级 | 设置 dump 优先级 |
| `dumpsys -h` | 帮助 | 显示帮助信息 |

### 关键机制

- **IBinder.dump()**: 每个系统服务实现此方法输出调试信息
- **服务发现**: 通过 ServiceManager 获取所有注册的服务

---

## 8. `dumpstate` — Bugreport 数据收集

**源码位置**: `frameworks/native/cmds/dumpstate/`

### 功能概述

`dumpstate` 用于收集系统状态数据，生成 bugreport。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `dumpstate` | 收集所有数据 | 调用各服务 dump |
| `dumpstate -w` | 等待完成 | 等待所有 dump 完成 |
| `dumpstate -s` | 输出到 stdout | 输出到标准输出 |
| `dumpstate -o <file>` | 输出到文件 | 输出到指定文件 |

### 关键机制

- **Bugreport 流程**: 调用各系统服务 dump 方法，收集日志、状态信息
- **与 dumpsys 关系**: dumpstate 内部调用 dumpsys 获取服务状态

---

## 9. `settings` — 系统设置管理

**源码位置**: `frameworks/base/cmds/settings/`

### 功能概述

`settings` 用于读写 Settings Provider 中的配置。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `get <namespace> <key>` | 获取设置值 | SettingsProvider.get() |
| `put <namespace> <key> <value>` | 设置值 | SettingsProvider.put() |
| `delete <namespace> <key>` | 删除设置 | SettingsProvider.delete() |
| `list <namespace>` | 列出所有设置 | SettingsProvider.list() |
| `reset <namespace>` | 重置设置 | SettingsProvider.reset() |

### 命名空间

- `system`: 系统设置（如屏幕亮度、音量）
- `secure`: 安全设置（如锁屏方式、已安装的辅助功能）
- `global`: 全局设置（如开发选项、自动时间）

---

## 10. `cmd` — 通用服务命令分发器

**源码位置**: `frameworks/native/cmds/cmd/`

### 功能概述

`cmd` 是 Android 统一的 shell 命令分发框架，用于执行系统服务命令。

### 架构原理

```
cmd <service> [subcommand] [args]
  │
  └── 查找对应服务的 ShellCommand
        │
        └── 调用 onCommand() 方法
              │
              └── 执行具体操作
```

### 支持的服务

- `cmd package` → PackageManagerService
- `cmd window` → WindowManagerService
- `cmd activity` → ActivityManagerService
- `cmd input` → InputManagerService
- `cmd wifi` → WifiService
- `cmd bluetooth_manager` → BluetoothManagerService
- `cmd phone` → TelephonyRegistry
- `cmd connectivity` → ConnectivityManager
- `cmd uimode` → UiModeManagerService
- `cmd alarm` → AlarmManagerService
- `cmd deviceidle` → DeviceIdleController
- `cmd jobscheduler` → JobSchedulerService
- `cmd notification` → NotificationManagerService
- `cmd power` → PowerManagerService
- `cmd role` → RoleManagerService
- `cmd sensor_privacy` → SensorPrivacyManager
- `cmd shortcut` → ShortcutService
- `cmd slice` → SliceManager
- `cmd statusbar` → StatusBarManagerService
- `cmd user` → UserManagerService
- `cmd voiceinteraction` → VoiceInteractionManagerService
- `cmd wallpaper` → WallpaperManagerService
- 等等...

### 关键机制

- **ShellCommand 接口**: 每个服务实现 `ShellCommand` 接口
- **自动注册**: 服务在 system_server 中注册时自动注册 ShellCommand
- **权限检查**: 每个命令可以自定义权限检查逻辑

---

## 11. `sm` — Storage Manager

**源码位置**: `frameworks/base/cmds/sm/src/com/android/commands/sm/Sm.java`

### 功能概述

`sm` 是存储管理命令，用于管理磁盘、卷、分区等。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `list-disks [adoptable]` | 列出磁盘 | IStorageManager.getDisks() |
| `list-volumes [type]` | 列出卷 | IStorageManager.getVolumes() |
| `has-adoptable` | 检查是否有可采纳存储 | StorageManager.hasAdoptable() |
| `get-primary-storage-uuid` | 获取主存储 UUID | IStorageManager.getPrimaryStorageUuid() |
| `set-force-adoptable` | 强制可采纳模式 | IStorageManager.setDebugFlags() |
| `set-virtual-disk` | 设置虚拟磁盘 | IStorageManager.setDebugFlags() |
| `partition DISK [public|private|mixed]` | 分区磁盘 | IStorageManager.partitionXxx() |
| `mount VOLUME` | 挂载卷 | IStorageManager.mount() |
| `unmount VOLUME` | 卸载卷 | IStorageManager.unmount() |
| `format VOLUME` | 格式化卷 | IStorageManager.format() |
| `benchmark VOLUME` | 基准测试 | IStorageManager.benchmark() |
| `idle-maint [run|abort]` | 空闲维护 | IStorageManager.runIdleMaintenance() |
| `fstrim` | 执行 fstrim | IStorageManager.fstrim() |
| `forget [UUID|all]` | 忘记卷 | IStorageManager.forgetVolume() |
| `start-checkpoint` | 启动检查点 | IStorageManager.startCheckpoint() |
| `supports-checkpoint` | 检查是否支持检查点 | IStorageManager.supportsCheckpoint() |
| `unmount-app-data-dirs` | 卸载应用数据目录 | IStorageManager.disableAppDataIsolation() |

### 关键机制

- **IStorageManager**: 通过 Binder 与 vold 通信
- **卷类型**: public/private/emulated/stub
- **检查点**: 用于 A/B 更新和回滚

---

## 12. `bu` — Backup

**源码位置**: `frameworks/base/cmds/bu/src/com/android/commands/bu/Backup.java`

### 功能概述

`bu` 是备份管理命令，用于执行备份和恢复操作。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `backup` | 执行备份 | IBackupManager.fullBackup() |
| `restore` | 执行恢复 | IBackupManager.fullRestore() |

### 关键机制

- **IBackupManager**: 通过 Binder 与 BackupManagerService 通信
- **全量备份**: 备份整个应用数据
- **用户支持**: 支持多用户备份

---

## 13. `bmgr` — Backup Manager (Transport 层)

**源码位置**: `frameworks/base/cmds/bmgr/src/com/android/commands/bmgr/Bmgr.java`

### 功能概述

`bmgr` 是备份传输层管理工具，用于管理备份传输、执行备份/恢复操作。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `list transports` | 列出可用传输 | IBackupManager.listTransports() |
| `set-transport <transport>` | 设置活跃传输 | IBackupManager.selectBackupTransport() |
| `backup <package>` | 备份指定包 | IBackupManager.requestBackup() |
| `restore <package>` | 恢复指定包 | IBackupManager.requestRestore() |
| `fullbackup` | 全量备份 | IBackupManager.fullBackup() |
| `fullrestore` | 全量恢复 | IBackupManager.fullRestore() |
| `run` | 执行备份/恢复 | IBackupManager.runBackup() / runRestore() |
| `clear <transport>` | 清除传输数据 | IBackupManager.clearBackupData() |
| `enable <true|false>` | 启用/禁用备份 | IBackupManager.setBackupEnabled() |
| `enabled` | 检查备份是否启用 | IBackupManager.isBackupEnabled() |
| `provisioned` | 检查是否已配置 | IBackupManager.isBackupServiceActive() |

### 关键机制

- **传输层**: 支持多种备份传输（Google 传输、本地传输等）
- **观察者模式**: 使用 IBackupObserver/IRestoreObserver 接收进度回调
- **全量备份**: 通过 ParcelFileDescriptor 传输备份数据

---

## 14. `ime` — Input Method Manager

**源码位置**: `frameworks/base/cmds/ime/`

### 功能概述

`ime` 是输入法管理命令，用于列出、启用、禁用输入法。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `list` | 列出输入法 | InputMethodManagerService |
| `enable` | 启用输入法 | InputMethodManagerService |
| `disable` | 禁用输入法 | InputMethodManagerService |
| `set` | 设置当前输入法 | InputMethodManagerService |

---

## 15. `locksettings` — 锁屏设置

**源码位置**: `frameworks/base/cmds/locksettings/`

### 功能概述

`locksettings` 用于管理锁屏相关设置。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `set-password` | 设置锁屏密码 | LockSettingsService |
| `clear-password` | 清除锁屏密码 | LockSettingsService |
| `verify` | 验证锁屏密码 | LockSettingsService |
| `set-disabled` | 设置锁屏禁用 | LockSettingsService |
| `get-disabled` | 获取锁屏禁用状态 | LockSettingsService |

---

## 16. `appops` — App Operations

**源码位置**: `frameworks/base/cmds/appops/`

### 功能概述

`appops` 用于管理应用操作权限（AppOps）。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `set` | 设置 AppOps 模式 | AppOpsManager.setMode() |
| `get` | 获取 AppOps 模式 | AppOpsManager.getMode() |
| `reset` | 重置 AppOps | AppOpsManager.resetAllModes() |
| `start` | 启动操作（Android 11+） | AppOpsManager.startOp() |
| `stop` | 停止操作（Android 11+） | AppOpsManager.stopOp() |

---

## 17. `appwidget` — App Widget

**源码位置**: `frameworks/base/cmds/appwidget/src/com/android/commands/appwidget/AppWidget.java`

### 功能概述

`appwidget` 用于管理应用小部件。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `grantbind` | 授予绑定权限 | AppWidgetManagerService |
| `revokebind` | 撤销绑定权限 | AppWidgetManagerService |

---

## 18. `requestsync` — 同步请求

**源码位置**: `frameworks/base/cmds/requestsync/src/com/android/commands/requestsync/RequestSync.java`

### 功能概述

`requestsync` 用于请求立即执行同步。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `requestsync` | 请求同步 | ContentResolver.requestSync() |

---

## 19. `hid` — HID 设备注入

**源码位置**: `frameworks/base/cmds/hid/src/com/android/commands/hid/Hid.java`

### 功能概述

`hid` 用于向系统注入 HID（Human Interface Device）事件。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `hid [FILE]` | 从文件读取 HID 报告并注入 | 解析 HID 报告描述符，创建虚拟设备 |

### 关键机制

- **HID 协议**: 解析 HID 报告描述符
- **虚拟设备**: 创建虚拟 HID 设备
- **事件注入**: 通过 /dev/uinput 或类似机制注入事件

---

## 20. `uinput` — User-space Input

**源码位置**: `frameworks/base/cmds/uinput/src/com/android/commands/uinput/Uinput.java`

### 功能概述

`uinput` 用于创建用户空间输入设备并注入事件。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `uinput [FILE]` | 从 JSON 文件读取配置，创建虚拟输入设备 | 解析 JSON，通过 /dev/uinput 创建设备 |

### 关键机制

- **JSON 配置**: 设备配置使用 JSON 格式
- **uinput**: 通过 Linux uinput 机制创建虚拟输入设备
- **事件注入**: 支持绝对坐标、按键、相对坐标等事件类型

---

## 21. `vr` — VR 模式

**源码位置**: `frameworks/base/cmds/vr/src/com/android/commands/vr/Vr.java`

### 功能概述

`vr` 用于控制 VR 模式。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `set-persistent-vr-mode-enabled` | 设置持久 VR 模式 | IVrManager.setPersistentVrModeEnabled() |
| `set-display-props` | 设置 VR 2D 显示属性 | IVrManager.setVr2dDisplayProperties() |
| `enable-virtual-display` | 启用虚拟显示 | IVrManager.enableVirtualDisplay() |

---

## 22. `screencap` — 屏幕截图

**源码位置**: `frameworks/base/cmds/screencap/`

### 功能概述

`screencap` 用于截取屏幕内容。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `screencap [file]` | 截取屏幕 | SurfaceControl.screenshot() |

---

## 23. `monkey` — 随机测试

**源码位置**: `development/cmds/monkey/src/com/android/commands/monkey/`

### 功能概述

`monkey` 是用于压力测试的伪随机事件生成器。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `monkey [options]` | 生成伪随机事件 | MonkeySourceRandom 生成事件流 |

### 关键机制

- **事件源**: MonkeySourceRandom 生成伪随机事件
- **事件类型**: 触摸、按键、滑动、Activity 切换等
- **约束**: 可以限制目标包、事件间隔、类型分布

---

## 24. `abx` — Android Binary XML

**源码位置**: `frameworks/base/cmds/abx/src/com/android/commands/abx/Abx.java`

### 功能概述

`abx` 用于在 Android Binary XML (ABX) 和人类可读 XML 之间转换。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `abx [file]` | 读取 ABX 文件并输出 XML | 解析 ABX 格式 |
| `abx2xml` | ABX → XML 转换 | 同上 |
| `xml2abx` | XML → ABX 转换 | 将 XML 编译为 ABX |

---

## 25. `device_config` — 设备配置

**源码位置**: `frameworks/base/cmds/device_config/`

### 功能概述

`device_config` 用于管理设备配置（Device Config）。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `get` | 获取配置值 | DeviceConfig.getProperty() |
| `set` | 设置配置值 | DeviceConfig.setProperty() |
| `delete` | 删除配置 | DeviceConfig.deleteProperty() |
| `list` | 列出配置 | DeviceConfig.getProperties() |
| `reset` | 重置配置 | DeviceConfig.resetToDefaults() |

---

## 26. `dpm` — Device Policy Manager

**源码位置**: `frameworks/base/cmds/dpm/`

### 功能概述

`dpm` 用于管理设备策略。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `set-active-admin` | 设置活动管理员 | DevicePolicyManager.setActiveAdmin() |
| `set-device-owner` | 设置设备所有者 | DevicePolicyManager.setDeviceOwner() |
| `set-profile-owner` | 设置配置文件所有者 | DevicePolicyManager.setProfileOwner() |
| `clear-freeze-period-record` | 清除冻结记录 | DevicePolicyManager.clearFreezePeriodRecord() |

---

## 27. `incident` / `incidentd` / `incident_helper` — 事件报告

**源码位置**: `frameworks/base/cmds/incident/`, `incidentd/`, `incident_helper/`

### 功能概述

- `incident`: 触发事件报告
- `incidentd`: 事件报告守护进程
- `incident_helper`: 事件报告辅助工具

### 子命令详细分析

| 命令 | 功能 | 原理 |
|------|------|------|
| `incident [section]` | 触发指定 section 的事件报告 | IncidentManager.reportIncident() |
| `incidentd` | 事件报告守护进程 | 处理事件报告请求 |
| `incident_helper` | 辅助工具 | 提供各 section 的数据收集 |

---

## 28. `uiautomator` — UI Automator

**源码位置**: `frameworks/base/cmds/uiautomator/`

### 功能概述

`uiautomator` 是 UI 自动化测试框架。

### 子命令详细分析

| 子命令 | 功能 | 原理 |
|--------|------|------|
| `runtest` | 运行测试 | UiAutomatorInstrumentationTestRunner |
| `dump` | 转储 UI 层次结构 | UiDevice.dumpWindowHierarchy() |

---

## 29. `gpu_counter_producer` — GPU 计数器

**源码位置**: `frameworks/base/cmds/gpu_counter_producer/`

### 功能概述

`gpu_counter_producer` 用于 GPU 性能计数器数据采集。

---

## 30. `bootanimation` — 开机动画

**源码位置**: `frameworks/base/cmds/bootanimation/`

### 功能概述

`bootanimation` 是开机动画服务，播放开机动画视频。

### 关键机制

- **动画格式**: 使用 zip 包包含多段图片
- **显示**: 通过 SurfaceFlinger 显示
- **退出**: 在系统准备完成后退出

---

## 总结

| 命令 | 核心功能 | 交互方式 |
|------|----------|----------|
| `am` | Activity/服务/广播/进程管理 | IActivityManager.shellCommand() |
| `pm` | 包管理 | cmd package → PMS |
| `wm` | 窗口/显示管理 | cmd window → WMS |
| `input` | 输入注入 | cmd input → IMS |
| `svc` | 系统服务控制 | 直接 Binder 或 cmd 转发 |
| `content` | ContentProvider CRUD | IContentProvider 直接调用 |
| `dumpsys` | 服务状态转储 | IBinder.dump() |
| `dumpstate` | Bugreport 数据收集 | 调用各服务 dump |
| `settings` | 系统设置读写 | SettingsProvider |
| `cmd` | 通用命令分发 | ShellCommand 接口 |
| `sm` | 存储管理 | IStorageManager → vold |
| `bu` | 备份/恢复 | IBackupManager |
| `bmgr` | 备份传输管理 | IBackupManager |
| `ime` | 输入法管理 | InputMethodManagerService |
| `locksettings` | 锁屏设置 | LockSettingsService |
| `appops` | 应用操作权限 | AppOpsManager |
| `appwidget` | 应用小部件 | AppWidgetManagerService |
| `requestsync` | 同步请求 | ContentResolver |
| `hid` | HID 事件注入 | 虚拟 HID 设备 |
| `uinput` | 用户空间输入 | /dev/uinput |
| `vr` | VR 模式控制 | IVrManager |
| `screencap` | 屏幕截图 | SurfaceControl |
| `monkey` | 随机压力测试 | 伪随机事件生成 |
| `abx` | ABX/XML 转换 | 格式解析 |
| `device_config` | 设备配置 | DeviceConfig |
| `dpm` | 设备策略 | DevicePolicyManager |
| `incident` | 事件报告 | IncidentManager |
| `uiautomator` | UI 自动化测试 | Instrumentation |
| `bootanimation` | 开机动画 | SurfaceFlinger |
