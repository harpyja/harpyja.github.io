# Android 15 AOSP 系统服务功能与交互逻辑分析

> 生成日期: 2026-07-24  
> 基于: Android 15 AOSP 源码

---

## 文档说明

本文档分析 Android 15 AOSP 中所有系统服务的**功能概述**、**工作原理**、**App 交互逻辑**，并补充说明：
- App 中 Manifest 权限声明在 service 端的实际功效
- Service 是否验证 Binder 对端权限
- SELinux 权限上下文
- `IBinder::transact()` 和 `IBinder::shellCommand()` 的调用可行性

---

## 一、Framework Java 服务 (运行于 system_server)

### 1.1 AccessibilityManagerService (无障碍服务)

**功能概述**: 管理系统中所有无障碍服务的注册、启用、事件分发。为视觉/听觉障碍用户提供屏幕读取、放大、语音控制等辅助能力。

**工作原理**:
- 注册为 `Context.ACCESSIBILITY_SERVICE`，运行于 `system_server` 进程
- 维护 `AccessibilityServiceConnection` 列表，每个已启用服务一个连接
- 通过 `AccessibilityInteractionConnection` 允许服务获取窗口内容（受 `RETRIEVE_WINDOW_CONTENT` 权限约束）
- 使用 `Binder.clearCallingIdentity()` 在服务回调时临时提升权限
- 当应用的无障碍服务被启用时，系统通过 `UserManagerService` 管理每个用户的启用状态
- 事件分发采用异步机制，通过 `sendAccessibilityEvent()` 广播给所有已连接的无障碍服务

**App 交互流程**:
```
App (无障碍服务端)
  ├── AndroidManifest.xml 声明:
  │   <service android:name=".MyAccessibilityService"
  │       android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
  │       <intent-filter>
  │           <action android:name="android.accessibilityservice.AccessibilityService"/>
  │       </intent-filter>
  │       <meta-data android:name="android.accessibilityservice"
  │           android:resource="@xml/accessibility_config"/>
  │   </service>
  │
  ├── 系统绑定服务时检查 BIND_ACCESSIBILITY_SERVICE 权限
  │   → 只有系统（system_server）可以绑定，普通 App 无法伪造
  │
  ├── 服务连接后通过 IAccessibilityInteractionConnection 获取窗口内容
  │   → 需要 RETRIEVE_WINDOW_CONTENT 权限
  │   → 通过 AccessibilityNodeInfo 遍历窗口树
  │
  └── 通过 performAction() 执行操作（点击、滚动等）
      → 需要服务已被用户在设置中手动启用

App (普通应用端)
  ├── AccessibilityManager am = getSystemService(ACCESSIBILITY_SERVICE);
  ├── am.getInstalledAccessibilityList() — 无需权限
  ├── am.getEnabledAccessibilityServiceList() — 无需权限
  ├── am.interrupt() — 无需权限
  └── am.sendAccessibilityEvent(event) — 无需权限（内部 API）
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `BIND_ACCESSIBILITY_SERVICE` | 无障碍服务的 manifest | **强制**：只有 system_server 可以绑定该服务，防止恶意应用绑定 |
| `RETRIEVE_WINDOW_CONTENT` | 调用 getWindowToken/registerUiTestAutomationService | **强制**：控制是否允许获取窗口内容 |
| `MANAGE_ACCESSIBILITY` | 调用 registerSystemAction 等 | **强制**：控制是否允许管理无障碍服务 |

**Binder 权限验证**:
- `enforceCallingOrSelfPermission(MANAGE_BIND_INSTANT_SERVICE)` — 设置即时服务绑定
- `@EnforcePermission(MANAGE_ACCESSIBILITY)` — 注册/注销系统动作
- `@EnforcePermission(RETRIEVE_WINDOW_CONTENT)` — 获取窗口令牌、注册 UI 测试服务
- `Binder.getCallingUid()` 用于跟踪调用方身份
- `OWNER_PROCESS_ID` 检查防止进程内伪造

**SELinux**: 运行于 `system_server` 域（`u:r:system_server:s0`），属于 `mlstrustedsubject`

**transact 调用可行性**:
- `getInstalledAccessibilityServiceList()`, `getEnabledAccessibilityServiceList()`, `interrupt()`, `sendAccessibilityEvent()` 标注 `@RequiresNoPermission`，可通过 transact 直接调用
- 敏感方法（如 `getWindowToken`）有 `RETRIEVE_WINDOW_CONTENT` 权限检查，但 transact 绕过 Java 层需 SELinux 策略配合
- 窗口内容获取受 `AccessibilityInteractionConnection` 二次校验

**shellCommand 调用可行性**:
- `onShellCommand()` → `AccessibilityShellCommand`，仅 `SHELL_UID` 可调用
- `dump()` 输出服务状态信息

---

### 1.2 AutofillManagerService (自动填充服务)

**功能概述**: 管理自动填充框架，协调应用与自动填充服务（如密码管理器）之间的交互。

**工作原理**:
- 注册为 `AUTOFILL_MANAGER_SERVICE`
- 使用 `MasterSystemService` 模式，按用户维护服务实例
- 通过 `AutofillServiceConnection` 绑定到第三方自动填充服务
- 维护填充会话状态机：`SESSION_STARTING → SESSION_ACTIVE → SESSION_FINISHED`
- 通过 `FieldClassificationAlgorithm` 进行字段分类

**App 交互流程**:
```
App (客户端)
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── AutofillManager afm = getSystemService(AutofillManager.class);
  ├── afm.isEnabled() — 查询是否启用，无需权限
  ├── afm.requestAutofill(view) — 请求填充，无需权限
  ├── afm.cancel() — 取消填充会话，无需权限
  └── afm.commit() — 提交填充结果，无需权限

App (填充服务端)
  ├── AndroidManifest.xml 声明:
  │   <service android:name=".MyAutofillService"
  │       android:permission="android.permission.BIND_AUTOFILL_SERVICE">
  │       <intent-filter>
  │           <action android:name="android.service.autofill.AutofillService"/>
  │       </intent-filter>
  │   </service>
  │
  ├── 系统绑定服务时检查 BIND_AUTOFILL_SERVICE 权限
  │
  ├── onFillRequest() 接收填充请求
  │   → 返回 FillResponse 包含数据集
  │
  └── onSaveRequest() 接收保存请求
      → 处理用户数据保存
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `BIND_AUTOFILL_SERVICE` | 填充服务的 manifest | **强制**：只有 system_server 可以绑定 |
| `MANAGE_AUTO_FILL` | 管理方法调用 | **强制**：控制调试/管理方法 |

**Binder 权限验证**:
- 所有管理方法调用 `enforceCallingPermissionForManagement()` 检查 `MANAGE_AUTO_FILL`
- 普通填充交互方法无显式权限检查（依赖框架层 UID 匹配）

**SELinux**: `system_server` 域

**transact 调用可行性**: 填充交互方法（如 `setAutofillOptions`）通常不需要权限但依赖 UID 匹配

**shellCommand 调用可行性**: 无专用 shellCommand

---

### 1.3 BackupManagerService (备份服务)

**功能概述**: 管理应用数据的备份和恢复，与备份传输服务交互。

**原理**:
- 注册为 `Context.BACKUP_SERVICE`
- 维护备份队列、传输连接
- 使用 `BackgroundThread` 处理异步操作
- 通过 `BackupManagerServiceInterface` 与传输服务通信

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │   → 可选: android:backupAgent 声明备份代理
  │
  ├── BackupManager bm = new BackupManager(context);
  ├── bm.dataChanged() — 请求备份，无需权限
  │   → Service 端: 加入备份队列，等待传输服务执行
  │
  ├── bm.requestRestore(observer) — 请求恢复
  │   → Service 端: 需要 BACKUP 权限
  │
  └── 系统调用备份代理:
      ├── onBackup() — 提供备份数据
      └── onRestore() — 接收恢复数据
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `android.permission.BACKUP` | 调用 requestRestore | **强制**：控制备份/恢复操作 |
| `INTERACT_ACROSS_USERS_FULL` | 跨用户操作 | **强制**：控制跨用户备份 |

**Binder 权限验证**:
- `enforcePermissionsOnUser()` 检查 `BACKUP` 权限
- `Process.SYSTEM_UID` 和 `Process.ROOT_UID` 显式检查用于 `setBackupServiceActive()`

**SELinux**: `system_server` 域

**transact 调用可行性**: `isBackupServiceActive()` 需要 `BACKUP` 权限；`dataChanged()` 等轻量方法可能无需权限

**shellCommand 调用可行性**: 无

---

### 1.4 PrintManagerService (打印服务)

**功能概述**: 管理系统打印功能，协调打印作业与打印服务之间的交互。

**原理**:
- 注册为 `Context.PRINT_SERVICE`
- 维护打印作业队列、打印服务发现
- 通过 `RemotePrintService` 绑定到第三方打印服务

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── PrintManager pm = getSystemService(PRINT_SERVICE);
  ├── pm.getPrintServices() — 需要 READ_PRINT_SERVICES
  ├── pm.print("job", adapter, hints) — 创建打印作业
  │   → Service 端: 创建 PrintJob，绑定到打印服务
  │   → 打印服务: 通过 PrintDocumentAdapter 获取内容
  │
  └── PrintJob job = ...;
      job.cancel() — 取消作业
      job.restart() — 重启作业
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `READ_PRINT_SERVICES` (normal) | 获取打印服务列表 | **强制**：控制打印服务发现 |
| `READ_PRINT_SERVICE_RECOMMENDATIONS` (normal) | 获取推荐 | **强制**：控制推荐访问 |
| `ACCESS_ALL_PRINT_JOBS` (system) | 访问所有打印作业 | **强制**：控制作业访问范围 |

**Binder 权限验证**:
- `enforceCallingOrSelfPermission` 用于读取权限检查
- `SHELL_UID` 和 `ROOT_UID` 检查允许 shell 访问所有打印作业

**SELinux**: `system_server` 域

**transact 调用可行性**: `getPrintServices()` 需要 normal 级权限；`print()` 本身无显式权限检查

**shellCommand 调用可行性**: `onShellCommand()` → `PrintShellCommand`

---

### 1.5 UsbService (USB 服务)

**功能概述**: 管理 USB 设备/配件模式、端口角色切换、权限授予。

**原理**:
- 注册为 `Context.USB_SERVICE`
- 管理 USB 设备连接、配件模式切换
- 维护每个应用的 USB 权限状态
- 通过 `UsbDeviceManager` 与底层通信

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-feature android:name="android.hardware.usb.host"/>
  │   → 或 android:hardware.usb.accessory
  │
  ├── UsbManager um = getSystemService(USB_SERVICE);
  ├── HashMap<String, UsbDevice> devices = um.getDeviceList();
  │   → 无需权限，返回已连接设备列表
  │
  ├── um.hasPermission(device) — 检查是否有设备权限
  ├── um.requestPermission(device, pi) — 请求权限（弹出系统对话框）
  │   → Service 端: 显示权限对话框，用户选择后持久化权限
  │
  ├── UsbDeviceConnection conn = um.openDevice(device);
  │   → 需要权限，否则抛出 SecurityException
  │
  ├── conn.controlTransfer() / conn.bulkTransfer() — 数据传输
  │
  └── 配件模式:
      ├── UsbAccessory[] accessories = um.getAccessoryList();
      └── ParcelFileDescriptor pfd = um.openAccessory(accessory);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_USB` (privileged) | 设置功能、授予权限、端口角色 | **强制**：控制 USB 管理操作 |
| `ACCESS_MTP` (normal) | 获取 MTP 控制 FD | **强制**：控制 MTP 访问 |

**Binder 权限验证**:
- `@EnforcePermission(MANAGE_USB)` 用于敏感 USB 控制方法
- `enforceCallingOrSelfPermission(MANAGE_USB)` 用于权限/偏好管理方法

**SELinux**: `system_server` 域

**transact 调用可行性**: `getDeviceList()` 等方法无显式权限要求；控制方法需要 `MANAGE_USB`

**shellCommand 调用可行性**: `dump()` 处理 shell 命令，包含 `reset-port` 等敏感操作

---

### 1.6 WifiServiceImpl (WiFi 服务)

**功能概述**: 管理 WiFi 连接、热点、网络配置、扫描等。

**原理**:
- 注册为 `Context.WIFI_SERVICE`
- 通过 `WifiStateMachine` / `ClientModeImpl` 管理连接状态
- 维护网络配置、扫描结果缓存
- 通过 `WifiNative` 与 wpa_supplicant 通信

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
  │   <uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
  │
  ├── WifiManager wm = getSystemService(WIFI_STATE_SERVICE);
  │
  ├── 读取操作（需 ACCESS_WIFI_STATE）:
  │   ├── wm.getConnectionInfo() — 获取连接信息
  │   ├── wm.getScanResults() — 获取扫描结果
  │   └── wm.getConfiguredNetworks() — 获取已配置网络
  │
  ├── 写入操作（需 CHANGE_WIFI_STATE）:
  │   ├── wm.setWifiEnabled(true) — 启用 WiFi
  │   ├── wm.addNetwork(config) — 添加网络配置
  │   ├── wm.enableNetwork(netId, true) — 连接网络
  │   └── wm.disconnect() — 断开连接
  │
  ├── 高级操作（需 NETWORK_SETTINGS）:
  │   ├── wm.getPrivilegedConfiguredNetworks()
  │   ├── wm.getFactoryMacAddress()
  │   └── wm.restartWifiSubsystem()
  │
  └── 热点操作:
      ├── wm.startLocalOnlyHotspot(callback) — 本地热点
      └── wm.startTethering(type, executor, callback) — 网络共享
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `ACCESS_WIFI_STATE` (normal) | 读取 WiFi 状态 | **强制**：控制状态读取 |
| `CHANGE_WIFI_STATE` (normal) | 修改 WiFi 配置 | **强制**：控制配置修改 |
| `NETWORK_SETTINGS` (privileged) | 高级网络配置 | **强制**：控制高级操作 |
| `RESTART_WIFI_SUBSYSTEM` (privileged) | 重启 WiFi 子系统 | **强制**：控制子系统重启 |
| `READ_WIFI_CREDENTIAL` (privileged) | 读取 WiFi 凭证 | **强制**：控制凭证读取 |

**Binder 权限验证**:
- 每个方法都有对应的 `enforceCallingOrSelfPermission` 检查
- `Binder.getCallingUid()` 大量使用 (100+ 处) 用于 UID 匹配
- `Process.SHELL_UID` 和 `Process.ROOT_UID` 特殊处理
- `mAppOps.checkPackage` 用于包名验证

**SELinux**: `system_server` 域

**transact 调用可行性**: `getScanResults()`, `getConnectionInfo()` 需要 normal 级权限；高级方法需要 `NETWORK_SETTINGS`

**shellCommand 调用可行性**: WiFi shell 命令通过 `WifiShellCommand` 实现

---

### 1.7 PermissionManagerService (权限管理服务)

**功能概述**: 管理系统中所有运行时权限的授予、撤销、查询。

**原理**:
- 注册为 `"permissionmgr"` 和 `"permission_checker"`
- 维护权限状态数据库
- 协调权限请求 UI 流程
- 通过 `PermissionRegistry` 管理所有权限定义

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.CAMERA"/>
  │   → 声明需要的运行时权限
  │
  ├── 请求权限:
  │   ActivityCompat.requestPermissions(this, 
  │       new String[]{Manifest.permission.CAMERA}, REQUEST_CODE);
  │   → Service 端: 检查权限状态，如未授予则显示系统对话框
  │   → 用户选择后更新权限状态数据库
  │
  ├── 查询权限:
  │   PackageManager pm = getPackageManager();
  │   int result = pm.checkPermission(CAMERA, packageName);
  │   → Service 端: 查询权限状态数据库
  │
  └── 直接操作（需特殊权限）:
      ├── pm.grantRuntimePermission(pkg, perm, user)
      └── pm.revokeRuntimePermission(pkg, perm, user)
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `ADJUST_RUNTIME_PERMISSIONS_POLICY` (system) | 调整权限策略 | **强制**：控制策略调整 |
| `UPDATE_APP_OPS_STATS` (system/privileged) | 更新 app ops 统计 | **强制**：控制统计更新 |

**Binder 权限验证**:
- `enforceCallingPermission(ADJUST_RUNTIME_PERMISSIONS_POLICY)` 用于策略调整
- `enforceCallingOrSelfPermission(UPDATE_APP_OPS_STATS)` 用于统计
- `Process.SYSTEM_UID` 检查

**SELinux**: `system_server` 域

**transact 调用可行性**: 权限查询方法通常不需要特殊权限；`grantRuntimePermission()` 等有 UID 和权限级别检查

**shellCommand 调用可行性**: 可通过 `adb shell pm grant/revoke` 操作

---

### 1.8 DevicePolicyManagerService (设备策略管理服务)

**功能概述**: 管理设备管理员策略、配置设备所有者/资料所有者。

**原理**:
- 注册为 `Context.DEVICE_POLICY_SERVICE`
- 维护每个用户的策略状态
- 协调与系统各组件的策略执行
- 通过 `DevicePolicyEngine` 管理策略规则

**App 交互流程**:
```
App (设备管理员)
  ├── AndroidManifest.xml:
  │   <receiver android:name=".MyDeviceAdminReceiver"
  │       android:permission="android.permission.BIND_DEVICE_ADMIN">
  │       <meta-data android:name="android.app.device_admin"
  │           android:resource="@xml/device_admin_policies"/>
  │       <intent-filter>
  │           <action android:name="android.app.action.DEVICE_ADMIN_ENABLED"/>
  │       </intent-filter>
  │   </receiver>
  │
  ├── DevicePolicyManager dpm = getSystemService(DEVICE_POLICY_SERVICE);
  │
  ├── 检查状态:
  │   ├── dpm.isAdminActive(admin) — 检查是否为活跃管理员
  │   ├── dpm.isDeviceOwnerApp(pkg) — 检查是否为设备所有者
  │   └── dpm.isProfileOwnerApp(pkg) — 检查是否为资料所有者
  │
  ├── 策略设置（需对应 MANAGE_DEVICE_POLICY_* 权限）:
  │   ├── dpm.setPasswordQuality(admin, quality) — 设置密码质量
  │   ├── dpm.setCameraDisabled(admin, disabled) — 禁用摄像头
  │   ├── dpm.lockNow() — 锁定设备
  │   ├── dpm.wipeData(flags) — 恢复出厂设置
  │   └── dpm.setApplicationHidden(admin, pkg, hidden) — 隐藏应用
  │
  └── 策略执行:
      └── 系统各组件查询 DPMS 获取策略状态
          → 如: Keyguard 检查密码质量要求
          → 如: Camera 检查是否被策略禁用
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `BIND_DEVICE_ADMIN` | 设备管理员 receiver | **强制**：只有系统可以激活设备管理员 |
| `MANAGE_PROFILE_AND_DEVICE_OWNERS` (system) | 管理所有者 | **强制**：控制所有者管理 |
| `MANAGE_DEVICE_POLICY_*` (60+ 权限) | 精细策略控制 | **强制**：每个策略域一个权限 |
| `LOCK_DEVICE` (privileged) | 锁定设备 | **强制**：控制锁屏操作 |
| `SET_TIME` / `SET_TIME_ZONE` (privileged) | 设置时间 | **强制**：控制时间设置 |
| `MASTER_CLEAR` (system) | 恢复出厂设置 | **强制**：控制清除操作 |

**Binder 权限验证**:
- `checkCallingPermission()` 用于 60+ 个 `MANAGE_DEVICE_POLICY_*` 权限
- `Process.SYSTEM_UID` 检查
- `Process.SHELL_UID` 检查
- 基于 DPM 模型的复杂策略检查

**SELinux**: `system_server` 域

**transact 调用可行性**: `isAdminActive()` 等查询方法需要 `BIND_DEVICE_ADMIN`；策略设置需要对应 `MANAGE_DEVICE_POLICY_*` 权限

**shellCommand 调用可行性**: `onShellCommand()` → DPM shell 命令

---

### 1.9 VoiceInteractionManagerService (语音交互服务)

**功能概述**: 管理语音交互服务（如 Google Assistant）的注册、激活和事件分发。

**原理**:
- 注册为 `Context.VOICE_INTERACTION_MANAGER_SERVICE`
- 维护当前活跃的语音交互会话
- 协调麦克风/摄像头资源的独占访问
- 通过 `VoiceInteractionSession` 管理交互流程

**App 交互流程**:
```
App (语音交互服务)
  ├── AndroidManifest.xml:
  │   <service android:name=".MyVoiceInteractionService"
  │       android:permission="android.permission.BIND_VOICE_INTERACTION">
  │       <meta-data android:name="android.voice_interaction"
  │           android:resource="@xml/voice_interaction_service"/>
  │       <intent-filter>
  │           <action android:name="android.service.voice.VoiceInteractionService"/>
  │       </intent-filter>
  │   </service>
  │
  ├── 系统绑定服务时检查 BIND_VOICE_INTERACTION 权限
  │
  ├── onReady() — 服务就绪
  ├── onCreateSession() — 创建交互会话
  │   → 进入 VoiceInteractionSession
  │
  ├── 会话中:
  │   ├── onShow(args, showFlags) — 显示 UI
  │   ├── onHide() — 隐藏 UI
  │   ├── onLockscreenShown() — 锁屏显示
  │   └── finishSession() — 结束会话
  │
  └── 需要 RECORD_AUDIO + CAPTURE_AUDIO_HOTWORD 权限

App (普通应用)
  ├── 启动语音交互:
  │   Intent intent = new Intent(Intent.ACTION_VOICE_COMMAND);
  │   startActivity(intent);
  │
  └── VoiceInteractionManager vim = getSystemService(VOICE_INTERACTION_MANAGER_SERVICE);
      └── vim.startSession(args) — 启动会话
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `BIND_VOICE_INTERACTION` | 语音交互服务 | **强制**：控制服务绑定 |
| `RECORD_AUDIO` (dangerous) | 录音访问 | **强制**：控制录音 |
| `CAMERA` (dangerous) | 摄像头访问 | **强制**：控制摄像头 |
| `CAPTURE_AUDIO_HOTWORD` (privileged) | 热词检测 | **强制**：控制热词检测 |
| `MANAGE_VOICE_KEYPHRASES` (privileged) | 管理快捷键 | **强制**：控制快捷键管理 |

**Binder 权限验证**:
- `enforceCallingPermission` 用于 `RECORD_AUDIO`, `CAMERA` 等
- `Binder.getCallingUid()` 大量使用

**SELinux**: `system_server` 域

**transact 调用可行性**: 启动语音交互需要 `RECORD_AUDIO` + `CAMERA`；`createSoundTriggerSession()` 需要 `CAPTURE_AUDIO_HOTWORD`

**shellCommand 调用可行性**: `onShellCommand()` → VoiceInteraction shell 命令

---

### 1.10 UsageStatsService (使用情况统计服务)

**功能概述**: 收集和管理应用使用情况统计，包括使用时长、频率、最后使用时间等。

**原理**:
- 注册为 `Context.USAGE_STATS_SERVICE`
- 维护基于用户的使用统计数据库
- 使用 `UsageStatsManagerInternal` 内部接口
- 通过 `UsageStatsXml` 持久化数据

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"/>
  │   → 特殊权限，需用户在设置中手动授权
  │
  ├── UsageStatsManager usm = getSystemService(USAGE_STATS_SERVICE);
  │
  ├── 查询统计（需 PACKAGE_USAGE_STATS）:
  │   ├── usm.queryUsageStats(interval, begin, end)
  │   │   → 返回使用统计列表
  │   ├── usm.queryEvents(begin, end)
  │   │   → 返回事件列表
  │   └── usm.queryEventStats(interval, begin, end)
  │       → 返回事件统计
  │
  ├── 观察应用使用（需 OBSERVE_APP_USAGE）:
  │   ├── usm.registerAppUsageObserver(...)
  │   └── usm.unregisterAppUsageObserver(...)
  │
  └── 控制操作:
      ├── usm.setAppInactive(pkg, inactive) — 设置应用非活跃
      └── usm.setAppStandbyBucket(pkg, bucket) — 设置待机分组
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `PACKAGE_USAGE_STATS` (special/appop) | 查询使用统计 | **强制**：需用户在设置中授权 |
| `REPORT_USAGE_STATS` (privileged) | 报告使用情况 | **强制**：控制报告 |
| `OBSERVE_APP_USAGE` (privileged) | 观察应用使用 | **强制**：控制观察 |

**Binder 权限验证**:
- `checkCallingPermission` 用于 `PACKAGE_USAGE_STATS`, `REPORT_USAGE_STATS`, `OBSERVE_APP_USAGE`
- `enforceCallingPermission` 用于配置方法
- `Process.SYSTEM_UID` 检查

**SELinux**: `system_server` 域

**transact 调用可行性**: `queryUsageStats()` 需要 `PACKAGE_USAGE_STATS`（特殊权限）

**shellCommand 调用可行性**: 无

---

### 1.11 RestrictionsManagerService (限制管理服务)

**功能概述**: 管理系统限制（如家长控制、企业限制），允许临时管理者设置和查询限制。

**原理**:
- 注册为 `Context.RESTRICTIONS_SERVICE`
- 维护限制键值对，按用户存储
- 广播限制变化事件
- 通过 `Bundle` 存储限制数据

**App 交互流程**:
```
App (临时管理者)
  ├── AndroidManifest.xml:
  │   <receiver android:name=".MyRestrictionsReceiver"
  │       android:permission="android.permission.BIND_DEVICE_ADMIN">
  │       ...
  │   </receiver>
  │
  ├── RestrictionsManager rm = getSystemService(RESTRICTIONS_SERVICE);
  │
  ├── 请求成为临时管理者:
  │   Intent intent = rm.createLocalApprovalIntent();
  │   startActivityForResult(intent, REQUEST_ID);
  │   → 系统显示确认对话框，用户授权后成为临时管理者
  │
  ├── 设置限制:
  │   Bundle restrictions = new Bundle();
  │   restrictions.putString("key", "value");
  │   rm.setRestrictions(restrictions);
  │   → Service 端: 存储限制，广播变化
  │
  └── 查询限制:
      └── Bundle current = rm.getRestrictions();

App (普通应用)
  ├── 查询限制:
  │   Bundle restrictions = rm.getManifestRestrictions(permission);
  │   → 返回当前生效的限制
  │
  └── 处理限制变化:
      └── 注册 BroadcastReceiver 监听 ACTION_RESTRICTIONS_CHANGED
```

**Manifest 权限功效**: 无特殊权限要求

**Binder 权限验证**: `Binder.getCallingUid()` 用于跟踪

**SELinux**: `system_server` 域

**transact 调用可行性**: 查询方法无严格权限限制；设置限制需要成为临时管理者

**shellCommand 调用可行性**: 无

---

### 1.12 CompanionDeviceManagerService (伴侣设备管理服务)

**功能概述**: 管理伴侣设备（如智能手表）的关联、发现和消息传递。

**原理**:
- 注册为 `Context.COMPANION_DEVICE_SERVICE`
- 维护设备关联列表
- 协调 BLE/蓝牙/WiFi 设备发现
- 通过 `CompanionDeviceAssociation` 管理关联

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.REQUEST_COMPANION_START_FOREGROUND_SERVICES_FROM_BACKGROUND"/>
  │
  ├── CompanionDeviceManager cdm = getSystemService(COMPANION_DEVICE_SERVICE);
  │
  ├── 设备发现:
  │   ├── cdm.associate(matcher, callback, handler)
  │   │   → Service 端: 启动 BLE/蓝牙/WiFi 扫描
  │   │   → 发现设备后显示系统对话框供用户选择
  │   │   → 用户确认后建立关联
  │   │
  │   └── DeviceFilter<BluetoothDevice> matcher = ...;
  │       → 过滤特定类型设备
  │
  ├── 管理关联:
  │   ├── cdm.getAssociations() — 获取已关联设备
  │   ├── cdm.disassociate(macAddress) — 取消关联
  │   └── cdm.dispatchMessage(systemId, assocId, message) — 发送消息
  │
  └── 自管理设备（需 REQUEST_COMPANION_SELF_MANAGED）:
      ├── cdm.associate(request, executor, callback)
      └── 无需用户确认即可关联
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_COMPANION_DEVICES` (privileged) | 管理设备关联 | **强制**：控制关联管理 |
| `USE_COMPANION_TRANSPORTS` (privileged) | 使用传输 | **强制**：控制传输使用 |
| `REQUEST_OBSERVE_COMPANION_DEVICE_PRESENCE` (privileged) | 观察存在 | **强制**：控制存在观察 |
| `BLUETOOTH_CONNECT` (dangerous) | 蓝牙连接 | **强制**：控制蓝牙 |
| `DELIVER_COMPANION_MESSAGES` (privileged) | 传递消息 | **强制**：控制消息传递 |
| `REQUEST_COMPANION_SELF_MANAGED` (privileged) | 自管理设备 | **强制**：控制自管理 |

**Binder 权限验证**:
- `@EnforcePermission` 用于多数方法
- `getCallingUid()` + `SYSTEM_UID` 检查

**SELinux**: `system_server` 域

**transact 调用可行性**: 设备发现/关联需要多种权限；自管理设备路径可能有较大攻击面

**shellCommand 调用可行性**: `dump()`

---

### 1.13 TextToSpeechManagerService (文字转语音服务)

**功能概述**: 管理 TTS 引擎的注册和语音合成。

**原理**:
- 注册为 `Context.TEXT_TO_SPEECH_MANAGER_SERVICE`
- 维护 TTS 引擎连接
- 通过 `TextToSpeech` 类与引擎通信

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── TextToSpeech tts = new TextToSpeech(context, listener);
  │   → Service 端: 绑定到默认 TTS 引擎
  │   → 引擎就绪后回调 onInit()
  │
  ├── tts.speak("text", QUEUE_FLUSH, null, "utteranceId");
  │   → Service 端: 将文本发送给 TTS 引擎
  │   → 引擎合成音频后通过 AudioTrack 播放
  │
  ├── tts.stop() — 停止合成
  ├── tts.setLanguage(Locale.US) — 设置语言
  ├── tts.setSpeechRate(1.0f) — 设置语速
  └── tts.shutdown() — 释放资源
```

**Manifest 权限功效**: 无特殊权限要求

**Binder 权限验证**: 最小权限检查

**SELinux**: `system_server` 域

**transact 调用可行性**: TTS 操作无严格权限限制

**shellCommand 调用可行性**: 无

---

### 1.14 CredentialManagerService (凭证管理服务)

**功能概述**: 管理凭证的创建、存储和检索（Android 14+ 新 API）。

**原理**:
- 注册为 `CREDENTIAL_SERVICE`
- 协调应用与凭证提供者之间的交互
- 通过 `CredentialProviderService` 绑定到提供者

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── CredentialManager cm = getSystemService(CredentialManager.class);
  │
  ├── 获取凭证:
  │   GetCredentialRequest request = new GetCredentialRequest.Builder()
  │       .addCredentialOption(new PublicKeyCredentialOption(...))
  │       .build();
  │   cm.getCredential(request, activity, executor, callback);
  │   → Service 端: 查询可用的凭证提供者
  │   → 显示系统选择器供用户选择
  │   → 用户选择后从提供者获取凭证
  │
  ├── 创建凭证:
  │   CreateCredentialRequest request = ...;
  │   cm.createCredential(request, activity, executor, callback);
  │   → Service 端: 将请求转发给凭证提供者
  │   → 提供者创建凭证后返回
  │
  └── 清除凭证:
      cm.clearCredentialState(request, executor, callback);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `CREDENTIAL_MANAGER_SET_ORIGIN` (privileged) | 设置凭证来源 | **强制**：控制来源设置 |
| `CREDENTIAL_MANAGER_SET_ALLOWED_PROVIDERS` (privileged) | 设置允许提供者 | **强制**：控制提供者设置 |

**Binder 权限验证**:
- `enforceCallingPermission` 用于 `CREDENTIAL_MANAGER_SET_ORIGIN`, `CREDENTIAL_MANAGER_SET_ALLOWED_PROVIDERS`
- `Binder.getCallingUid()` 大量使用

**SELinux**: `system_server` 域

**transact 调用可行性**: 凭证获取/创建流程有复杂的多方验证；设置方法需要 system 权限

**shellCommand 调用可行性**: 无

---

### 1.15 AppPredictionManagerService (应用预测服务)

**功能概述**: 管理应用预测目标（如 dock 预测、分享目标预测）。

**原理**:
- 注册为 `APP_PREDICTION_SERVICE`
- 协调应用与预测服务
- 通过 `AppPredictionSession` 管理预测会话

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── AppPredictionManager apm = getSystemService(AppPredictionManager.class);
  │
  ├── 创建预测会话:
  │   AppPredictionSession session = apm.createAppPredictionSession(
  │       new AppPredictionContext.Builder().build());
  │   → Service 端: 创建会话，绑定到预测服务
  │
  ├── 请求预测:
  │   session.requestPredictionUpdate();
  │   → Service 端: 通知预测服务更新预测
  │   → 预测结果通过回调返回
  │
  ├── 管理预测目标:
  │   session.predictTargets(targets);
  │   → 上报用户选择的目标
  │
  └── session.destroy();
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_APP_PREDICTIONS` (privileged) | 管理方法 | **强制**：控制管理操作 |
| `PACKAGE_USAGE_STATS` (special) | 访问使用统计 | **强制**：控制统计访问 |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_APP_PREDICTIONS`
- `Binder.getCallingUid()` + `SYSTEM_UID` 检查

**SELinux**: `system_server` 域

**transact 调用可行性**: 预测更新等方法无严格权限限制

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.16 ContentCaptureManagerService (内容捕获服务)

**功能概述**: 管理内容捕获（如截屏内容分析、自动填充数据源）。

**原理**:
- 注册为 `CONTENT_CAPTURE_MANAGER_SERVICE`
- 协调应用与内容捕获服务
- 通过 `ContentCaptureSession` 管理捕获会话

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── View view = findViewById(R.id.my_view);
  │
  ├── 启用/禁用内容捕获:
  │   view.setContentCaptureEnabled(false);
  │   → Service 端: 控制是否向捕获服务发送事件
  │
  ├── 内容捕获流程:
  │   1. 系统创建 ContentCaptureSession
  │   2. View 事件（滚动、文本变化）发送给捕获服务
  │   3. 捕获服务分析内容，提供建议/自动填充数据
  │
  └── 自定义捕获:
      view.setContentCaptureContext(builder.build());
      → 设置额外的捕获上下文
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_CONTENT_CAPTURE` (privileged) | 管理方法 | **强制**：控制管理操作 |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_CONTENT_CAPTURE`

**SELinux**: `system_server` 域

**transact 调用可行性**: 查询方法无严格权限限制

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.17 MusicRecognitionManagerService (音乐识别服务)

**功能概述**: 管理音乐识别（如 Now Playing）功能。

**原理**:
- 注册为 `MUSIC_RECOGNITION_SERVICE`
- 协调音乐识别请求和处理
- 通过 `MusicRecognitionManager` 管理识别

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.RECORD_MICROPHONE"/>
  │
  ├── MusicRecognitionManager mrm = getSystemService(MusicRecognitionManager.class);
  │
  ├── 触发识别:
  │   mrm.beginRecognition(request, executor, callback);
  │   → Service 端: 启动麦克风录音
  │   → 将音频发送给识别服务
  │   → 识别结果通过回调返回
  │
  └── 识别结果:
      callback.onTrackRecognized(result);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_MUSIC_RECOGNITION` (privileged) | 管理方法 | **强制**：控制管理操作 |
| `MICROPHONE` (manifest) | 访问麦克风 | **强制**：控制麦克风访问 |

**Binder 权限验证**:
- `checkCallingPermission(MANAGE_MUSIC_RECOGNITION)` 用于查询
- `enforceCallingPermissionForManagement()` 用于管理

**SELinux**: `system_server` 域

**transact 调用可行性**: 识别请求无严格权限限制

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.18 TranslationManagerService (翻译服务)

**功能概述**: 管理 UI 翻译和文本翻译。

**原理**:
- 注册为 `TRANSLATION_MANAGER_SERVICE`
- 协调翻译服务
- 通过 `TranslationContext` 管理翻译上下文

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── TranslationManager tm = getSystemService(TranslationManager.class);
  │
  ├── 创建翻译上下文:
  │   TranslationContext context = tm.createTranslationContext(
  │       sourceSpec, targetSpec, 0);
  │   → Service 端: 创建翻译会话
  │
  ├── 翻译 UI:
  │   tm.requestUiTranslation(source, executor, callback);
  │   → Service 端: 提取 UI 文本
  │   → 发送给翻译服务
  │   → 翻译结果通过回调返回
  │
  └── 翻译文本:
      tm.requestTranslation(request, executor, callback);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_UI_TRANSLATION` (privileged) | 管理方法 | **强制**：控制管理操作 |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_UI_TRANSLATION`

**SELinux**: `system_server` 域

**transact 调用可行性**: 翻译请求无严格权限限制

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.19 SmartspaceManagerService (智能空间服务)

**功能概述**: 管理智能空间（如锁屏卡片、气泡卡片）内容更新。

**原理**:
- 注册为 `SMARTSPACE_SERVICE`
- 协调智能空间卡片更新
- 通过 `SmartspaceSession` 管理会话

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── SmartspaceManager sm = getSystemService(SmartspaceManager.class);
  │
  ├── 创建智能空间会话:
  │   SmartspaceSession session = sm.createSession(
  │       new SmartspaceConfig.Builder(context, "surface").build());
  │   → Service 端: 创建会话
  │
  ├── 更新内容:
  │   session.notifySmartspaceEvent(event);
  │   → Service 端: 将事件发送给系统 UI
  │   → 系统 UI 显示卡片
  │
  └── session.close();
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_SMARTSPACE` (privileged) | 管理方法 | **强制**：控制管理操作 |
| `ACCESS_SMARTSPACE` (privileged) | 访问智能空间 | **强制**：控制访问 |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_SMARTSPACE`
- `checkCallingPermission` 用于访问控制

**SELinux**: `system_server` 域

**transact 调用可行性**: 卡片更新需要 `MANAGE_SMARTSPACE` 或 `ACCESS_SMARTSPACE`

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.20 SupervisionManagerService (监督模式服务)

**功能概述**: 管理家长控制/监督模式功能。

**原理**:
- 注册为 `SUPERVISION_SERVICE`
- 协调监督功能
- 通过 `SupervisionService` 管理监督状态

**App 交互流程**:
```
App (监督者)
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── SupervisionManager sm = getSystemService(SupervisionManager.class);
  │
  ├── 查询监督状态:
  │   boolean isSupervised = sm.isSupervisedUser();
  │
  └── 设置监督配置:
      sm.setSupervisionEnabled(enabled);
```

**Manifest 权限功效**: 无特殊权限要求

**Binder 权限验证**: 无显式权限检查

**SELinux**: `system_server` 域

**transact 调用可行性**: 监督功能方法无严格权限限制

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.21 SystemCaptionsManagerService (系统字幕服务)

**功能概述**: 管理系统字幕生成。

**原理**:
- 不发布 binder 服务（仅内部使用）
- 协调字幕生成
- 通过 `SystemCaptionsManager` 管理字幕

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── SystemCaptionsManager scm = getSystemService(SystemCaptionsManager.class);
  │
  ├── 查询字幕状态:
  │   CaptionStyle style = scm.getStyle();
  │   Locale locale = scm.getLocale();
  │
  └── 监听字幕变化:
      scm.addCaptioningChangeListener(executor, listener);
```

**Manifest 权限功效**: N/A

**Binder 权限验证**: N/A

**SELinux**: `system_server` 域

**transact 调用可行性**: 无 binder 服务，无法直接 transact

**shellCommand 调用可行性**: 无

---

### 1.22 WallpaperEffectsGenerationManagerService (壁纸效果生成服务)

**功能概述**: 管理壁纸效果生成（如动态壁纸特效）。

**原理**:
- 注册为 `WALLPAPER_EFFECTS_GENERATION_SERVICE`
- 协调壁纸效果生成
- 通过 `WallpaperEffectsGenerationManager` 管理效果

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── WallpaperEffectsGenerationManager wegm = 
  │       getSystemService(WallpaperEffectsGenerationManager.class);
  │
  ├── 生成壁纸效果:
  │   wegm.generateWallpaperEffects(request, executor, callback);
  │   → Service 端: 将请求发送给效果生成服务
  │   → 生成结果通过回调返回
  │
  └── 查询效果:
      wegm.getWallpaperEffects(request, executor, callback);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_WALLPAPER_EFFECTS_GENERATION` (privileged) | 管理方法 | **强制**：控制管理操作 |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_WALLPAPER_EFFECTS_GENERATION`

**SELinux**: `system_server` 域

**transact 调用可行性**: 效果生成方法无严格权限限制

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.23 AppFunctionManagerService (应用函数服务)

**功能概述**: 管理应用函数（Android 15 新 API，支持应用暴露可调用函数）。

**原理**:
- 注册为 `APP_FUNCTION_SERVICE`
- 协调应用函数的注册和调用
- 通过 `AppFunctionManager` 管理函数

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── AppFunctionManager afm = getSystemService(AppFunctionManager.class);
  │
  ├── 执行函数:
  │   afm.executeAppFunction(request, executor, callback);
  │   → Service 端: 查找函数实现
  │   → 调用函数并返回结果
  │
  ├── 管理函数:
  │   afm.setAppFunctionEnabled(pkg, functionId, enabled);
  │   → 启用/禁用特定函数
  │
  └── 查询函数:
      afm.isAppFunctionEnabled(pkg, functionId);
```

**Manifest 权限功效**: 无特殊权限要求（权限检查在 impl 层）

**Binder 权限验证**: 委托给 impl 层

**SELinux**: `system_server` 域

**transact 调用可行性**: 函数执行无严格 manifest 权限要求

**shellCommand 调用可行性**: 无

---

### 1.24 ContentSuggestionsManagerService (内容建议服务)

**功能概述**: 管理内容建议（如主屏幕建议）。

**原理**:
- 注册为内容建议服务
- 协调建议更新
- 通过 `ContentSuggestionsManager` 管理建议

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── ContentSuggestionsManager csm = 
  │       getSystemService(ContentSuggestionsManager.class);
  │
  ├── 创建建议会话:
  │   ContentSuggestionsSession session = csm.createSession(
  │       new ContentSuggestionsContext.Builder().build());
  │   → Service 端: 创建会话
  │
  ├── 请求建议:
  │   session.requestContentSuggestions(remoteAction, executor, callback);
  │   → Service 端: 将请求发送给建议服务
  │   → 建议结果通过回调返回
  │
  └── session.close();
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_CONTENT_SUGGESTIONS` (privileged) | 管理方法 | **强制**：控制管理操作 |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_CONTENT_SUGGESTIONS`
- `Process.SHELL_UID` 检查

**SELinux**: `system_server` 域

**transact 调用可行性**: 建议请求无严格权限限制

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.25 ContextualSearchManagerService (上下文搜索服务)

**功能概述**: 管理上下文搜索（如 Now on Tap/长按搜索）。

**原理**:
- 注册为 `CONTEXTUAL_SEARCH_SERVICE`
- 协调上下文搜索触发
- 通过 `ContextualSearchManager` 管理搜索

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── ContextualSearchManager csm = 
  │       getSystemService(ContextualSearchManager.class);
  │
  ├── 触发搜索:
  │   csm.startSession();
  │   → Service 端: 启动搜索会话
  │   → 用户选择文本后触发搜索
  │   → 搜索结果通过系统 UI 显示
  │
  └── csm.stopSession();
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `START_TASKS_FROM_RECENTS` (privileged) | 从最近任务启动 | **强制**：控制启动 |
| `ACCESS_CONTEXTUAL_SEARCH` (privileged) | 访问上下文搜索 | **强制**：控制访问 |

**Binder 权限验证**:
- `checkCallingPermission(ACCESS_CONTEXTUAL_SEARCH)`
- `SHELL_UID`, `ROOT_UID`, `SYSTEM_UID` 检查

**SELinux**: `system_server` 域

**transact 调用可行性**: 搜索触发需要 `ACCESS_CONTEXTUAL_SEARCH`

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.26 ProfcollectdManagerService (性能收集转发服务)

**功能概述**: 转发性能收集请求到 native `profcollectd`。

**原理**:
- 不发布 binder 服务
- 作为 Java 到 native 的桥接
- 通过 `ProfcollectForwardingService` 转发

**App 交互流程**: 无公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**: N/A

**SELinux**: `system_server` 域

**transact 调用可行性**: 无 binder 服务

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.27 SearchUiManagerService (搜索 UI 服务)

**功能概述**: 管理搜索 UI 相关功能。

**原理**:
- 注册为 `SEARCH_UI_SERVICE`
- 协调搜索 UI
- 通过 `SearchUiManager` 管理搜索

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── SearchUiManager sum = getSystemService(SearchUiManager.class);
  │
  ├── 创建搜索会话:
  │   SearchSession session = sum.createSearchSession(config);
  │   → Service 端: 创建会话
  │
  ├── 查询:
  │   session.requestSearch(query, executor, callback);
  │   → Service 端: 将查询发送给搜索服务
  │   → 结果通过回调返回
  │
  └── session.close();
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_SEARCH_UI` (privileged) | 管理方法 | **强制**：控制管理操作 |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_SEARCH_UI`

**SELinux**: `system_server` 域

**transact 调用可行性**: 管理方法需要 `MANAGE_SEARCH_UI`

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.28 FeatureFlagsService (功能标志服务)

**功能概述**: 管理系统功能标志（Feature Flags）的同步和覆盖。

**原理**:
- 注册为 `FEATURE_FLAGS_SERVICE`
- 维护功能标志状态
- 协调跨进程标志同步
- 通过 `FeatureFlags` 管理标志

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── FeatureFlags ff = DeviceConfig.getFeatureFlags();
  │
  ├── 读取标志:
  │   boolean enabled = ff.getBoolean("namespace", "flag_name", defaultValue);
  │   → Service 端: 查询标志状态
  │
  ├── 监听变化:
  │   DeviceConfig.addOnPropertiesChangedListener(...);
  │
  └── 修改标志（需 WRITE_FLAGS）:
      DeviceConfig.setProperty("namespace", "flag_name", "value", false);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `SYNC_FLAGS` (internal) | 同步标志 | **强制**：控制同步 |
| `WRITE_FLAGS` (internal) | 写标志 | **强制**：控制写入 |

**Binder 权限验证**:
- `assertSyncPermission()` 检查 `SYNC_FLAGS`
- `assertWritePermission()` 检查 `WRITE_FLAGS`

**SELinux**: `system_server` 域

**transact 调用可行性**: 读取标志需要 `SYNC_FLAGS`；修改标志需要 `WRITE_FLAGS`

**shellCommand 调用可行性**: `FlagsShellCommand`

---

### 1.29 NetworkStatsService (网络统计服务)

**功能概述**: 收集和管理网络使用统计数据。

**原理**:
- 注册为网络统计服务
- 维护每个应用/UID 的网络使用统计
- 使用 BPF 收集数据
- 通过 `NetworkStatsManager` 暴露数据

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.READ_NETWORK_USAGE_HISTORY"/>
  │
  ├── NetworkStatsManager nsm = getSystemService(NetworkStatsManager.class);
  │
  ├── 查询网络使用统计:
  │   NetworkStats stats = nsm.queryDetailsForUid(
  │       NetworkTemplate.buildTemplateMobileAll(subscriberId),
  │       startTime, endTime, uid);
  │   → Service 端: 查询统计数据库
  │   → 返回指定 UID 的网络使用数据
  │
  ├── 查询摘要:
  │   NetworkStats.Bucket bucket = nsm.querySummaryForDevice(
  │       template, startTime, endTime);
  │
  └── 监听变化:
      nsm.registerUsageCallback(template, executor, callback);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `UPDATE_DEVICE_STATS` (system/privileged) | 更新设备统计 | **强制**：控制统计更新 |

**Binder 权限验证**:
- `enforceCallingOrSelfPermission(UPDATE_DEVICE_STATS)`
- `Process.SYSTEM_UID` 检查

**SELinux**: `system_server` 域

**transact 调用可行性**: 查询方法无严格权限限制（受 UID 匹配约束）；更新方法需要 `UPDATE_DEVICE_STATS`

**shellCommand 调用可行性**: `dump()`

---

### 1.30 CoverageManagerService (覆盖率服务)

**功能概述**: 管理代码覆盖率数据收集。

**原理**:
- 注册为 `COVERAGE_SERVICE`
- 协调覆盖率数据收集
- 通过 `CoverageService` 管理覆盖率

**App 交互流程**:
```
App
  ├── AndroidManifest.xml: 无需特殊权限
  │
  ├── 覆盖率收集由系统自动触发
  │   → Service 端: 收集覆盖率数据
  │   → 数据用于测试和分析
  │
  └── 手动触发:
      CoverageManager cm = getSystemService(CoverageManager.class);
      cm.generateCoverageData();
```

**Manifest 权限功效**: 无特殊权限要求

**Binder 权限验证**: 无显式权限检查

**SELinux**: `system_server` 域

**transact 调用可行性**: 覆盖率数据收集无严格权限限制

**shellCommand 调用可行性**: `onShellCommand()`

---

### 1.31 AppWidgetService (桌面小部件服务)

**功能概述**: 管理桌面小部件的绑定、更新和显示。

**原理**:
- 注册为 `AppWidgetManager`
- 维护小部件绑定列表
- 协调小部件更新
- 通过 `AppWidgetHost` 和 `AppWidgetProvider` 交互

**App 交互流程**:
```
App (小部件提供者)
  ├── AndroidManifest.xml:
  │   <receiver android:name=".MyAppWidgetProvider"
  │       android:permission="android.appwidget.action.APPWIDGET_UPDATE">
  │       <meta-data android:name="android.appwidget.provider"
  │           android:resource="@xml/appwidget_info"/>
  │       <intent-filter>
  │           <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
  │       </intent-filter>
  │   </receiver>
  │
  ├── 小部件更新:
  │   onUpdate(context, appWidgetManager, appWidgetIds);
  │   → Service 端: 触发更新，调用 onUpdate
  │
  └── 自定义 RemoteViews:
      RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget);
      appWidgetManager.updateAppWidget(appWidgetId, views);

App (宿主)
  ├── AppWidgetHost host = new AppWidgetHost(context, hostId);
  ├── int appWidgetId = host.allocateAppWidgetId();
  ├── appWidgetManager.bindAppWidgetIdIfAllowed(appWidgetId, provider);
  └── host.deleteAppWidgetId(appWidgetId);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `BIND_APPWIDGET` (privileged) | 绑定小部件 | **强制**：控制小部件绑定 |
| `APPWIDGET_LIST` (normal) | 列出小部件 | **强制**：控制小部件列表 |

**Binder 权限验证**:
- `enforceCallingPermission(BIND_APPWIDGET)` 用于绑定操作
- `Binder.getCallingUid()` 用于 UID 匹配

**SELinux**: `system_server` 域

**transact 调用可行性**: 绑定小部件需要 `BIND_APPWIDGET`；查询方法无严格权限限制

**shellCommand 调用可行性**: 无

---

## Framework Java 服务总结

| 服务 | 核心功能 | 主要交互方式 | 关键权限 | transact 风险 |
|------|----------|--------------|----------|---------------|
| AccessibilityManagerService | 无障碍服务管理 | 系统绑定 + 事件分发 | MANAGE_ACCESSIBILITY | MODERATE |
| AutofillManagerService | 自动填充框架 | 填充会话管理 | MANAGE_AUTO_FILL | LOW |
| BackupManagerService | 备份恢复 | 备份队列 + 传输 | BACKUP | LOW |
| PrintManagerService | 打印管理 | 打印作业队列 | READ_PRINT_SERVICES | LOW |
| UsbService | USB 管理 | 设备连接 + 权限 | MANAGE_USB | LOW |
| WifiServiceImpl | WiFi 管理 | 连接 + 配置 | ACCESS/CHANGE_WIFI_STATE | LOW |
| PermissionManagerService | 权限管理 | 权限状态数据库 | ADJUST_RUNTIME_PERMISSIONS_POLICY | LOW |
| DevicePolicyManagerService | 设备策略 | 策略状态 + 执行 | MANAGE_DEVICE_POLICY_* | LOW |
| VoiceInteractionManagerService | 语音交互 | 会话管理 | RECORD_AUDIO + CAMERA | LOW |
| UsageStatsService | 使用统计 | 统计数据库 | PACKAGE_USAGE_STATS | LOW |
| RestrictionsManagerService | 限制管理 | 键值存储 | 无 | LOW |
| CompanionDeviceManagerService | 伴侣设备 | 设备关联 | MANAGE_COMPANION_DEVICES | LOW |
| TextToSpeechManagerService | TTS 管理 | 引擎绑定 | 无 | LOW |
| CredentialManagerService | 凭证管理 | 凭证提供者 | CREDENTIAL_MANAGER_SET_* | LOW |
| AppPredictionManagerService | 应用预测 | 预测会话 | MANAGE_APP_PREDICTIONS | LOW |
| ContentCaptureManagerService | 内容捕获 | 捕获会话 | MANAGE_CONTENT_CAPTURE | LOW |
| MusicRecognitionManagerService | 音乐识别 | 识别请求 | MANAGE_MUSIC_RECOGNITION | LOW |
| TranslationManagerService | 翻译 | 翻译上下文 | MANAGE_UI_TRANSLATION | LOW |
| SmartspaceManagerService | 智能空间 | 卡片更新 | MANAGE_SMARTSPACE | LOW |
| SupervisionManagerService | 监督模式 | 监督状态 | 无 | LOW |
| SystemCaptionsManagerService | 系统字幕 | 字幕生成 | 无 | N/A |
| WallpaperEffectsGenerationManagerService | 壁纸效果 | 效果生成 | MANAGE_WALLPAPER_EFFECTS_GENERATION | LOW |
| AppFunctionManagerService | 应用函数 | 函数调用 | 无 | LOW |
| ContentSuggestionsManagerService | 内容建议 | 建议更新 | MANAGE_CONTENT_SUGGESTIONS | LOW |
| ContextualSearchManagerService | 上下文搜索 | 搜索触发 | ACCESS_CONTEXTUAL_SEARCH | LOW |
| ProfcollectdManagerService | 性能收集 | 请求转发 | 无 | N/A |
| SearchUiManagerService | 搜索 UI | 搜索会话 | MANAGE_SEARCH_UI | LOW |
| FeatureFlagsService | 功能标志 | 标志同步 | SYNC_FLAGS/WRITE_FLAGS | LOW |
| NetworkStatsService | 网络统计 | 统计数据库 | UPDATE_DEVICE_STATS | LOW |
| CoverageManagerService | 覆盖率 | 数据收集 | 无 | LOW |
| AppWidgetService | 桌面小部件 | 小部件绑定 | BIND_APPWIDGET | LOW |

---

## 二、Native 系统服务

### 2.1 SurfaceFlinger (Surface 合成服务)

**功能概述**: 管理系统中所有 Surface 的合成与显示，将各应用的窗口内容合成到屏幕上。

**工作原理**:
- 注册为 `"SurfaceFlinger"` 和 `"SurfaceFlingerAIDL"`
- 维护 `Layer` 树，每个窗口对应一个 Layer
- 通过 `Client` 对象管理应用连接
- 使用 HardwareComposer (HWC) 或 GPU 合成
- 通过 `SurfaceComposer` 接口暴露给客户端

**App 交互流程**:
```
App
  ├── 通过 WindowManager 创建 Surface:
  │   WindowManager wm = getSystemService(WindowManager.class);
  │   WindowManager.LayoutParams params = new WindowManager.LayoutParams();
  │   wm.addView(view, params);
  │   → Service 端: 创建 Layer，添加到 Layer 树
  │
  ├── Surface 绘制:
  │   Canvas canvas = surface.lockCanvas(null);
  │   canvas.drawColor(Color.WHITE);
  │   surface.unlockCanvasAndPost(canvas);
  │   → Service 端: 接收 Buffer，触发合成
  │
  ├── 合成流程:
  │   1. SurfaceFlinger 收集所有可见 Layer 的 Buffer
  │   2. 通过 HWC 或 GPU 合成
  │   3. 输出到 Display
  │
  └── 截图:
      SurfaceControl.screenshot(display);
      → 需要 READ_FRAME_BUFFER 权限或自截图
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `ACCESS_SURFACE_FLINGER` (system) | 直接访问 SurfaceFlinger | **强制**：控制直接访问 |
| `READ_FRAME_BUFFER` (system) | 读取帧缓冲/截图 | **强制**：控制截图 |
| `HARDWARE_TEST` (privileged) | 访问 backdoor transact codes | **强制**：控制 backdoor |
| `DUMP` (system/privileged) | dump 操作 | **强制**：控制 dump |
| `CONTROL_DISPLAY_BRIGHTNESS` (system) | 控制显示亮度 | **强制**：控制亮度 |

**Binder 权限验证**:
- `CheckTransactCodeCredentials` — 根据 transact code 检查不同权限
- `validateScreenshotPermissions` — 截图权限：`AID_GRAPHICS`, `AID_SYSTEM`, 或 `READ_FRAME_BUFFER`
- 自截图豁免：`captureArgs.uid == uid` 时无需权限
- Backdoor codes (1000-1045)：仅需 `AID_SYSTEM` 或 `HARDWARE_TEST`

**SELinux**: `surfaceflinger` 域，`mlstrustedsubject`，`coredomain`

**transact 调用可行性**: **HIGH** — Legacy transact codes 1000-1045 是 backdoor codes，绕过正常权限检查

**shellCommand 调用可行性**: `dump()` 需要 `AID_SHELL` 或 `DUMP` 权限

---

### 2.2 SensorService (传感器服务)

**功能概述**: 管理设备传感器数据的采集和分发，包括加速度计、陀螺仪、心率等。

**工作原理**:
- 维护传感器列表和事件连接
- 通过 `SensorEventConnection` 向应用分发事件
- 支持传感器权限、AppOp、速率限制
- 通过 `SensorDevice` 与 HAL 交互

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.HIGH_SAMPLING_RATE_SENSORS"/>
  │   → 高采样率权限
  │
  ├── SensorManager sm = getSystemService(SensorManager.class);
  │
  ├── 获取传感器:
  │   Sensor accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
  │   List<Sensor> sensors = sm.getSensorList(Sensor.TYPE_ALL);
  │
  ├── 注册监听:
  │   sm.registerListener(listener, accelerometer, SensorManager.SENSOR_DELAY_NORMAL);
  │   → Service 端: 创建 SensorEventConnection
  │   → 检查传感器权限（如 BODY_SENSORS）
  │   → 检查 AppOp
  │   → 检查 UID 活跃状态
  │   → 检查传感器隐私状态
  │   → 开始分发事件
  │
  ├── 接收事件:
  │   listener.onSensorChanged(event);
  │   → 事件通过 shared memory 传递
  │
  └── 注销监听:
      sm.unregisterListener(listener);
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `HIGH_SAMPLING_RATE_SENSORS` (normal) | 高采样率 (>200Hz) | **强制**：控制采样率 |
| `BODY_SENSORS` (dangerous) | 心率等身体传感器 | **强制**：控制传感器访问 |

**Binder 权限验证**:
- `canAccessSensor()` — 综合检查：权限 + AppOp + UID 状态 + 传感器隐私
- `hasSensorAccess()` — 检查传感器隐私、UID 活跃状态、操作限制
- Head Tracker 传感器：默认仅限 `AID_SYSTEM` 和 `AID_AUDIOSERVER`
- 预 Q SDK 应用：Step Counter/Detector 有豁免

**SELinux**: `sensors` 域

**transact 调用可行性**: **MODERATE** — 直接建立传感器事件连接可能绕过 Java 层

**shellCommand 调用可行性**: `shellCommand` 需要 `MANAGE_SENSORS` 权限

---

### 2.3 GpuService (GPU 服务)

**功能概述**: 暴露 GPU 驱动统计信息、内存信息、Vulkan 属性。

**原理**:
- 收集 GPU 统计数据 (`GpuStats`)
- 管理 GPU 内存信息 (`GpuMem`)
- 提供 Vulkan 属性和 profile
- 通过 `GpuService` 暴露数据

**App 交互流程**:
```
App
  ├── 通过 GraphicsEnvironment 或间接 API
  │
  ├── 获取 GPU 信息:
  │   GpuManager gm = context.getSystemService(GpuManager.class);
  │   String version = gm.getGpuDriverVersion();
  │   → Service 端: 返回 GPU 驱动版本
  │
  ├── 获取 Vulkan 信息:
  │   gm.getVulkanProperties();
  │   → Service 端: 返回 Vulkan 属性 JSON
  │
  └── 获取 GPU 统计:
      gm.getGpuStats();
      → Service 端: 返回 GPU 统计数据
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `ACCESS_GPU_SERVICE` (system) | 访问 GPU 服务 | **强制**：控制访问 |
| `DUMP` (system/privileged) | dump 操作 | **强制**：控制 dump |

**Binder 权限验证**:
- `toggleAngleAsSystemDriver()` — 需要 `AID_SYSTEM` AND `ACCESS_GPU_SERVICE`
- `setUpdatableDriverPath()` — 需要 `AID_SYSTEM`
- `doDump()` — 需要 `AID_SHELL` 或 `DUMP`

**SELinux**: `gpuservice` 域，`coredomain`，`bpfdomain`

**transact 调用可行性**: **LOW-MODERATE** — `shellCommand` 无显式权限检查

**shellCommand 调用可行性**: `shellCommand` 无权限检查

---

### 2.4 InputDispatcher / InputManager (输入服务)

**功能概述**: 管理输入事件的分发，将触摸/按键事件路由到正确的窗口。

**原理**:
- `InputDispatcher` 负责事件分发
- `InputManager` 管理输入通道
- 维护焦点窗口、触摸状态
- 通过 `InputChannel` 与应用通信

**App 交互流程**:
```
App
  ├── 通过 View 间接交互:
  │   view.setOnTouchListener((v, event) -> { return true; });
  │   → Service 端: 通过 InputChannel 发送事件
  │
  ├── 输入事件流程:
  │   1. 硬件产生输入事件
  │   2. InputReader 读取事件
  │   3. InputDispatcher 分发事件
  │   4. 通过 InputChannel 发送给目标窗口
  │   5. ViewRootImpl 接收并分发给 View
  │
  ├── 注入输入事件（需权限）:
  │   Instrumentation inst = new Instrumentation();
  │   inst.sendKeyDownUpSync(KeyEvent.KEYCODE_A);
  │   → Service 端: 验证 INJECT_EVENTS 权限
  │   → 验证 HMAC 签名
  │   → 注入事件
  │
  └── 创建输入通道（需权限）:
      InputChannel channel = new InputChannel();
      → 仅限 AID_SHELL 或 AID_ROOT
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `INJECT_EVENTS` (system/privileged) | 注入输入事件 | **强制**：控制事件注入 |
| `FILTER_INPUT_EVENTS` (signature) | 过滤输入事件 | **强制**：控制事件过滤 |

**Binder 权限验证**:
- `injectInputEvent()` — 验证 HMAC 签名，无内置权限检查
- `createInputChannel()` — 仅限 `AID_SHELL` 或 `AID_ROOT`
- 焦点验证：检查窗口是否属于正确 UID

**SELinux**: `inputflinger` 域，`coredomain`

**transact 调用可行性**: **HIGH** — `injectInputEvent` 在 InputDispatcher 层无内置权限检查

**shellCommand 调用可行性**: `createInputChannel` 仅限 `AID_SHELL`/`AID_ROOT`

---

### 2.5 AudioFlinger (音频核心服务)

**功能概述**: 管理音频播放和录制流的创建、混音和路由。

**原理**:
- 运行于 `audioserver` 进程
- 维护 `AudioTrack` (播放) 和 `AudioRecord` (录制) 对象
- 通过 `MixerThread` 混音多个播放流
- 与 `AudioPolicyService` 协作进行路由决策

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  │
  ├── 播放音频:
  │   AudioTrack track = new AudioTrack.Builder()
  │       .setAudioAttributes(new AudioAttributes.Builder()
  │           .setUsage(AudioAttributes.USAGE_MEDIA).build())
  │       .setAudioFormat(new AudioFormat.Builder()
  │           .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
  │           .setSampleRate(44100).build())
  │       .build();
  │   track.play();
  │   → Service 端: 创建 AudioTrack 对象
  │   → 打开输出流 (openOutput)
  │   → 验证 attribution source
  │   → 开始播放
  │
  ├── 录制音频:
  │   AudioRecord record = new AudioRecord.Builder()
  │       .setAudioFormat(...)
  │       .setBufferSizeInBytes(bufferSize)
  │       .build();
  │   record.startRecording();
  │   → Service 端: 创建 AudioRecord 对象
  │   → 打开输入流 (openInput)
  │   → 验证 RECORD_AUDIO 权限
  │   → 开始录制
  │
  └── 音频效果:
      Equalizer eq = new Equalizer(0, track.getAudioSessionId());
      → Service 端: 创建效果对象，绑定到音频流
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MODIFY_AUDIO_SETTINGS` (normal) | 修改音频设置 | **强制**：控制设置修改 |
| `RECORD_AUDIO` (dangerous) | 音频录制 | **强制**：控制录制 |
| `DUMP` (system/privileged) | dump 操作 | **强制**：控制 dump |

**Binder 权限验证**:
- `settingsAllowed()` — 检查 `MODIFY_AUDIO_SETTINGS` 或 `isAudioServerUid`
- `dumpAllowed()` — 检查 `DUMP` 权限
- `setLowRamDevice` — 需要 `isAudioServerOrSystemServerUid`
- `checkStreamType` — 非音频服务器 UID 不能访问非公共流类型
- `setParameters` — 过滤保留参数

**SELinux**: `audioserver` 域

**transact 调用可行性**: **MODERATE** — `onTransactWrapper` 阻止部分敏感操作

**shellCommand 调用可行性**: 无

---

### 2.6 AudioPolicyService (音频策略服务)

**功能概述**: 管理音频路由策略，决定音频流输出到哪个设备。

**原理**:
- 运行于 `audioserver` 进程
- 维护音频端口、模块、路由规则
- 处理电话状态、助手服务 UID 等对路由的影响

**App 交互流程**:
```
App
  ├── AudioManager am = getSystemService(AudioManager.class);
  │
  ├── 音频路由:
  │   am.setSpeakerphoneOn(true);
  │   → Service 端: 设置路由到扬声器
  │
  ├── 模式控制:
  │   am.setMode(AudioManager.MODE_IN_CALL);
  │   → Service 端: 切换到通话模式
  │   → 重新路由所有音频流
  │
  ├── 蓝牙:
  │   am.startBluetoothSco();
  │   → Service 端: 启用蓝牙 SCO
  │
  └── 音量控制:
      am.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0);
      → Service 端: 设置流音量
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `MANAGE_AUDIO_POLICY` (system/privileged) | 管理音频策略 | **强制**：控制策略管理 |

**Binder 权限验证**:
- `onTransact()` — 阻止非服务 UID 的敏感事务
- `getPermissionController` — 需要 `isAudioServerOrSystemServerUid`

**SELinux**: `audioserver` 域

**transact 调用可行性**: **MODERATE** — `onTransact` 显式阻止非服务 UID 的敏感事务

**shellCommand 调用可行性**: `shellCommand()` 需要 `MANAGE_AUDIO_POLICY`

---

### 2.7 CameraService (相机服务)

**功能概述**: 管理相机设备的打开、配置和帧捕获。

**原理**:
- 运行于 `cameraserver` 进程
- 维护相机设备列表和客户端连接
- 处理相机权限和 UID 状态
- 通过 `CameraDevice` 与 HAL 交互

**App 交互流程**:
```
App
  ├── AndroidManifest.xml:
  │   <uses-permission android:name="android.permission.CAMERA"/>
  │   <uses-feature android:name="android.hardware.camera"/>
  │
  ├── CameraManager cm = getSystemService(CameraManager.class);
  │
  ├── 打开相机:
  │   cm.openCamera("0", new CameraDevice.StateCallback() {
  │       @Override
  │       public void onOpened(@NonNull CameraDevice camera) {
  │           // 相机已打开
  │       }
  │   }, null);
  │   → Service 端: 验证客户端权限
  │   → 检查 CAMERA 权限
  │   → 检查 UID 活跃状态
  │   → 检查传感器隐私
  │   → 检查多用户状态
  │   → 打开相机设备
  │
  ├── 创建会话:
  │   camera.createCaptureSession(outputs, callback, handler);
  │   → Service 端: 创建 CaptureSession
  │
  ├── 捕获帧:
  │   CaptureRequest request = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
  │   request.addTarget(surface);
  │   session.setRepeatingRequest(request, callback, handler);
  │   → Service 端: 发送请求到相机 HAL
  │   → 接收帧数据，通过 Surface 返回
  │
  └── 释放:
      camera.close();
```

**Manifest 权限功效**:

| 权限 | 声明位置 | Service 端功效 |
|------|----------|----------------|
| `CAMERA` (dangerous) | 访问相机 | **强制**：控制相机访问 |
| `SYSTEM_CAMERA` (privileged) | 访问系统相机 | **强制**：控制系统相机 |
| `MANAGE_CAMERA` (privileged) | 管理相机 | **强制**：控制管理操作 |
| `CAMERA_HEADLESS_SYSTEM_USER` (system) | 无头系统用户相机 | **强制**：控制无头用户访问 |
| `CAMERA_PRIVACY_ALLOWLIST` (internal) | 相机隐私白名单 | **强制**：控制隐私白名单 |
| `CAMERA_SEND_SYSTEM_EVENTS` (system) | 发送系统事件 | **强制**：控制系统事件 |
| `CAMERA_OPEN_CLOSE_LISTENER` (system) | 监听相机开关 | **强制**：控制监听 |
| `CAMERA_INJECT_EXTERNAL_CAMERA` (system) | 注入外部相机 | **强制**：控制注入 |

**Binder 权限验证**:
- `validateClientPermissionsLocked()` — 最全面的客户端验证
- `callerHasSystemUid()` — `getCallingUid() < AID_APP_START`
- `isTrustedCallingUid()` — `AID_MEDIA`, `AID_CAMERASERVER`, `AID_RADIO`
- `resolveClientUid()` — 非信任调用方无法伪造 UID

**SELinux**: `cameraserver` 域，`coredomain`，`camera_service_server`

**transact 调用可行性**: **LOW** — 最全面的客户端验证

**shellCommand 调用可行性**: `shellCommand` 需要 `MANAGE_CAMERA`

---

## Native 系统服务总结

| 服务 | 核心功能 | 主要交互方式 | 关键权限 | transact 风险 |
|------|----------|--------------|----------|---------------|
| SurfaceFlinger | Surface 合成 | Layer 树 + Buffer 队列 | ACCESS_SURFACE_FLINGER | HIGH |
| SensorService | 传感器数据 | 事件连接 + shared memory | HIGH_SAMPLING_RATE_SENSORS | MODERATE |
| GpuService | GPU 信息 | 统计查询 | ACCESS_GPU_SERVICE | LOW-MODERATE |
| InputDispatcher | 输入事件分发 | InputChannel + 焦点窗口 | INJECT_EVENTS | HIGH |
| AudioFlinger | 音频播放/录制 | AudioTrack/AudioRecord | MODIFY_AUDIO_SETTINGS | MODERATE |
| AudioPolicyService | 音频路由策略 | 路由决策 + 模式控制 | MANAGE_AUDIO_POLICY | MODERATE |
| CameraService | 相机设备管理 | CameraDevice + Session | CAMERA | LOW |

---

## 三、媒体服务

### 3.1 AudioFlinger (音频核心)

**功能概述**: 管理音频播放/录制流的创建、混音和路由。运行于 `audioserver` 进程。

**原理**: 维护 AudioTrack/AudioRecord 对象，通过 MixerThread 混音，与 AudioPolicyService 协作路由。

**App 交互**:
```java
// 播放
AudioTrack track = new AudioTrack.Builder()
    .setAudioAttributes(new AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA).build())
    .setAudioFormat(new AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(44100).build())
    .build();
track.play();

// 录制
AudioRecord record = new AudioRecord.Builder()
    .setAudioFormat(...).setBufferSizeInBytes(size).build();
record.startRecording();
```

**Manifest 权限**: `MODIFY_AUDIO_SETTINGS` (normal), `RECORD_AUDIO` (dangerous), `DUMP` (system)

**Binder 验证**: `settingsAllowed()` 检查 MODIFY_AUDIO_SETTINGS；信任 UID (AID_SYSTEM/AID_AUDIOSERVER/AID_MEDIA/AID_ROOT) 绕过多数检查

**SELinux**: `audioserver` 域

**transact**: MODERATE — `onTransactWrapper` 阻止部分操作

**shell**: 无

---

### 3.2 AudioPolicyService (音频策略)

**功能概述**: 管理音频路由策略，决定音频流输出到哪个设备。

**原理**: 维护音频端口、模块、路由规则，处理电话状态/助手服务对路由的影响。

**App 交互**:
```java
AudioManager am = getSystemService(AudioManager.class);
am.setSpeakerphoneOn(true);
am.setMode(AudioManager.MODE_IN_CALL);
am.startBluetoothSco();
am.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0);
```

**Manifest 权限**: `MANAGE_AUDIO_POLICY` (system/privileged)

**Binder 验证**: `onTransact()` 阻止非服务 UID 的敏感事务

**SELinux**: `audioserver` 域

**transact**: MODERATE

**shell**: `shellCommand()` 需要 `MANAGE_AUDIO_POLICY`，命令：`purge_permission-cache`

---

### 3.3 CameraService (相机服务)

**功能概述**: 管理相机设备的打开、配置和帧捕获。运行于 `cameraserver` 进程。

**原理**: 维护相机设备列表和客户端连接，处理相机权限/UID 状态/传感器隐私。

**App 交互**:
```java
CameraManager cm = getSystemService(CameraManager.class);
cm.openCamera("0", new CameraDevice.StateCallback() {
    @Override
    public void onOpened(@NonNull CameraDevice camera) {
        camera.createCaptureSession(outputs, callback, handler);
    }
}, null);
```

**Manifest 权限**: `CAMERA` (dangerous), `SYSTEM_CAMERA` (privileged), `MANAGE_CAMERA` (privileged)

**Binder 验证**: `validateClientPermissionsLocked()` — 最全面的客户端验证（权限+UID+隐私+多用户+无头用户）

**SELinux**: `cameraserver` 域

**transact**: LOW

**shell**: `shellCommand` 需要 `MANAGE_CAMERA`

---

### 3.4 DrmServer (DRM 管理)

**功能概述**: 管理 DRM 会话的创建、验证和销毁。运行于 `drmserver` 进程。

**原理**: 维护 DRM 客户端列表，处理解密/转换会话，与 DRM 插件交互。

**App 交互**:
```java
DrmManagerClient client = new DrmManagerClient();
DrmInfoRequest request = new DrmInfoRequest(DrmInfoRequest.TYPE_REGISTRATION_INFO, "video/wvm");
DrmInfo info = client.acquireDrmInfo(request);
```

**Manifest 权限**: 无特殊权限要求（基于 token）

**Binder 验证**: 无显式权限检查，基于 `uniqueId` token 的安全模型

**SELinux**: `drmserver` 域，`mlstrustedsubject`，`net_domain`（唯一有网络的媒体服务）

**transact**: MODERATE — 无显式权限检查

**shell**: 无

---

### 3.5 MediaPlayerService (媒体播放)

**功能概述**: 管理媒体播放器的创建和控制。运行于 `mediaserver` 进程。

**原理**: 维护播放器客户端列表，处理媒体资源管理。

**App 交互**:
```java
MediaPlayer mp = MediaPlayer.create(context, Uri.parse("content://media/external/audio/media/1"));
mp.start();
mp.setOnCompletionListener(...);
mp.release();
```

**Manifest 权限**: 无特殊权限要求

**Binder 验证**: 无显式权限检查

**SELinux**: `mediaserver` 域

**transact**: MODERATE

**shell**: 无

---

### 3.6 ResourceManagerService (媒体资源管理)

**功能概述**: 管理媒体编解码器资源的分配和回收。

**原理**: 维护资源列表和进程信息，处理资源回收决策。

**App 交互**: 间接通过 MediaCodec/MediaPlayer

**Manifest 权限**: `MEDIA_RESOURCE_OVERRIDE_PID` (internal), `GET_PROCESS_STATE_AND_OOM_SCORE` (internal)

**Binder 验证**: `addResource` 非信任 PID/UID 被覆盖；`overridePid` 需要 `MEDIA_RESOURCE_OVERRIDE_PID`

**SELinux**: `mediaserver` 域

**transact**: LOW-MODERATE

**shell**: 无

---

### 3.7 MediaExtractorService (媒体提取)

**功能概述**: 解析媒体文件，提取音视频轨道和元数据。

**原理**: 运行于独立进程（`media.extractor`），使用 Minijail 沙箱 + seccomp 策略，通过 FD 接收文件。

**App 交互**:
```java
MediaExtractor extractor = new MediaExtractor();
extractor.setDataSource(path);
MediaFormat format = extractor.getTrackFormat(0);
```

**Manifest 权限**: 无特殊权限要求

**Binder 验证**: 无显式权限检查

**SELinux**: `mediaextractor` 域，`mlstrustedsubject`

**transact**: LOW — Minijail 沙箱 + seccomp 策略限制

**shell**: 无

---

### 3.8 MediaSwCodecService (软件编解码器)

**功能概述**: 提供软件编解码器（H.264, H.265, VP9 等）的实现。

**原理**: 运行于独立进程（`media.swcodec`），使用 Minijail 沙箱 + seccomp 策略。

**App 交互**:
```java
MediaCodec codec = MediaCodec.createDecoderByType("video/avc");
codec.configure(format, surface, null, 0);
codec.start();
```

**Manifest 权限**: 无特殊权限要求

**Binder 验证**: 无显式权限检查

**SELinux**: `media.swcodec` 域

**transact**: LOW — Minijail 沙箱 + seccomp 策略限制

**shell**: 无

---

### 3.9 TunerService (调谐器服务)

**功能概述**: 管理 TV 调谐器设备的访问。

**原理**: 注册为 `android.media.tv.tuner.TunerService`，支持懒加载 HAL。

**App 交互**:
```java
Tuner tuner = new Tuner(context, null, Tuner.TUNER_TYPE_LIVE);
tuner.openDvbFrontEnd();
```

**Manifest 权限**: `ACCESS_TV_SHARED_FILTER` (privileged)

**Binder 验证**: `openSharedFilter` 需要 `ACCESS_TV_SHARED_FILTER` + PID 匹配验证

**SELinux**: 独立域

**transact**: LOW

**shell**: 无

---

### 3.10 MediaMetrics (媒体指标)

**功能概述**: 收集音频/视频使用统计数据，上报到 StatsD。

**原理**: 运行于 `audioserver` 进程，收集 AudioTrack/AudioRecord 状态。

**App 交互**: 无直接公共 API

**Manifest 权限**: N/A

**Binder 验证**: `recordingAllowed()` 使用 `permission::PermissionChecker`

**SELinux**: `audioserver` 域

**transact**: LOW

**shell**: 无

---

### 3.11 TranscodingService (转码服务)

**功能概述**: 管理媒体文件的转码（格式转换、分辨率调整等）。

**原理**: 通过媒体编解码器基础设施实现，管理转码会话。

**App 交互**:
```java
MediaTranscodingManager mtm = getSystemService(MediaTranscodingManager.class);
mtm.addTranscodingRequest(request, executor, callback);
```

**Manifest 权限**: 无特殊权限要求

**Binder 验证**: 无显式权限检查

**SELinux**: 依赖底层编解码器服务域

**transact**: LOW

**shell**: 无

---

## 媒体服务总结

| 服务 | 核心功能 | 主要交互方式 | 关键权限 | transact 风险 |
|------|----------|--------------|----------|---------------|
| AudioFlinger | 音频播放/录制 | AudioTrack/AudioRecord | MODIFY_AUDIO_SETTINGS | MODERATE |
| AudioPolicyService | 音频路由策略 | 路由决策 + 模式控制 | MANAGE_AUDIO_POLICY | MODERATE |
| CameraService | 相机设备管理 | CameraDevice + Session | CAMERA | LOW |
| DrmServer | DRM 会话管理 | Token 模型 | 无 | MODERATE |
| MediaPlayerService | 媒体播放 | MediaPlayer | 无 | MODERATE |
| ResourceManagerService | 编解码器资源 | 资源分配/回收 | MEDIA_RESOURCE_OVERRIDE_PID | LOW-MODERATE |
| MediaExtractorService | 媒体文件解析 | FD 传递 | 无 | LOW |
| MediaSwCodecService | 软件编解码器 | Minijail 沙箱 | 无 | LOW |
| TunerService | TV 调谐器 | Tuner API | ACCESS_TV_SHARED_FILTER | LOW |
| MediaMetrics | 媒体统计 | StatsD 上报 | 无 | LOW |
| TranscodingService | 媒体转码 | 转码会话 | 无 | LOW |

---

## 四、系统核心守护进程

### 4.1 Init (系统初始化)

**功能概述**: 系统第一个用户空间进程，负责启动所有系统服务、管理属性、处理 uevent。

**原理**: 解析 `.rc` 文件定义服务启动顺序，通过 Unix domain socket 接收控制命令。

**App 交互**: 无直接 binder IPC，通过 property 和 init 间接交互。

**Manifest 权限**: N/A

**Binder 验证**: 无 binder IPC，使用 Unix domain socket + `SO_PEERCRED` 验证

**SELinux**: `init` 域

**transact**: VERY LOW（无 binder IPC）

**shell**: `ctl.start`/`ctl.stop`/`ctl.restart` 控制服务

---

### 4.2 Property Service (属性服务)

**功能概述**: 管理系统属性（`ro.*`, `persist.*`, `sys.*` 等），提供全局键值存储。

**原理**: 通过 Unix domain socket 接收读写请求，维护属性数据库，处理属性触发器。

**App 交互**:
```java
String value = System.getProperty("ro.build.version.sdk");
String fingerprint = Build.FINGERPRINT;
```

**Manifest 权限**: N/A（SELinux 控制）

**Binder 验证**: 无 binder IPC，`CheckPermissions()` + `CheckMacPerms()` + SELinux

**SELinux**: `init` 域

**transact**: VERY LOW

**shell**: `getprop`/`setprop` 命令

---

### 4.3 Vold (存储卷守护进程)

**功能概述**: 管理存储卷的挂载、卸载、加密和格式化。

**原理**: 维护卷列表和挂载状态，处理文件系统操作，管理外部存储和 OBB。

**App 交互**:
```java
StorageManager sm = getSystemService(StorageManager.class);
List<StorageVolume> volumes = sm.getStorageVolumes();
sm.mountObb(path, key, callback);
```

**Manifest 权限**: `MANAGE_EXTERNAL_STORAGE` (privileged), `MOUNT_UNMOUNT_FILESYSTEMS` (system)

**Binder 验证**: `ENFORCE_SYSTEM_OR_ROOT` 宏 — 多数操作需要 `AID_SYSTEM` 或 `AID_ROOT`

**SELinux**: `vold` 域

**transact**: HIGH — 文件系统操作有 UID 检查

**shell**: 通过 CommandListener 处理

---

### 4.4 Netd (网络守护进程)

**功能概述**: 管理网络接口、防火墙规则、DNS、带宽控制。

**原理**: 维护网络栈配置，处理防火墙规则，管理带宽和 QoS。

**App 交互**:
```java
ConnectivityManager cm = getSystemService(ConnectivityManager.class);
cm.requestNetwork(request, callback);
cm.bindProcessToNetwork(network);
```

**Manifest 权限**: `NETWORK_STACK` (internal), `MAINLINE_NETWORK_STACK` (internal), `CONNECTIVITY_INTERNAL` (internal)

**Binder 验证**: `ENFORCE_NETWORK_STACK_PERMISSIONS()` 宏；`AID_SYSTEM` 自动允许（避免死锁）

**SELinux**: `netd` 域，`bpfdomain`

**transact**: HIGH — `AID_SYSTEM` 绕过权限检查

**shell**: 通过 CommandListener 处理

---

### 4.5 LMKD (低内存杀手)

**功能概述**: 在系统内存不足时杀死进程以释放内存。

**原理**: 通过 Unix domain socket 接收命令，维护进程优先级列表，根据内存压力杀死进程。

**App 交互**: 无直接公共 API

**Manifest 权限**: N/A

**Binder 验证**: 无 binder IPC，使用 Unix socket + `SCM_CREDENTIALS`

**SELinux**: `lmkd` 域

**transact**: VERY LOW

**shell**: 无

---

### 4.6 GatekeeperD (Gatekeeper 守护进程)

**功能概述**: 管理 Gatekeeper 注册、验证和删除操作。

**原理**: 处理 Gatekeeper 事务，与 Trusty/TEE 中的 Gatekeeper TA 通信。

**App 交互**: 通过 LockSettingsService 间接交互

**Manifest 权限**: `ACCESS_KEYGUARD_SECURE_STORAGE` (system)

**Binder 验证**: 所有操作需要 `ACCESS_KEYGUARD_SECURE_STORAGE`

**SELinux**: `gatekeeperd` 域

**transact**: LOW

**shell**: 无

---

### 4.7 Installd (安装守护进程)

**功能概述**: 管理应用数据的创建、清理、快照和恢复。

**原理**: 处理应用数据目录操作，管理 dexopt/ART 编译，处理快照和恢复。

**App 交互**: 无直接公共 API，通过 PackageManagerService 间接交互

**Manifest 权限**: N/A

**Binder 验证**: `checkUid()` — `uid == expectedUid || uid == AID_ROOT`；`ENFORCE_UID(AID_SYSTEM)` 宏

**SELinux**: `installd` 域

**transact**: MEDIUM — UID-based 无 binder 权限

**shell**: 无

---

### 4.8 ServiceManager (服务管理器)

**功能概述**: 管理系统服务的注册和查找。

**原理**: 维护服务名称到 IBinder 的映射，处理服务注册/注销，管理服务查找权限。

**App 交互**:
```java
IBinder binder = ServiceManager.getService("service_name");
```

**Manifest 权限**: N/A（SELinux 控制）

**Binder 验证**: `addService()` 拒绝 App UID；`canAddService()` → SELinux 检查

**SELinux**: `servicemanager` 域

**transact**: MEDIUM — SELinux 控制

**shell**: 无

---

### 4.9 Apexd (APEX 管理)

**功能概述**: 管理 APEX 模块的激活、停用和回滚。

**原理**: 维护 APEX 模块列表，处理模块激活流程，管理快照和回滚。

**App 交互**: 无直接公共 API

**Manifest 权限**: N/A

**Binder 验证**: `CheckCallerIsRoot()` — 仅 `AID_ROOT`；`CheckCallerSystemOrRoot()` — `AID_ROOT` 或 `AID_SYSTEM`

**SELinux**: `apexd` 域

**transact**: HIGH — 模块管理是高权限操作

**shell**: `shellCommand` 无显式权限检查

---

### 4.10 UpdateEngine (OTA 更新引擎)

**功能概述**: 管理 OTA 更新的下载、验证和应用。

**原理**: 处理 A/B 更新，管理 payload 应用，协调启动控制。

**App 交互**:
```java
UpdateEngine ue = new UpdateEngine();
ue.bind(callback, handler);
ue.applyPayload(url, offset, size, headerKeyValuePairs);
```

**Manifest 权限**: N/A（SELinux 控制）

**Binder 验证**: 无显式权限检查，完全依赖 SELinux

**SELinux**: `update_engine` 域

**transact**: HIGH — 无显式权限检查

**shell**: 无

---

### 4.11 Storaged (存储统计)

**功能概述**: 收集和存储使用统计数据。

**原理**: 收集每个 UID 的 I/O 统计，暴露给 dumpsys。

**App 交互**: 无直接公共 API

**Manifest 权限**: N/A

**Binder 验证**: `dump()` 需要 `AID_SHELL` 或 `DUMP`

**SELinux**: `storaged` 域，`mlstrustedsubject`

**transact**: LOW

**shell**: 无

---

### 4.12 Tombstoned (Tombstone 收集)

**功能概述**: 收集和管理进程崩溃时的 tombstone 数据。

**原理**: 监听 debuggerd 信号，收集 tombstone 数据，暴露给 dumpsys。

**App 交互**: 无直接公共 API

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查，通过 SELinux 和文件权限控制

**SELinux**: `tombstoned` 域

**transact**: MODERATE

**shell**: 无

---

### 4.13 DebuggerD (调试器守护进程)

**功能概述**: 生成进程崩溃时的 core dump 和 tombstone。

**原理**: 通过 ptrace 附加到崩溃进程，收集寄存器/堆栈/内存信息。

**App 交互**: 无直接公共 API

**Manifest 权限**: N/A

**Binder 验证**: `pid_contains_tid()` 验证线程属于进程

**SELinux**: `debuggerd` 域

**transact**: LOW

**shell**: 无

---

### 4.14 CredStore (凭证存储)

**功能概述**: 管理应用凭证的存储和检索。

**原理**: 注册为 "android.security.identity"，处理凭证操作。

**App 交互**: 通过 CredentialManager API

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查

**SELinux**: `credstore` 域

**transact**: MODERATE

**shell**: 无

---

### 4.15 Keystore2 (密钥存储 2)

**功能概述**: 管理应用密钥的生成、存储和使用。

**原理**: Rust 实现，注册为 `android.system.keystore2.IKeystoreService/default`。

**App 交互**:
```java
KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
ks.load(null);
```

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查（在入口点）

**SELinux**: `keystore2` 域

**transact**: MODERATE

**shell**: 无

---

### 4.16 BootStat (启动统计)

**功能概述**: 测量和记录启动时间。

**原理**: CLI 工具，非持久服务，读取 `/proc`，写入 statsd。

**App 交互**: 无

**Manifest 权限**: N/A

**Binder 验证**: 无

**SELinux**: N/A

**transact**: VERY LOW

**shell**: 无

---

### 4.17 Usbd (USB 守护进程)

**功能概述**: 处理 USB 事件和模式切换。

**原理**: 最小守护进程，在充电器模式下退出，调用 `setCurrentUsbFunctions()` 到 HAL。

**App 交互**: 无

**Manifest 权限**: N/A

**Binder 验证**: 无

**SELinux**: `usbd` 域

**transact**: VERY LOW

**shell**: 无

---

### 4.18 LLKD (锁死检测)

**功能概述**: 检测系统锁死并触发 kernel panic。

**原理**: 独立守护进程，`prctl(PR_SET_DUMPABLE, 0)` 防止 core dump。

**App 交互**: 无

**Manifest 权限**: N/A

**Binder 验证**: 无

**SELinux**: `llkd` 域

**transact**: VERY LOW

**shell**: 无

---

## 系统核心守护进程总结

| 服务 | 核心功能 | 主要交互方式 | 关键权限/UID | transact 风险 |
|------|----------|--------------|--------------|---------------|
| Init | 系统初始化 | .rc 文件 + Unix socket | N/A | VERY LOW |
| Property Service | 属性管理 | Unix socket + SELinux | SELinux 控制 | VERY LOW |
| Vold | 存储卷管理 | 文件系统操作 | AID_SYSTEM/ROOT | HIGH |
| Netd | 网络管理 | 防火墙/DNS/带宽 | NETWORK_STACK | HIGH |
| LMKD | 低内存杀手 | Unix socket + SCM_CREDENTIALS | 无 | VERY LOW |
| GatekeeperD | Gatekeeper | TEE 通信 | ACCESS_KEYGUARD_SECURE_STORAGE | LOW |
| Installd | 应用安装 | 数据目录操作 | AID_SYSTEM | MEDIUM |
| ServiceManager | 服务注册/查找 | SELinux 控制 | SELinux | MEDIUM |
| Apexd | APEX 模块管理 | 模块激活/回滚 | AID_ROOT/SYSTEM | HIGH |
| UpdateEngine | OTA 更新 | Payload 应用 | SELinux 控制 | HIGH |
| Storaged | 存储统计 | I/O 统计 | DUMP | LOW |
| Tombstoned | Tombstone 收集 | 崩溃数据 | SELinux 控制 | MODERATE |
| DebuggerD | Core dump 生成 | ptrace | 无 | LOW |
| CredStore | 凭证存储 | 凭证操作 | 无 | MODERATE |
| Keystore2 | 密钥存储 | 密钥操作 | 无 | MODERATE |
| BootStat | 启动统计 | CLI 工具 | N/A | VERY LOW |
| Usbd | USB 事件 | HAL 调用 | 无 | VERY LOW |
| LLKD | 锁死检测 | 独立守护进程 | 无 | VERY LOW |

---

## 五、Trusty/安全服务

### 5.1 Trusty Gatekeeper

**功能概述**: 通过 Trusty TEE 实现 Gatekeeper 注册和验证。

**原理**: 运行于 `gatekeeperd` 域，通过 `/dev/trusty-ipc-dev0` 与 Trusty TA 通信。

**App 交互**: 通过 Gatekeeper HAL 间接交互

**Manifest 权限**: N/A（框架层处理）

**Binder 验证**: 无显式 Android 权限检查，UID 参数传递给 Trusty TA

**SELinux**: `gatekeeperd` 域

**transact**: LOW

**shell**: 无

---

### 5.2 Trusty Keymaster

**功能概述**: 通过 Trusty TEE 实现密钥生成、导入、导出、签名等。

**原理**: 运行于 `keymasterd` 域，通过 Trusty IPC 转发命令到 TA。

**App 交互**: 通过 Keymint HAL 间接交互

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查，所有命令直接转发到 Trusty TA

**SELinux**: `keymasterd` 域

**transact**: LOW

**shell**: 无

---

### 5.3 Trusty ConfirmationUI

**功能概述**: 通过 Trusty TEE 实现安全确认 UI。

**原理**: 运行于 `confirmationui` 域，安全输入设备独占访问，状态机管理。

**App 交互**: 通过 ConfirmationUI HAL 间接交互

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查

**SELinux**: `confirmationui` 域

**transact**: LOW

**shell**: 无

---

### 5.4 Trusty Storage Proxy

**功能概述**: 代理 Trusty TA 的存储操作，提供看门狗监控。

**原理**: 监控存储命令超时，看门狗超时：500ms 默认，10s 最大。

**App 交互**: 无直接交互

**Manifest 权限**: N/A

**Binder 验证**: 无

**SELinux**: 存储相关域

**transact**: VERY LOW

**shell**: 无

---

## 六、HAL 服务

### 6.1 Biometrics Face HAL (面部识别)

**功能概述**: 提供面部识别 HAL 实现。

**原理**: 注册为 `android.hardware.biometrics.face@1.0`，单线程 RPC。

**App 交互**: 通过 BiometricManager 间接交互

**Manifest 权限**: N/A（框架层处理）

**Binder 验证**: 无显式权限检查

**SELinux**: `hal_face_default` 域

**transact**: LOW

**shell**: 无

---

### 6.2 Biometrics Fingerprint HAL (指纹识别)

**功能概述**: 提供指纹识别 HAL 实现。

**原理**: 注册为 `android.hardware.biometrics.fingerprint@2.2`，单线程 RPC。

**App 交互**: 通过 BiometricManager 间接交互

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查

**SELinux**: `hal_fingerprint_default` 域

**transact**: LOW

**shell**: 无

---

### 6.3 WiFi HAL

**功能概述**: 提供 WiFi HAL 实现。

**原理**: AIDL 服务，支持懒加载服务注册。

**App 交互**: 通过 WifiManager 间接交互

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查

**SELinux**: `hal_wifi_default` 域

**transact**: LOW

**shell**: 无

---

### 6.4 Sensors HAL

**功能概述**: 提供传感器 HAL 实现。

**原理**: 使用 FMQ (Fast Message Queue) 进行事件传递，`injectSensorData()` 允许注入传感器事件。

**App 交互**: 通过 SensorManager 间接交互

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查

**SELinux**: `hal_sensors_default` 域

**transact**: MODERATE — `injectSensorData()` 允许注入传感器事件

**shell**: 无

---

### 6.5 Camera Provider HAL

**功能概述**: 提供相机 Provider HAL 实现。

**原理**: 注册为 `android.hardware.camera.provider@2.5`，支持懒加载服务注册。

**App 交互**: 通过 CameraManager 间接交互

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查

**SELinux**: `hal_camera_default` 域

**transact**: LOW

**shell**: 无

---

## 七、包服务

### 7.1 TelecomServiceImpl (电话服务)

**功能概述**: 管理电话呼叫、会议、音频路由。

**原理**: 运行于 `system_server` 进程，维护电话呼叫状态，协调音频路由。

**App 交互**:
```java
TelecomManager tm = getSystemService(TelecomManager.class);
tm.placeCall(uri, extras);
tm.registerPhoneAccount(account);
```

**Manifest 权限**: `MANAGE_OWN_CALLS` (normal), `MODIFY_PHONE_STATE` (system), `READ_PHONE_STATE` (dangerous), `READ_PRIVILEGED_PHONE_STATE` (system), `WRITE_SECURE_SETTINGS` (system)

**Binder 验证**: `enforceCallingPackage()`, `enforceUserHandleMatchesCaller()`, `isPrivilegedUid()`, `enforceCrossUserPermission()`

**SELinux**: `system_server` 域

**transact**: HIGH — 50+ AIDL 方法

**shell**: `BasicShellCommandHandler` 实现

---

### 7.2 Telephony Service (电话服务)

**功能概述**: 管理移动网络、SIM 卡、短信等。

**原理**: 运行于 `system_server` 进程，维护电话状态，协调与调制解调器的通信。

**App 交互**:
```java
TelephonyManager tm = getSystemService(TelephonyManager.class);
String operator = tm.getNetworkOperatorName();
String imei = tm.getDeviceId();
```

**Manifest 权限**: `READ_PHONE_STATE` (dangerous), `MODIFY_PHONE_STATE` (system), `READ_PRIVILEGED_PHONE_STATE` (system)

**Binder 验证**: `TelephonyPermissions` 验证，`CarrierPrivilegesTracker` 运营商特权检查

**SELinux**: `system_server` 域

**transact**: HIGH — 100+ AIDL 方法

**shell**: 无

---

### 7.3 Car Service (车机服务)

**功能概述**: 管理车机系统的核心服务。

**原理**: 代理模式：`CarService` 代理到 `CarServiceImpl`，31 个 binder 线程。

**App 交互**:
```java
Car car = Car.createCar(context);
CarPropertyManager cpm = (CarPropertyManager) car.getCarManager(Car.PROPERTY_SERVICE);
```

**Manifest 权限**: 在 `CarServiceImpl` 中检查

**Binder 验证**: 委托给 `CarServiceImpl`

**SELinux**: `system_server` 域

**transact**: MODERATE

**shell**: 无

---

## 八、车机服务

### 8.1 WatchdogProcessService (看门狗服务)

**功能概述**: 监控车机进程健康状态，杀死无响应进程。

**原理**: 客户端注册 + binder 死亡监控，健康检查超时，VHAL 心跳监控。

**App 交互**: 通过 ICarWatchdogService 间接交互

**Manifest 权限**: N/A

**Binder 验证**: `getCallingUid()` 客户端识别，`getCallingPid()` 进程识别

**SELinux**: 车机相关域

**transact**: MODERATE — `dumpAndKillAllProcesses()` 进程终止能力

**shell**: 无

---

### 8.2 EvsManager (外部视觉系统管理器)

**功能概述**: 管理车机外部摄像头系统。

**原理**: AIDL 接口，协调摄像头资源。

**App 交互**: 通过 EvsManager API

**Manifest 权限**: N/A

**Binder 验证**: 无显式权限检查

**SELinux**: 车机相关域

**transact**: LOW

**shell**: 无

---

## 九、模块服务

### 9.1 StatsD (统计守护进程)

**功能概述**: 收集系统统计信息，上报到 StatsD。

**原理**: 注册为 `stats`，请求调用方 SELinux 上下文，9 个线程池。

**App 交互**: 无直接公共 API

**Manifest 权限**: N/A

**Binder 验证**: SELinux 上下文验证

**SELinux**: `statsd` 域

**transact**: LOW

**shell**: 无

---

### 9.2 Derive SDK (SDK 级别推导)

**功能概述**: 在启动时推导 SDK 级别。

**原理**: 命令行工具，非持久服务，挂载点：`/apex`。

**App 交互**: 无

**Manifest 权限**: N/A

**Binder 验证**: 无

**SELinux**: N/A

**transact**: VERY LOW

**shell**: 无

---

### 9.3 Microdroid Launcher (微虚拟机启动器)

**功能概述**: 在隔离环境中加载和运行 payload。

**原理**: 创建隔离的 linker namespace，受限库访问白名单。

**App 交互**: 无

**Manifest 权限**: N/A

**Binder 验证**: 无

**SELinux**: 隔离域

**transact**: VERY LOW

**shell**: 无

---

## 十、恢复模式服务

### 10.1 Recovery (恢复模式)

**功能概述**: 在恢复模式下执行 OTA 安装、数据擦除等操作。

**原理**: 无 Android 权限模型，需要物理访问，电池电量检查，用户确认。

**App 交互**: 无

**Manifest 权限**: N/A

**Binder 验证**: 无

**SELinux**: `recovery` 域

**transact**: VERY LOW

**shell**: 命令行接口：`/cache/recovery/command`

---

## 全局总结

### 攻击面评级总表

| 服务类别 | 最高风险服务 | transact 风险 | shell 风险 |
|----------|-------------|---------------|------------|
| Framework Java | AccessibilityManagerService | MODERATE | LOW |
| Native 系统 | SurfaceFlinger, InputDispatcher | HIGH | LOW |
| 媒体服务 | DrmServer, MediaPlayer | MODERATE | LOW |
| 系统核心 | netd, vold, apexd, update_engine | HIGH | LOW |
| Trusty/安全 | Trusty Gatekeeper | LOW | NONE |
| HAL 服务 | Sensors HAL | MODERATE | NONE |
| 包服务 | TelecomServiceImpl, PhoneInterfaceManager | HIGH | LOW |
| 车机服务 | WatchdogProcessService | MODERATE | NONE |
| 模块服务 | StatsD | LOW | NONE |
| 恢复模式 | Recovery | VERY LOW | LOW |

### IBinder.transact() 攻击可行性

| 条件 | 可行性 | 说明 |
|------|--------|------|
| 无权限方法 | ✅ 可行 | `@RequiresNoPermission` 方法可直接调用 |
| 需 normal 权限方法 | ⚠️ 需权限 | 需声明对应权限 |
| 需 system 权限方法 | ❌ 不可行 | 需 system/privileged 权限 |
| 需 AID_SYSTEM | ❌ 不可行 | 需 system server 身份 |
| SELinux 保护 | ❌ 不可行 | SELinux 阻止 app 访问服务 |

### IBinder.shellCommand() 攻击可行性

| 条件 | 可行性 | 说明 |
|------|--------|------|
| 无权限 shellCommand | ⚠️ 需 SHELL_UID | GpuService, APEX 无权限检查 |
| 需权限 shellCommand | ❌ 需 SHELL_UID + 权限 | 多数需要特定权限 |
| dump() 方法 | ⚠️ 需 SHELL_UID | 输出可能泄露信息 |

### 关键安全发现

1. **SurfaceFlinger Backdoor Codes (1000-1045)**: 绕过正常权限检查，仅需 `AID_SYSTEM` 或 `HARDWARE_TEST`
2. **InputDispatcher 无内置权限检查**: `injectInputEvent` 依赖框架层 `INJECT_EVENTS` 权限
3. **netd AID_SYSTEM 绕过**: 避免死锁但扩大攻击面
4. **update_engine 无显式权限检查**: 完全依赖 SELinux
5. **GpuService shellCommand 无权限检查**: 可执行 `vkjson`, `vkprofiles`
6. **APEX shellCommand 无显式权限检查**: 可执行 `stagePackages`, `remountPackages`
7. **Sensors HAL injectSensorData()**: 可注入伪造传感器事件
8. **Trusty 服务无显式权限检查**: 依赖框架层权限检查在前

---


