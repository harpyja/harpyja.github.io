# Android 15 AOSP 系统服务安全分析

> 生成日期: 2026-07-24  
> 基于: Android 15 AOSP 源码

---

## 符号说明

| 符号 | 含义 |
|------|------|
| **transact** | 能否通过 `IBinder.transact()` 直接调用 |
| **shell** | 能否通过 `adb shell dumpsys` 或 shellCommand 调用 |
| **perm** | 是否需要 Manifest 权限 |
| **uid** | 是否校验调用方 UID |
| **SELinux** | SELinux 域/策略 |
| **N/A** | 不适用 |

---

## 一、Framework Java 服务安全分析

### 1.1 AccessibilityManagerService (无障碍服务)

**功能**: 管理系统中所有无障碍服务的注册、启用、事件分发。为视觉/听觉障碍用户提供屏幕读取、放大、语音控制等辅助能力。

**原理**: 
- 注册为 `Context.ACCESSIBILITY_SERVICE`，运行于 `system_server` 进程
- 维护 `AccessibilityServiceConnection` 列表，每个已启用服务一个连接
- 通过 `AccessibilityInteractionConnection` 允许服务获取窗口内容（受 `RETRIEVE_WINDOW_CONTENT` 权限约束）
- 使用 `Binder.clearCallingIdentity()` 在服务回调时临时提升权限

**App 交互**:
```java
// 获取服务实例
AccessibilityManager am = (AccessibilityManager) getSystemService(Context.ACCESSIBILITY_SERVICE);
// 查询已安装服务
List<AccessibilityServiceInfo> services = am.getInstalledAccessibilityServiceList();
// 中断当前服务反馈
am.interrupt();
// 发送无障碍事件（内部API）
am.sendAccessibilityEvent(event);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查位置 |
|------|------|----------|
| `ACCESSIBILITY_SERVICE` (normal) | 仅用于查找服务，无实际访问控制 | manifest 声明即可 |
| `MANAGE_ACCESSIBILITY` (privileged/system) | 启用/禁用无障碍服务、注册/注销系统动作 | `registerSystemAction`, `unregisterSystemAction` |
| `STATUS_BAR_SERVICE` (system) | 通知无障碍按钮点击/长按/可见性变化 | `notifyAccessibilityButtonClicked` 等 |
| `MODIFY_ACCESSIBILITY_DATA` | 设置 PIP 替代连接 | `setPictureInPictureActionReplacingConnection` |
| `RETRIEVE_WINDOW_CONTENT` | 注册 UI 自动化测试服务、获取窗口令牌 | `registerUiTestAutomationService`, `getWindowToken` |
| `MANAGE_BIND_INSTANT_SERVICE` | 设置是否允许绑定即时服务 | `setBindInstantServiceAllowed` |

**Binder 权限验证**:
- `enforceCallingOrSelfPermission` 用于 `MANAGE_BIND_INSTANT_SERVICE`
- `@EnforcePermission` 注解（Android 15 新模式，基于 `PermissionEnforcer`）用于多数敏感操作
- `Binder.getCallingUid()` 在 `OWNER_PROCESS_ID` 检查中（line 1348）
- 部分方法标注 `@RequiresNoPermission`（如 `sendAccessibilityEvent`, `getInstalledAccessibilityServiceList`, `interrupt`），无需权限即可调用

**SELinux**: 运行于 `system_server` 域（`system_server`），属于 `mlstrustedsubject`

**transact 攻击面**: 
- 可通过 `IBinder.transact()` 直接调用 `getEnabledAccessibilityServiceList()`, `getInstalledAccessibilityServiceList()`, `interrupt()` 等方法（无权限要求）
- 敏感方法（如 `getWindowToken`）虽有 `RETRIEVE_WINDOW_CONTENT` 权限检查，但 `transact()` 绕过 Java 层权限检查需 SELinux 策略配合
- 窗口内容获取受 `AccessibilityInteractionConnection` 二次校验

**shell 攻击面**:
- `onShellCommand()` (line 5226) → `AccessibilityShellCommand`，仅 `SHELL_UID` 可调用
- `dump()` (line 5083) 可输出服务状态信息

**总结**: 攻击面中等。无权限可读信息有限；敏感操作有权限保护；UI 自动化路径是高价值攻击目标。

---

### 1.2 AutofillManagerService (自动填充服务)

**功能**: 管理自动填充框架，协调应用与自动填充服务（如密码管理器）之间的交互。

**原理**:
- 注册为 `AUTOFILL_MANAGER_SERVICE`
- 使用 `MasterSystemService` 模式，按用户维护服务实例
- 通过 `AutofillServiceConnection` 绑定到第三方自动填充服务

**App 交互**:
```java
AutofillManager afm = getSystemService(AutofillManager.class);
// 检查是否启用
boolean enabled = afm.isEnabled();
// 提交填充数据（内部）
afm.autofill(data);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_AUTO_FILL` (system) | 管理方法：设置调试模式、重置等 | `enforceCallingPermissionForManagement()` |

**Binder 权限验证**:
- 所有管理方法调用 `enforceCallingPermissionForManagement()` 检查 `MANAGE_AUTO_FILL`
- `Binder.getCallingUid()` 在 `getServiceForUserWithLocalBinderIdentityLocked` 中使用
- 普通自动填充交互方法无显式权限检查（依赖框架层 UID 匹配）

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 填充交互方法（如 `setAutofillOptions`, `setSavedPassword`）通常不需要权限但依赖 UID 匹配
- 可通过 `transact()` 尝试触发填充流程，但受应用 UID 匹配限制

**shell 攻击面**: 无专用 shellCommand，`dump()` 受 AbstractMasterSystemService 框架保护

---

### 1.3 BackupManagerService (备份服务)

**功能**: 管理应用数据的备份和恢复，与备份传输服务交互。

**原理**:
- 注册为 `Context.BACKUP_SERVICE`
- 维护备份队列、传输连接
- 使用 `BackgroundThread` 处理异步操作

**App 交互**:
```java
BackupManager bm = new BackupManager(context);
// 请求备份
bm.dataChanged();
// 执行备份操作（需权限）
bm.requestRestore(observer);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `android.permission.BACKUP` (system/privileged) | 访问备份服务、跨用户操作 | `enforceCallingOrSelfPermission` |
| `INTERACT_ACROSS_USERS_FULL` (system) | 跨用户备份操作 | `enforceCallingOrSelfPermission` |

**Binder 权限验证**:
- `enforcePermissionsOnUser()` (line 468-470) 检查 `BACKUP` 权限
- `Process.SYSTEM_UID` 和 `Process.ROOT_UID` 显式检查 (line 464) 用于 `setBackupServiceActive()`
- `binderGetCallingUid()` 用于调用方 UID 跟踪

**SELinux**: `system_server` 域

**transact 攻击面**: 
- `isBackupServiceActive()` 需要 `BACKUP` 权限
- `requestRestore()` 需要相应权限
- 但 `dataChanged()` 等轻量方法可能无需权限

**shell 攻击面**: 无专用 shellCommand，`dump()` (line 1509) 输出备份状态

---

### 1.4 PrintManagerService (打印服务)

**功能**: 管理系统打印功能，协调打印作业与打印服务之间的交互。

**原理**:
- 注册为 `Context.PRINT_SERVICE`
- 维护打印作业队列、打印服务发现

**App 交互**:
```java
PrintManager pm = (PrintManager) getSystemService(Context.PRINT_SERVICE);
PrintDocumentAdapter adapter = new MyPrintDocumentAdapter();
pm.print("job_name", adapter, null);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `READ_PRINT_SERVICES` (normal) | 获取打印服务列表、添加/移除打印服务变化监听 | `enforceCallingOrSelfPermission` |
| `READ_PRINT_SERVICE_RECOMMENDATIONS` (normal) | 获取打印服务推荐、监听推荐变化 | `enforceCallingOrSelfPermission` |
| `ACCESS_ALL_PRINT_JOBS` (system/privileged) | 访问所有打印作业 | `checkCallingPermission` |

**Binder 权限验证**:
- `enforceCallingOrSelfPermission` 用于读取权限检查
- `SHELL_UID` 和 `ROOT_UID` 检查 (lines 799-801, 819-821) 允许 shell 访问所有打印作业
- `Process.SYSTEM_UID` 检查 (line 1117) 限制特定操作

**SELinux**: `system_server` 域

**transact 攻击面**: 
- `getPrintServices()` 和 `getPrintServiceRecommendations()` 需要 normal 级权限
- `print()` 方法本身无显式权限检查，受框架保护

**shell 攻击面**: 
- `onShellCommand()` (line 133) → `PrintShellCommand`
- `dump()` (line 752) 输出打印状态

---

### 1.5 UsbService (USB 服务)

**功能**: 管理 USB 设备/配件模式、端口角色切换、权限授予。

**原理**:
- 注册为 `Context.USB_SERVICE`
- 管理 USB 设备连接、配件模式切换
- 维护每个应用的 USB 权限状态

**App 交互**:
```java
UsbManager um = (UsbManager) getSystemService(Context.USB_SERVICE);
// 获取已连接设备
HashMap<String, UsbDevice> devices = um.getDeviceList();
// 请求设备权限
PermissionIntent pi = um.requestPermission(device);
// 打开设备
UsbDeviceConnection conn = um.openDevice(device);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_USB` (privileged/system) | 设置当前功能、授予权限、设置端口角色等 | `@EnforcePermission`, `enforceCallingOrSelfPermission` |
| `ACCESS_MTP` (normal) | 获取 MTP 控制文件描述符 | `@EnforcePermission` |

**Binder 权限验证**:
- `@EnforcePermission(MANAGE_USB)` 用于敏感 USB 控制方法
- `enforceCallingOrSelfPermission(MANAGE_USB)` 用于权限/偏好管理方法
- `Binder.getCallingUid()` 用于权限状态跟踪

**SELinux**: `system_server` 域

**transact 攻击面**: 
- `getDeviceList()` 等方法无显式权限要求
- `setCurrentFunctions()` 等控制方法需要 `MANAGE_USB`
- `setPortRoles()` 等高级操作需要 `MANAGE_USB`

**shell 攻击面**: 
- `dump()` (line 1079) 处理 shell 命令，包含 `reset-port` 等敏感操作
- 部分 dump 子命令需要 `MANAGE_USB` 权限

---

### 1.6 WifiServiceImpl (WiFi 服务)

**功能**: 管理 WiFi 连接、热点、网络配置、扫描等。

**原理**:
- 注册为 `Context.WIFI_SERVICE`
- 通过 `WifiStateMachine` / `ClientModeImpl` 管理连接状态
- 维护网络配置、扫描结果缓存

**App 交互**:
```java
WifiManager wm = (WifiManager) getSystemService(Context.WIFI_STATE_SERVICE);
// 获取连接信息
WifiInfo info = wm.getConnectionInfo();
// 获取扫描结果
List<ScanResult> results = wm.getScanResults();
// 添加网络配置
int netId = wm.addNetwork(wifiConfig);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `ACCESS_WIFI_STATE` (normal) | 获取 WiFi 状态、连接信息、扫描结果 | `enforceCallingOrSelfPermission` |
| `CHANGE_WIFI_STATE` (normal) | 修改 WiFi 配置、连接/断开网络 | `enforceCallingOrSelfPermission` |
| `NETWORK_SETTINGS` (privileged/system) | 高级网络配置、重启 WiFi 子系统 | `enforceCallingOrSelfPermission` |
| `RESTART_WIFI_SUBSYSTEM` (privileged) | 重启 WiFi 子系统 | `enforceCallingOrSelfPermission` |
| `READ_WIFI_CREDENTIAL` (privileged) | 读取 WiFi 凭证 | `enforceCallingOrSelfPermission` |

**Binder 权限验证**:
- 每个方法都有对应的 `enforceCallingOrSelfPermission` 检查
- `Binder.getCallingUid()` 大量使用 (100+ 处) 用于 UID 匹配
- `Process.SHELL_UID` 和 `Process.ROOT_UID` 特殊处理 (line 3331)
- `Process.SYSTEM_UID` 用于特定操作 (line 3907)
- `mAppOps.checkPackage` 用于包名验证 (line 1158)

**SELinux**: `system_server` 域

**transact 攻击面**: 
- `getScanResults()`, `getConnectionInfo()` 需要 normal 级权限
- `addNetwork()`, `removeNetwork()` 需要 `CHANGE_WIFI_STATE`
- `getPrivilegedConfiguredNetworks()` 等高价值方法需要 `NETWORK_SETTINGS`

**shell 攻击面**: 
- WiFi shell 命令通过 `WifiShellCommand` 实现
- 可通过 `adb shell cmd wifi` 执行多种操作

---

### 1.7 PermissionManagerService (权限管理服务)

**功能**: 管理系统中所有运行时权限的授予、撤销、查询。

**原理**:
- 注册为 `"permissionmgr"` 和 `"permission_checker"`
- 维护权限状态数据库
- 协调权限请求 UI 流程

**App 交互**:
```java
// 通过 ActivityCompat 请求权限
ActivityCompat.requestPermissions(this, 
    new String[]{Manifest.permission.CAMERA}, REQUEST_CODE);

// 直接查询（系统应用）
PackageManager pm = getPackageManager();
int result = pm.checkPermission(Manifest.permission.CAMERA, packageName);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `ADJUST_RUNTIME_PERMISSIONS_POLICY` (system) | 调整运行时权限策略 | `enforceCallingPermission` |
| `UPDATE_APP_OPS_STATS` (system/privileged) | 更新 app ops 统计 | `enforceCallingOrSelfPermission` |

**Binder 权限验证**:
- `enforceCallingPermission(ADJUST_RUNTIME_PERMISSIONS_POLICY)` 用于策略调整
- `enforceCallingOrSelfPermission(UPDATE_APP_OPS_STATS)` 用于统计
- `Binder.getCallingUid()` 大量使用
- `Process.SYSTEM_UID` 检查 (line 915)

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 权限查询方法通常不需要特殊权限
- `grantRuntimePermission()`, `revokeRuntimePermission()` 有 UID 和权限级别检查
- 恶意应用无法直接授予自身权限（受 UID 和已知权限限制）

**shell 攻击面**: 
- 无直接 shellCommand，但 `dump()` (line 1727) 输出权限状态
- 可通过 `adb shell pm grant/revoke` 操作

---

### 1.8 DevicePolicyManagerService (设备策略管理服务)

**功能**: 管理设备管理员策略、配置设备所有者/资料所有者。

**原理**:
- 注册为 `Context.DEVICE_POLICY_SERVICE`
- 维护每个用户的策略状态
- 协调与系统各组件的策略执行

**App 交互**:
```java
DevicePolicyManager dpm = (DevicePolicyManager) getSystemService(
    Context.DEVICE_POLICY_SERVICE);
// 检查是否为设备管理员
boolean isAdmin = dpm.isAdminActive(adminComponent);
// 设置密码策略
dpm.setPasswordQuality(adminComponent, PASSWORD_QUALITY_COMPLEX);
// 锁定设备
dpm.lockNow();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `BIND_DEVICE_ADMIN` (normal) | 成为设备管理员的必要条件 | manifest 声明 |
| `MANAGE_PROFILE_AND_DEVICE_OWNERS` (system) | 管理资料/设备所有者 | `checkCallingPermission` |
| `MANAGE_DEVICE_POLICY_*` (60+ 权限) | 精细策略控制（每个策略域一个权限） | `checkCallingPermission` |
| `LOCK_DEVICE` (privileged) | 锁定设备 | `checkCallingPermission` |
| `SET_TIME` / `SET_TIME_ZONE` (privileged) | 设置时间/时区 | `checkCallingPermission` |
| `MASTER_CLEAR` (system) | 恢复出厂设置 | `checkCallingPermission` |

**Binder 权限验证**:
- `checkCallingPermission()` 用于 60+ 个 `MANAGE_DEVICE_POLICY_*` 权限
- `Process.SYSTEM_UID` 检查 (lines 11078, 11365, 13619)
- `Process.SHELL_UID` 检查 (line 11373)
- `Process.ROOT_UID` 检查 (line 16224)
- 基于 DPM 模型的复杂策略检查

**SELinux**: `system_server` 域

**transact 攻击面**: 
- `isAdminActive()`, `isDeviceOwnerApp()` 等查询方法需要 `BIND_DEVICE_ADMIN`
- 策略设置方法需要对应的 `MANAGE_DEVICE_POLICY_*` 权限
- 设备管理 API 是最复杂的权限模型之一

**shell 攻击面**: 
- `onShellCommand()` (line 11590) → DPM shell 命令
- `dump()` (line 11480) 输出策略状态

---

### 1.9 VoiceInteractionManagerService (语音交互服务)

**功能**: 管理语音交互服务（如 Google Assistant）的注册、激活和事件分发。

**原理**:
- 注册为 `Context.VOICE_INTERACTION_MANAGER_SERVICE`
- 维护当前活跃的语音交互会话
- 协调麦克风/摄像头资源的独占访问

**App 交互**:
```java
// 应用启动语音交互
Intent intent = new Intent(Intent.ACTION_VOICE_COMMAND);
startActivity(intent);

// 语音交互服务实现
public class MyVoiceInteractionService extends VoiceInteractionService {
    // 处理语音请求
}
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `RECORD_AUDIO` (dangerous) | 录音访问 | `enforceCallingPermission` |
| `CAMERA` (dangerous) | 摄像头访问 | `enforceCallingPermission` |
| `CAPTURE_AUDIO_HOTWORD` (privileged) | 热词检测录音 | `enforceCallingPermission` |
| `MANAGE_VOICE_KEYPHRASES` (privileged) | 管理语音快捷键 | `enforceCallingPermission` |
| `START_TASKS_FROM_RECENTS` (privileged) | 从最近任务启动 | `@RequiresPermission` |

**Binder 权限验证**:
- `enforceCallingPermission` 用于 `RECORD_AUDIO`, `CAMERA` 等
- `Binder.getCallingUid()` 大量使用

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 启动语音交互需要 `RECORD_AUDIO` + `CAMERA`
- `createSoundTriggerSession()` 需要 `CAPTURE_AUDIO_HOTWORD`
- `setDisabled()` 等管理方法需要 system 权限

**shell 攻击面**: 
- `onShellCommand()` (line 2311) → VoiceInteraction shell 命令
- `dump()` (line 2291)

---

### 1.10 UsageStatsService (使用情况统计服务)

**功能**: 收集和管理应用使用情况统计，包括使用时长、频率、最后使用时间等。

**原理**:
- 注册为 `Context.USAGE_STATS_SERVICE`
- 维护基于用户的使用统计数据库
- 使用 `UsageStatsManagerInternal` 内部接口

**App 交互**:
```java
UsageStatsManager usm = (UsageStatsManager) getSystemService(
    Context.USAGE_STATS_SERVICE);
// 查询使用统计（需特殊权限）
List<UsageStats> stats = usm.queryUsageStats(
    UsageStatsManager.INTERVAL_DAILY, startTime, endTime);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `PACKAGE_USAGE_STATS` (special/appop) | 查询使用统计 | `checkCallingPermission` |
| `REPORT_USAGE_STATS` (privileged) | 报告使用情况 | `checkCallingPermission` |
| `OBSERVE_APP_USAGE` (privileged) | 观察应用使用情况 | `checkCallingPermission` |

**Binder 权限验证**:
- `checkCallingPermission` 用于 `PACKAGE_USAGE_STATS`, `REPORT_USAGE_STATS`, `OBSERVE_APP_USAGE`
- `enforceCallingPermission` 用于配置方法
- `Process.SYSTEM_UID` 检查 (lines 735, 749, 2223, 2251, 2264)

**SELinux**: `system_server` 域

**transact 攻击面**: 
- `queryUsageStats()` 需要 `PACKAGE_USAGE_STATS`（特殊权限，需用户在设置中授权）
- `queryEvents()` 等读取方法需要权限
- `setAppInactive()` 等控制方法需要 `PACKAGE_USAGE_STATS`

**shell 攻击面**: 
- 无直接 shellCommand
- `dump()` (line 2769) 输出使用统计

---

### 1.11 RestrictionsManagerService (限制管理服务)

**功能**: 管理系统限制（如家长控制、企业限制），允许临时管理者设置和查询限制。

**原理**:
- 注册为 `Context.RESTRICTIONS_SERVICE`
- 维护限制键值对，按用户存储
- 广播限制变化事件

**App 交互**:
```java
RestrictionsManager rm = (RestrictionsManager) getSystemService(
    Context.RESTRICTIONS_SERVICE);
// 查询限制
Bundle restrictions = rm.getManifestRestrictions(permission);
// 请求权限（临时管理者）
Intent intent = rm.createLocalApprovalIntent();
```

**Manifest 权限及功效**: 无特殊权限要求

**Binder 权限验证**: `Binder.getCallingUid()` 用于跟踪

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 查询方法无严格权限限制
- 设置限制需要成为临时管理者（通过 `requestPermission` 流程）

**shell 攻击面**: 无

---

### 1.12 CompanionDeviceManagerService (伴侣设备管理服务)

**功能**: 管理伴侣设备（如智能手表）的关联、发现和消息传递。

**原理**:
- 注册为 `Context.COMPANION_DEVICE_SERVICE`
- 维护设备关联列表
- 协调 BLE/蓝牙/WiFi 设备发现

**App 交互**:
```java
CompanionDeviceManager cdm = (CompanionDeviceManager) getSystemService(
    Context.COMPANION_DEVICE_SERVICE);
// 启动设备关联
cdm.associate(matcher, new MyCallback(), null);
// 获取已关联设备
List<String> devices = cdm.getAssociations();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_COMPANION_DEVICES` (privileged) | 管理设备关联 | `@EnforcePermission` |
| `USE_COMPANION_TRANSPORTS` (privileged) | 使用伴侣传输 | `@EnforcePermission` |
| `REQUEST_OBSERVE_COMPANION_DEVICE_PRESENCE` (privileged) | 观察设备存在 | `@EnforcePermission` |
| `BLUETOOTH_CONNECT` (dangerous) | 蓝牙连接 | `@EnforcePermission` |
| `DELIVER_COMPANION_MESSAGES` (privileged) | 传递伴侣消息 | `@EnforcePermission` |
| `REQUEST_COMPANION_SELF_MANAGED` (privileged) | 自管理设备 | `@EnforcePermission` |
| `ASSOCIATE_COMPANION_DEVICES` (system) | 关联伴侣设备 | `@EnforcePermission` |

**Binder 权限验证**:
- `@EnforcePermission` 用于多数方法
- `getCallingUid()` + `SYSTEM_UID` 检查 (lines 631, 639, 647, 694, 727, 735)

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 设备发现/关联需要多种权限
- 自管理设备路径（`REQUEST_COMPANION_SELF_MANAGED`）可能有较大攻击面

**shell 攻击面**: 
- `dump()` (line 754)

---

### 1.13 TextToSpeechManagerService (文字转语音服务)

**功能**: 管理 TTS 引擎的注册和语音合成。

**原理**:
- 注册为 `Context.TEXT_TO_SPEECH_MANAGER_SERVICE`
- 维护 TTS 引擎连接

**App 交互**:
```java
TextToSpeech tts = new TextToSpeech(context, this);
tts.speak("hello", TextToSpeech.QUEUE_FLUSH, null, "utterance_id");
```

**Manifest 权限及功效**: 无特殊权限要求

**Binder 权限验证**: 最小权限检查

**SELinux**: `system_server` 域

**transact 攻击面**: 
- TTS 操作无严格权限限制
- 可能用于触发第三方 TTS 引擎的漏洞

**shell 攻击面**: 无

---

### 1.14 CredentialManagerService (凭证管理服务)

**功能**: 管理凭证的创建、存储和检索（Android 14+ 新 API，与 AndroidX Credential Manager 对应）。

**原理**:
- 注册为 `CREDENTIAL_SERVICE`
- 协调应用与凭证提供者之间的交互

**App 交互**:
```java
CredentialManager cm = getSystemService(CredentialManager.class);
// 获取凭证
GetCredentialRequest request = new GetCredentialRequest.Builder()
    .addCredentialOption(new PublicKeyCredentialOption(...))
    .build();
cm.getCredentialAsync(request, null, executor, callback);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `CREDENTIAL_MANAGER_SET_ORIGIN` (privileged) | 设置凭证来源 | `enforceCallingPermission` |
| `CREDENTIAL_MANAGER_SET_ALLOWED_PROVIDERS` (privileged) | 设置允许的凭证提供者 | `enforceCallingPermission` |

**Binder 权限验证**:
- `enforceCallingPermission` 用于 `CREDENTIAL_MANAGER_SET_ORIGIN`, `CREDENTIAL_MANAGER_SET_ALLOWED_PROVIDERS`
- `Binder.getCallingUid()` 大量使用

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 凭证获取/创建流程有复杂的多方验证
- 设置方法需要 system 权限

**shell 攻击面**: 无

---

### 1.15 AppPredictionManagerService (应用预测服务)

**功能**: 管理应用预测目标（如 dock 预测、分享目标预测）。

**原理**:
- 注册为 `APP_PREDICTION_SERVICE`
- 协调应用与预测服务

**App 交互**:
```java
AppPredictionManager apm = getSystemService(AppPredictionManager.class);
// 创建预测会话
AppPredictionSession session = apm.createAppPredictionSession(
    new AppPredictionContext.Builder().build());
// 请求预测
session.requestPredictionUpdate();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_APP_PREDICTIONS` (privileged) | 管理方法（调试、重置） | `enforceCallingPermission` |
| `PACKAGE_USAGE_STATS` (special) | 访问使用统计 | `checkCallingPermission` |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_APP_PREDICTIONS`
- `Binder.getCallingUid()` + `SYSTEM_UID` 检查

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 预测更新等方法无严格权限限制
- 管理方法需要 `MANAGE_APP_PREDICTIONS`

**shell 攻击面**: 
- `onShellCommand()` (line 173)
- 可通过 `adb shell cmd app_prediction` 操作

---

### 1.16 ContentCaptureManagerService (内容捕获服务)

**功能**: 管理内容捕获（如截屏内容分析、自动填充数据源）。

**原理**:
- 注册为 `CONTENT_CAPTURE_MANAGER_SERVICE`
- 协调应用与内容捕获服务

**App 交互**:
```java
ContentCaptureManager ccm = getSystemService(ContentCaptureManager.class);
// 检查是否启用
boolean enabled = ccm.isContentCaptureEnabled();
// 设置内容捕获Enabled（需权限）
ccm.setContentCaptureEnabled(enabled);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_CONTENT_CAPTURE` (privileged) | 管理方法 | `enforceCallingPermission` |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_CONTENT_CAPTURE`

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 查询方法无严格权限限制
- 设置方法需要 `MANAGE_CONTENT_CAPTURE`

**shell 攻击面**: 
- `onShellCommand()` (line 1296)
- `dump()` (line 1261)

---

### 1.17 MusicRecognitionManagerService (音乐识别服务)

**功能**: 管理音乐识别（如 Now Playing）功能。

**原理**:
- 注册为 `MUSIC_RECOGNITION_SERVICE`
- 协调音乐识别请求和处理

**App 交互**:
```java
MusicRecognitionManager mrm = getSystemService(MusicRecognitionManager.class);
// 触发识别
mrm.beginRecognition(request, executor, callback);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_MUSIC_RECOGNITION` (privileged) | 管理方法 | `enforceCallingPermission` |
| `MICROPHONE` (manifest) | 访问麦克风 | manifest 声明 |

**Binder 权限验证**:
- `checkCallingPermission(MANAGE_MUSIC_RECOGNITION)` 用于查询
- `enforceCallingPermissionForManagement()` 用于管理

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 识别请求无严格权限限制
- 管理方法需要 `MANAGE_MUSIC_RECOGNITION`

**shell 攻击面**: 
- `onShellCommand()` (line 138)

---

### 1.18 TranslationManagerService (翻译服务)

**功能**: 管理 UI 翻译和文本翻译。

**原理**:
- 注册为 `TRANSLATION_MANAGER_SERVICE`
- 协调翻译服务

**App 交互**:
```java
TranslationManager tm = getSystemService(TranslationManager.class);
// 创建翻译会话
TranslationContext context = tm.createTranslationContext(
    sourceSpec, targetSpec, 0);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_UI_TRANSLATION` (privileged) | 管理方法 | `enforceCallingPermission` |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_UI_TRANSLATION`

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 翻译请求无严格权限限制
- 管理方法需要 `MANAGE_UI_TRANSLATION`

**shell 攻击面**: 
- `onShellCommand()` (line 316)
- `dump()` (line 302)

---

### 1.19 SmartspaceManagerService (智能空间服务)

**功能**: 管理智能空间（如锁屏卡片、气泡卡片）内容更新。

**原理**:
- 注册为 `SMARTSPACE_SERVICE`
- 协调智能空间卡片更新

**App 交互**: 主要通过内部 API

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_SMARTSPACE` (privileged) | 管理方法 | `enforceCallingPermission`, `checkCallingPermission` |
| `ACCESS_SMARTSPACE` (privileged) | 访问智能空间 | `checkCallingPermission` |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_SMARTSPACE`
- `checkCallingPermission` 用于访问控制

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 卡片更新需要 `MANAGE_SMARTSPACE` 或 `ACCESS_SMARTSPACE`

**shell 攻击面**: 
- `onShellCommand()` (line 148)

---

### 1.20 SupervisionManagerService (监督模式服务)

**功能**: 管理家长控制/监督模式功能。

**原理**:
- 注册为 `SUPERVISION_SERVICE`
- 协调监督功能

**Manifest 权限及功效**: 无特殊权限要求

**Binder 权限验证**: 无显式权限检查

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 监督功能方法无严格权限限制
- 可能有 UID 检查

**shell 攻击面**: 
- `onShellCommand()` (line 51) → `SupervisionServiceShellCommand`
- `dump()` (line 63)

---

### 1.21 SystemCaptionsManagerService (系统字幕服务)

**功能**: 管理系统字幕生成。

**原理**:
- 不发布 binder 服务（仅内部使用）
- 协调字幕生成

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**: N/A

**SELinux**: `system_server` 域

**transact 攻击面**: 无 binder 服务，无法直接 transact

**shell 攻击面**: 无

---

### 1.22 WallpaperEffectsGenerationManagerService (壁纸效果生成服务)

**功能**: 管理壁纸效果生成（如动态壁纸特效）。

**原理**:
- 注册为 `WALLPAPER_EFFECTS_GENERATION_SERVICE`
- 协调壁纸效果生成

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_WALLPAPER_EFFECTS_GENERATION` (privileged) | 管理方法 | `enforceCallingPermission` |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_WALLPAPER_EFFECTS_GENERATION`

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 效果生成方法无严格权限限制
- 管理方法需要权限

**shell 攻击面**: 
- `onShellCommand()` (line 133)

---

### 1.23 AppFunctionManagerService (应用函数服务)

**功能**: 管理应用函数（Android 15 新 API，支持应用暴露可调用函数）。

**原理**:
- 注册为 `APP_FUNCTION_SERVICE`
- 协调应用函数的注册和调用

**App 交互**:
```java
AppFunctionManager afm = getSystemService(AppFunctionManager.class);
// 执行函数
afm.executeAppFunction(functionRequest, executor, callback);
```

**Manifest 权限及功效**: 无特殊权限要求（权限检查在 impl 层）

**Binder 权限验证**: 委托给 impl 层

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 函数执行无严格 manifest 权限要求
- 依赖 impl 层 UID/Permission 校验

**shell 攻击面**: 无

---

### 1.24 ContentSuggestionsManagerService (内容建议服务)

**功能**: 管理内容建议（如主屏幕建议）。

**原理**:
- 注册为内容建议服务
- 协调建议更新

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_CONTENT_SUGGESTIONS` (privileged) | 管理方法 | `enforceCallingPermission` |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_CONTENT_SUGGESTIONS`
- `Process.SHELL_UID` 检查 (line 280)

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 建议请求无严格权限限制
- 管理方法需要权限

**shell 攻击面**: 
- `onShellCommand()` (line 274)

---

### 1.25 ContextualSearchManagerService (上下文搜索服务)

**功能**: 管理上下文搜索（如 Now on Tap/长按搜索）。

**原理**:
- 注册为 `CONTEXTUAL_SEARCH_SERVICE`
- 协调上下文搜索触发

**App 交互**: 主要通过内部 API

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `START_TASKS_FROM_RECENTS` (privileged) | 从最近任务启动 | `@RequiresPermission` |
| `ACCESS_CONTEXTUAL_SEARCH` (privileged) | 访问上下文搜索 | `checkCallingPermission` |

**Binder 权限验证**:
- `checkCallingPermission(ACCESS_CONTEXTUAL_SEARCH)` 
- `SHELL_UID`, `ROOT_UID`, `SYSTEM_UID` 检查 (lines 389-391)

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 搜索触发需要 `ACCESS_CONTEXTUAL_SEARCH`

**shell 攻击面**: 
- `onShellCommand()` (line 517)

---

### 1.26 ProfcollectdManagerService (性能收集转发服务)

**功能**: 转发性能收集请求到 native `profcollectd`。

**原理**:
- 不发布 binder 服务
- 作为 Java 到 native 的桥接

**App 交互**: 无公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**: N/A

**SELinux**: `system_server` 域

**transact 攻击面**: 无 binder 服务

**shell 攻击面**: 
- `onShellCommand()` (line 58)
- `dump()` (line 63)

---

### 1.27 SearchUiManagerService (搜索 UI 服务)

**功能**: 管理搜索 UI 相关功能。

**原理**:
- 注册为 `SEARCH_UI_SERVICE`
- 协调搜索 UI

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_SEARCH_UI` (privileged) | 管理方法 | `enforceCallingPermission` |

**Binder 权限验证**:
- `enforceCallingPermissionForManagement()` 检查 `MANAGE_SEARCH_UI`

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 管理方法需要 `MANAGE_SEARCH_UI`

**shell 攻击面**: 
- `onShellCommand()` (line 148)

---

### 1.28 FeatureFlagsService (功能标志服务)

**功能**: 管理系统功能标志（Feature Flags）的同步和覆盖。

**原理**:
- 注册为 `FEATURE_FLAGS_SERVICE`
- 维护功能标志状态
- 协调跨进程标志同步

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `SYNC_FLAGS` (internal) | 同步标志 | `checkCallingOrSelfPermission` |
| `WRITE_FLAGS` (internal) | 写标志 | `checkCallingPermission` |

**Binder 权限验证**:
- `assertSyncPermission()` 检查 `SYNC_FLAGS`
- `assertWritePermission()` 检查 `WRITE_FLAGS`

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 读取标志需要 `SYNC_FLAGS`
- 修改标志需要 `WRITE_FLAGS`
- 功能标志可用于启用/禁用系统行为

**shell 攻击面**: 
- `FlagsShellCommand` (line 55)

---

### 1.29 NetworkStatsService (网络统计服务)

**功能**: 收集和管理网络使用统计数据。

**原理**:
- 注册为网络统计服务
- 维护每个应用/UID 的网络使用统计
- 使用 BPF 收集数据

**App 交互**:
```java
NetworkStatsManager nsm = getSystemService(NetworkStatsManager.class);
// 查询网络使用统计
NetworkStats stats = nsm.queryDetailsForUid(
    NetworkTemplate.buildTemplateMobileAll(subscriberId),
    startTime, endTime, uid);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `UPDATE_DEVICE_STATS` (system/privileged) | 更新设备统计 | `enforceCallingOrSelfPermission` |

**Binder 权限验证**:
- `enforceCallingOrSelfPermission(UPDATE_DEVICE_STATS)` 
- `Process.SYSTEM_UID` 检查

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 查询方法无严格权限限制（受 UID 匹配约束）
- 更新方法需要 `UPDATE_DEVICE_STATS`

**shell 攻击面**: 
- `dump()` (line 2892)

---

### 1.30 CoverageManagerService (覆盖率服务)

**功能**: 管理代码覆盖率数据收集。

**原理**:
- 注册为 `COVERAGE_SERVICE`
- 协调覆盖率数据收集

**Manifest 权限及功效**: 无特殊权限要求

**Binder 权限验证**: 无显式权限检查

**SELinux**: `system_server` 域

**transact 攻击面**: 
- 覆盖率数据收集无严格权限限制
- 可能影响系统性能

**shell 攻击面**: 
- `onShellCommand()` (line 51)

---

### 1.31 其他服务汇总

| 服务 | Manifest 权限 | UID 检查 | shellCommand | 主要攻击面 |
|------|---------------|----------|--------------|------------|
| **AppWidgetService** | `BIND_APPWIDGET`(privileged) | 是 | 是 | 小部件绑定/更新 |
| **MIDI Service** | `MIDI_PERMISSION` (internal) | 否 | 否 | MIDI 设备访问 |

---

## Framework Java 服务总结

| 维度 | 分析 |
|------|------|
| **权限检查模式** | 以 `enforceCallingPermission`/`enforceCallingOrSelfPermission` 为主，Android 15 引入 `@EnforcePermission` 注解 |
| **UID 检查** | 大量使用 `Binder.getCallingUid()`，`SYSTEM_UID`/`SHELL_UID`/`ROOT_UID` 用于特权操作 |
| **SELinux 保护** | 所有 Framework 服务运行于 `system_server` 域，app 无法直接访问 |
| **transact 风险** | 低权限可调用方法（如 `getInstalledAccessibilityServiceList`）可能被 transact 滥用；高权限方法受权限+SELinux 双重保护 |
| **shell 风险** | `onShellCommand` 和 `dump` 受 `SHELL_UID` 限制，但输出可能泄露敏感信息 |
| **关键漏洞点** | 1. `Binder.clearCallingIdentity()` 调用上下文切换 2. `@RequiresNoPermission` 方法 3. UID 检查不严的跨用户操作 |

---

## 二、Native 系统服务安全分析

### 2.1 SurfaceFlinger (Surface 合成服务)

**功能**: 管理系统中所有 Surface 的合成与显示，将各应用的窗口内容合成到屏幕上。

**原理**:
- 注册为 `"SurfaceFlinger"` 和 `"SurfaceFlingerAIDL"`
- 维护 `Layer` 树，每个窗口对应一个 Layer
- 通过 `Client` 对象管理应用连接
- 使用 HardwareComposer (HWC) 或 GPU 合成

**App 交互**:
```java
// 通过 WindowManager 间接交互
WindowManager wm = getSystemService(WindowManager.class);
// 创建 Surface（SurfaceView, TextureView 等）
SurfaceView sv = new SurfaceView(context);
sv.getHolder().getSurface();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查位置 |
|------|------|----------|
| `ACCESS_SURFACE_FLINGER` (system) | 直接访问 SurfaceFlinger | `CheckTransactCodeCredentials` |
| `READ_FRAME_BUFFER` (system) | 读取帧缓冲/截图 | `validateScreenshotPermissions` |
| `HARDWARE_TEST` (privileged) | 访问 backdoor transact codes | `CheckTransactCodeCredentials` |
| `DUMP` (system/privileged) | dump 操作 | `dump()` |
| `CONTROL_DISPLAY_BRIGHTNESS` (system) | 控制显示亮度 | `checkControlDisplayBrightnessPermission` |
| `CAPTURE_BLACKOUT_CONTENT` (system) | 捕获黑屏内容 | 权限检查 |
| `INTERNAL_SYSTEM_WINDOW` (system) | 创建内部系统窗口 | 权限检查 |
| `WAKEUP_SURFACE_FLINGER` (system) | 唤醒 SurfaceFlinger | 权限检查 |

**Binder 权限验证**:
- `CheckTransactCodeCredentials` (line 6067) — 根据 transact code 检查不同权限
- `validateScreenshotPermissions` (line 6802) — 截图权限：`AID_GRAPHICS`, `AID_SYSTEM`, 或 `READ_FRAME_BUFFER`
- 自截图豁免：`captureArgs.uid == uid` 时无需权限
- Backdoor codes (1000-1045)：仅需 `AID_SYSTEM` 或 `HARDWARE_TEST`

**SELinux**: `surfaceflinger` 域，`mlstrustedsubject`，`coredomain`

**transact 攻击面**: **HIGH**
- Legacy transact codes 1000-1045 是 backdoor codes，绕过正常权限检查
- 仅需 `AID_SYSTEM` 或 `HARDWARE_TEST` 即可调用
- 可通过 `IBinder.transact()` 直接调用，绕过 Java 层权限框架
- `SET_TRANSACTION_STATE` (code) 无显式权限要求

**shell 攻击面**: 
- `dump()` 需要 `AID_SHELL` 或 `DUMP` 权限
- 无直接 shellCommand 实现

---

### 2.2 SensorService (传感器服务)

**功能**: 管理设备传感器数据的采集和分发，包括加速度计、陀螺仪、心率等。

**原理**:
- 维护传感器列表和事件连接
- 通过 `SensorEventConnection` 向应用分发事件
- 支持传感器权限、AppOp、速率限制

**App 交互**:
```java
SensorManager sm = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
Sensor accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
sm.registerListener(listener, accelerometer, SensorManager.SENSOR_DELAY_NORMAL);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `HIGH_SAMPLING_RATE_SENSORS` (normal) | 高采样率 (>200Hz) | `isRateCappedBasedOnPermission` |
| 传感器专属权限 (如 `BODY_SENSORS`) | 访问特定传感器 | `hasPermissionForSensor` |

**Binder 权限验证**:
- `canAccessSensor()` (line 2292) — 综合检查：权限 + AppOp + UID 状态 + 传感器隐私
- `hasSensorAccess()` (line 528) — 检查传感器隐私、UID 活跃状态、操作限制
- Head Tracker 传感器：默认仅限 `AID_SYSTEM` 和 `AID_AUDIOSERVER`
- 预 Q SDK 应用：Step Counter/Detector 有豁免

**SELinux**: `sensors` 域

**transact 攻击面**: **MODERATE**
- 直接建立传感器事件连接可能绕过 Java 层
- 受传感器隐私状态和 UID 活跃状态限制

**shell 攻击面**: 
- `shellCommand` (line 910) 需要 `MANAGE_SENSORS` 权限
- 命令：`set-uid-state`, `reset-uid-state`, `get-uid-state`, `unrestrict-ht`, `restrict-ht`

---

### 2.3 GpuService (GPU 服务)

**功能**: 暴露 GPU 驱动统计信息、内存信息、Vulkan 属性。

**原理**:
- 收集 GPU 统计数据 (`GpuStats`)
- 管理 GPU 内存信息 (`GpuMem`)
- 提供 Vulkan 属性和 profile

**App 交互**:
```java
// 通过 GraphicsEnvironment 或间接 API
GpuManager gm = context.getSystemService(GpuManager.class);
String version = gm.getGpuDriverVersion();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `ACCESS_GPU_SERVICE` (system) | 访问 GPU 服务 | `toggleAngleAsSystemDriver` |
| `DUMP` (system/privileged) | dump 操作 | `doDump` |

**Binder 权限验证**:
- `toggleAngleAsSystemDriver()` — 需要 `AID_SYSTEM` AND `ACCESS_GPU_SERVICE`
- `setUpdatableDriverPath()` — 需要 `AID_SYSTEM`
- `doDump()` — 需要 `AID_SHELL` 或 `DUMP`

**SELinux**: `gpuservice` 域，`coredomain`，`bpfdomain`

**transact 攻击面**: **LOW-MODERATE**
- `shellCommand` 无显式权限检查（但 `doDump` 有）
- 直接 transact 可能访问 GPU 统计信息

**shell 攻击面**: 
- `shellCommand` (line 152) 无权限检查
- 命令：`vkjson`, `vkprofiles`, `help`

---

### 2.4 InputDispatcher / InputManager (输入服务)

**功能**: 管理输入事件的分发，将触摸/按键事件路由到正确的窗口。

**原理**:
- `InputDispatcher` 负责事件分发
- `InputManager` 管理输入通道
- 维护焦点窗口、触摸状态

**App 交互**:
```java
// 通过 View 间接交互
view.setOnTouchListener((v, event) -> {
    // 处理触摸事件
    return true;
});

// 注入输入事件（需权限）
Instrumentation inst = new Instrumentation();
inst.sendKeyDownUpSync(KeyEvent.KEYCODE_A);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `INJECT_EVENTS` (system/privileged) | 注入输入事件 | 框架层检查 |
| `FILTER_INPUT_EVENTS` (signature) | 过滤输入事件 | 框架层检查 |

**Binder 权限验证**:
- `injectInputEvent()` (line 4763) — 验证 HMAC 签名，无内置权限检查
- `createInputChannel()` (line 262) — 仅限 `AID_SHELL` 或 `AID_ROOT`
- 焦点验证：检查窗口是否属于正确 UID

**SELinux**: `inputflinger` 域，`coredomain`

**transact 攻击面**: **HIGH**
- `injectInputEvent` 在 InputDispatcher 层无内置权限检查
- 依赖框架层 `INJECT_EVENTS` 权限检查
- 直接 binder 调用可绕过框架层权限
- 需要正确的 HMAC 签名（但签名密钥可能从框架层获取）

**shell 攻击面**: 
- `createInputChannel` 仅限 `AID_SHELL`/`AID_ROOT`

---

### 2.5 AudioFlinger (音频服务)

**功能**: 管理音频播放和录制流的创建、混音和路由。

**原理**:
- 维护 `AudioTrack` (播放) 和 `AudioRecord` (录制) 对象
- 通过 `MixerThread` 混音多个播放流
- 与 `AudioPolicyService` 协作进行路由决策

**App 交互**:
```java
// 播放音频
AudioTrack track = new AudioTrack.Builder()
    .setAudioAttributes(new AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA).build())
    .setAudioFormat(new AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(44100).build())
    .build();
track.play();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `RECORD_AUDIO` (dangerous) | 音频录制 | 框架层检查 |
| `MODIFY_AUDIO_SETTINGS` (normal) | 修改音频设置 | 框架层检查 |

**Binder 权限验证**:
- `validateAttributionFromContextOrTrustedCaller()` (line 132) — 验证 attribution source
- 信任 UID：`AID_SYSTEM`, `AID_AUDIOSERVER`, `AID_MEDIA`, `AID_ROOT`
- `setMasterVolume`, `setMode` 等需要 `isServiceUid()` (UID < `AID_APP_START`)
- `onTransactWrapper()` (line 5149) — 阻止非系统进程的敏感操作

**SELinux**: `audioserver` 域

**transact 攻击面**: **MODERATE**
- `onTransactWrapper` 阻止部分敏感操作
- 信任 UID 绕过多数检查
- 非信任调用方无法伪造 UID/PID

**shell 攻击面**: 无直接 shellCommand

---

### 2.6 AudioPolicyService (音频策略服务)

**功能**: 管理音频路由策略，决定音频流输出到哪个设备。

**原理**:
- 维护音频端口、模块、路由规则
- 与 AudioFlinger 协作
- 处理音频策略决策

**App 交互**:
```java
AudioManager am = getSystemService(AudioManager.class);
am.setSpeakerphoneOn(true);
am.setMode(AudioManager.MODE_IN_CALL);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_AUDIO_POLICY` (system/privileged) | 管理音频策略 | `shellCommand` |

**Binder 权限验证**:
- `onTransact()` (line 1370) — 阻止非服务 UID 的敏感事务
- `getPermissionController` 需要 `isAudioServerOrSystemServerUid()`

**SELinux**: `audioserver` 域

**transact 攻击面**: **MODERATE**
- `onTransact` 显式阻止非服务 UID 的敏感事务

**shell 攻击面**: 
- `shellCommand()` (line 1454) 需要 `MANAGE_AUDIO_POLICY`

---

### 2.7 CameraService (相机服务)

**功能**: 管理相机设备的打开、配置和帧捕获。

**原理**:
- 维护相机设备列表
- 管理相机客户端连接
- 处理相机权限和 UID 状态

**App 交互**:
```java
CameraManager cm = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
cm.openCamera("0", new CameraDevice.StateCallback() {
    @Override
    public void onOpened(@NonNull CameraDevice camera) {
        // 使用相机
    }
}, null);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `CAMERA` (dangerous) | 访问相机 | `hasPermissionsForCamera` |
| `SYSTEM_CAMERA` (privileged) | 访问系统相机 | 权限检查 |
| `MANAGE_CAMERA` (privileged) | 管理相机 | `shellCommand` |
| `CAMERA_HEADLESS_SYSTEM_USER` (system) | 无头系统用户相机 | 权限检查 |
| `CAMERA_PRIVACY_ALLOWLIST` (internal) | 相机隐私白名单 | 权限检查 |
| `CAMERA_SEND_SYSTEM_EVENTS` (system) | 发送系统事件 | 权限检查 |
| `CAMERA_OPEN_CLOSE_LISTENER` (system) | 监听相机开关 | 权限检查 |
| `CAMERA_INJECT_EXTERNAL_CAMERA` (system) | 注入外部相机 | 权限检查 |

**Binder 权限验证**:
- `validateClientPermissionsLocked()` (line 1744) — 最全面的客户端验证：
  1. 系统相机拒绝检查
  2. CAMERA 权限检查
  3. UID 活跃状态检查
  4. 传感器隐私检查
  5. 用户前台检查
  6. 无头系统用户检查
- `callerHasSystemUid()` — `getCallingUid() < AID_APP_START`
- `isTrustedCallingUid()` — `AID_MEDIA`, `AID_CAMERASERVER`, `AID_RADIO`
- `resolveClientUid()` — 非信任调用方无法伪造 UID

**SELinux**: `cameraserver` 域，`coredomain`，`camera_service_server`

**transact 攻击面**: **LOW**
- 最全面的客户端验证
- `onTransact()` 处理 `SHELL_COMMAND_TRANSACTION` 需要 `MANAGE_CAMERA`

**shell 攻击面**: 
- `shellCommand` (line 5933) 需要 `MANAGE_CAMERA`
- 命令：`set-uid-state`, `reset-uid-state`, `get-uid-state`, `set-rotate-and-crop`, `get-rotate-and-crop`, `set-autoframing`, `get-autoframing`, `set-image-dump-mask`, `get-image-dump-mask`, `set-camera-mute`, `set-stream-use-case-override`, `clear-stream-use-case-override`, `set-zoom-override`, `watch`, `set-watchdog`, `help`

---

### 2.8 Vold (存储卷守护进程)

**功能**: 管理存储卷的挂载、卸载、加密和格式化。

**原理**:
- 维护卷列表和挂载状态
- 处理文件系统操作
- 管理外部存储和 OBB

**App 交互**:
```java
StorageManager sm = getSystemService(StorageManager.class);
// 获取存储卷信息
List<StorageVolume> volumes = sm.getStorageVolumes();
// 挂载 OBB
sm.mountObb(path, key, callback);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_EXTERNAL_STORAGE` (privileged) | 管理外部存储 | 框架层 |
| `MOUNT_UNMOUNT_FILESYSTEMS` (system) | 挂载/卸载文件系统 | 框架层 |

**Binder 权限验证**:
- `CheckPermission()` — 检查 `DUMP` 权限
- `CheckUidOrRoot()` — `uid == expectedUid || uid == AID_ROOT`
- `ENFORCE_SYSTEM_OR_ROOT` 宏 — 多数操作需要 `AID_SYSTEM` 或 `AID_ROOT`

**SELinux**: `vold` 域，`coredomain`

**transact 攻击面**: **LOW**
- 多数操作需要 `AID_SYSTEM` 或 `AID_ROOT`

**shell 攻击面**: 
- 无直接 shellCommand（通过 CommandListener 处理）

---

### 2.9 Netd (网络守护进程)

**功能**: 管理网络接口、防火墙规则、DNS、带宽控制。

**原理**:
- 维护网络栈配置
- 处理防火墙规则
- 管理带宽和 QoS

**App 交互**:
```java
ConnectivityManager cm = getSystemService(ConnectivityManager.class);
// 请求网络
cm.requestNetwork(request, callback);
// 绑定到网络
cm.bindProcessToNetwork(network);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `NETWORK_STACK` (internal) | 网络栈访问 | `ENFORCE_NETWORK_STACK_PERMISSIONS` |
| `MAINLINE_NETWORK_STACK` (internal) | 主线网络栈 | `ENFORCE_NETWORK_STACK_PERMISSIONS` |
| `ACCESS_NETWORK_STATE` (normal) | 访问网络状态 | 框架层 |
| `CHANGE_NETWORK_STATE` (normal) | 修改网络状态 | 框架层 |

**Binder 权限验证**:
- `ENFORCE_NETWORK_STACK_PERMISSIONS()` 宏 — 检查 `NETWORK_STACK` 或 `MAINLINE_NETWORK_STACK`
- `checkAnyPermission()` — `AID_SYSTEM` 始终允许（绕过权限检查）
- `AID_NETWORK_STACK` 允许 `MAINLINE_NETWORK_STACK`

**SELinux**: `netd` 域，`coredomain`，`bpfdomain`

**transact 攻击面**: **LOW**
- 多数操作需要 `NETWORK_STACK` 或 `MAINLINE_NETWORK_STACK`
- `AID_SYSTEM` 绕过检查

**shell 攻击面**: 
- 无直接 shellCommand（通过 CommandListener 处理）

---

### 2.10 GatekeeperD (Gatekeeper 守护进程)

**功能**: 管理 Gatekeeper 注册、验证和删除操作。

**原理**:
- 处理 Gatekeeper 事务
- 与 Trusty/TEE 中的 Gatekeeper TA 通信

**App 交互**:
```java
// 通过 LockSettingsService 间接交互
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `ACCESS_KEYGUARD_SECURE_STORAGE` (system) | 访问 Keyguard 安全存储 | `enroll`, `verify`, `deleteUser` |
| `DUMP` (system/privileged) | dump 操作 | `dump` |

**Binder 权限验证**:
- `enroll()` (line 171) — 需要 `ACCESS_KEYGUARD_SECURE_STORAGE`
- `verify()` (line 292) — 需要 `ACCESS_KEYGUARD_SECURE_STORAGE`
- `deleteUser()` (line 428) — 需要 `ACCESS_KEYGUARD_SECURE_STORAGE`
- `dump()` (line 465) — 需要 `DUMP`

**SELinux**: `gatekeeperd` 域，`coredomain`

**transact 攻击面**: **LOW**
- 所有操作需要 `ACCESS_KEYGUARD_SECURE_STORAGE`

**shell 攻击面**: 无

---

### 2.11 Installd (安装守护进程)

**功能**: 管理应用数据的创建、清理、快照和恢复。

**原理**:
- 处理应用数据目录操作
- 管理 dexopt/ART 编译
- 处理快照和恢复

**App 交互**: 无直接公共 API，通过 PackageManagerService 间接交互

**Manifest 权限及功效**: N/A（不直接暴露给 app）

**Binder 权限验证**:
- `checkUid()` (line 157) — `uid == expectedUid || uid == AID_ROOT`
- `ENFORCE_UID(AID_SYSTEM)` 宏 — 几乎所有操作需要 `AID_SYSTEM`

**SELinux**: `installd` 域，`coredomain`

**transact 攻击面**: **LOW**
- 所有操作需要 `AID_SYSTEM` 或 `AID_ROOT`

**shell 攻击面**: 无

---

### 2.12 ServiceManager (服务管理器)

**功能**: 管理系统服务的注册和查找。

**原理**:
- 维护服务名称到 IBinder 的映射
- 处理服务注册/注销
- 管理服务查找权限

**App 交互**:
```java
// 通过 getSystemService() 间接交互
IBinder binder = ServiceManager.getService("service_name");
```

**Manifest 权限及功效**: N/A（SELinux 控制）

**Binder 权限验证**:
- `addService()` (line 498) — `multiuser_get_app_id(ctx.uid) >= AID_APP` → 拒绝（App UID 不能添加服务）
- `canAddService()` → `mAccess->canAdd()` → SELinux `selinux_check_access()`
- `getService()` (line 425) — `mAccess->canFind()` → SELinux 检查
- 隔离应用被阻止查找非白名单服务

**SELinux**: `servicemanager` 域，`coredomain`

**transact 攻击面**: **VERY LOW**
- 所有访问由 SELinux 控制
- 无 UID 绕过

**shell 攻击面**: 无

---

### 2.13 Apexd (APEX 管理)

**功能**: 管理 APEX 模块的激活、停用和回滚。

**原理**:
- 维护 APEX 模块列表
- 处理模块激活流程
- 管理快照和回滚

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- `CheckCallerIsRoot()` (line 56) — `uid != AID_ROOT` → 拒绝
- `CheckCallerSystemOrRoot()` (line 66) — `uid != AID_ROOT && uid != AID_SYSTEM` → 拒绝
- Root 操作：`stagePackages`, `resumeRevertIfNeeded`, `remountPackages` 等
- System/Root 操作：`submitStagedSession`, `markStagedSessionReady` 等

**SELinux**: `apexd` 域，`coredomain`

**transact 攻击面**: **LOW**
- 所有操作需要 `AID_ROOT` 或 `AID_SYSTEM`

**shell 攻击面**: 
- `shellCommand` (line 867) 无显式权限检查
- 命令：`help`, `stagePackages`

---

### 2.14 UpdateEngine (OTA 更新引擎)

**功能**: 管理 OTA 更新的下载、验证和应用。

**原理**:
- 处理 A/B 更新
- 管理 payload 应用
- 协调启动控制

**App 交互**:
```java
UpdateEngine ue = new UpdateEngine();
ue.bind(new UpdateEngineCallback() {
    @Override
    public void onPayloadApplicationComplete(int errorCode) {}
    @Override
    public void onStatusUpdate(int status, float percent) {}
}, handler);
ue.applyPayload(url, offset, size, headerKeyValuePairs);
```

**Manifest 权限及功效**: N/A（SELinux 控制）

**Binder 权限验证**:
- 无显式权限检查
- 完全依赖 SELinux 策略

**SELinux**: `update_engine` 域，`coredomain`

**transact 攻击面**: **MODERATE**
- 无显式权限检查
- 仅依赖 SELinux 策略

**shell 攻击面**: 无

---

### 2.15 Storaged (存储统计)

**功能**: 收集和存储使用统计数据。

**原理**:
- 收集每个 UID 的 I/O 统计
- 暴露给 dumpsys

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- `dump()` (line 96) — 需要 `AID_SHELL` 或 `DUMP`

**SELinux**: `storaged` 域，`coredomain`，`mlstrustedsubject`

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 2.16 Tombstoned (Tombstone 收集)

**功能**: 收集和管理进程崩溃时的 tombstone 数据。

**原理**:
- 监听 debuggerd 信号
- 收集 tombstone 数据
- 暴露给 dumpsys

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- 无显式权限检查
- 通过 SELinux 和文件权限控制

**SELinux**: `tombstoned` 域，`coredomain`

**transact 攻击面**: **MODERATE**
- 无显式权限检查
- 依赖 SELinux 策略

**shell 攻击面**: 无

---

## Native 服务总结

| 维度 | 分析 |
|------|------|
| **权限检查模式** | 混合模式：UID 检查 (`AID_SYSTEM`/`AID_ROOT`) + 权限字符串检查 + SELinux |
| **UID 检查** | 大量使用 `multiuser_get_app_id(uid)` 和硬编码 UID 比较 |
| **SELinux 保护** | 所有 Native 服务有独立 SELinux 域，app 无法直接访问 |
| **transact 风险** | **SurfaceFlinger** (backdoor codes) 和 **InputDispatcher** (无内置权限检查) 风险最高 |
| **shell 风险** | `shellCommand` 实现不一致：GpuService 无权限检查，其他需要特定权限 |
| **关键漏洞点** | 1. SurfaceFlinger backdoor codes 1000-1045 2. InputDispatcher 无内置权限检查 3. 信任 UID 绕过 4. APEX shellCommand 无权限检查 |

---

## 三、媒体服务安全分析

### 3.1 AudioFlinger (音频核心服务)

**功能**: 管理音频播放/录制流的创建、混音和路由。所有应用音频输出的底层引擎。

**原理**:
- 运行于 `audioserver` 进程
- 维护 `AudioTrack` (播放) 和 `AudioRecord` (录制) 对象
- 通过 `MixerThread` 混音多个播放流
- 与 `AudioPolicyService` 协作进行路由决策
- 使用 `AudioFlingerServerAdapter` 包装 Binder 接口

**App 交互**:
```java
// 播放音频
AudioTrack track = new AudioTrack.Builder()
    .setAudioAttributes(new AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA).build())
    .setAudioFormat(new AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(44100).build())
    .build();
track.play();

// 录制音频
AudioRecord record = new AudioRecord.Builder()
    .setAudioFormat(new AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(44100).build())
    .setBufferSizeInBytes(bufferSize)
    .build();
record.startRecording();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MODIFY_AUDIO_SETTINGS` (normal) | 修改主音量、模式、麦克风静音等 | `settingsAllowed()` |
| `DUMP` (system/privileged) | dump 操作 | `dumpAllowed()` |
| `RECORD_AUDIO` (dangerous) | 音频录制 | 框架层 + 权限检查器 |

**Binder 权限验证**:
- `settingsAllowed()` — 检查 `MODIFY_AUDIO_SETTINGS` 或 `isAudioServerUid`
- `dumpAllowed()` — 检查 `DUMP` 权限
- `setLowRamDevice` — 需要 `isAudioServerOrSystemServerUid`
- `checkStreamType` — 非音频服务器 UID 不能访问非公共流类型
- `setParameters` — 过滤保留参数（`filterReservedParameters`），非音频服务器 UID 不能设置路由/采样率/格式等
- `validateAttributionFromContextOrTrustedCaller` — 信任 UID 自动填充 attribution，非信任 UID 使用 binder 上下文

**UID 辅助函数**:
```
isServiceUid(uid)          → app_id < AID_APP_START (10000)
isAudioServerUid(uid)      → uid == AID_AUDIOSERVER (1041)
isAudioServerOrSystemServerUid(uid) → AID_SYSTEM || AID_AUDIOSERVER
isAudioServerOrMediaServerOrSystemServerOrRootUid(uid) → AID_SYSTEM || AID_AUDIOSERVER || AID_MEDIA || AID_ROOT
```

**SELinux**: `audioserver` 域，`coredomain`

**transact 攻击面**: **MODERATE**
- `AudioFlingerServerAdapter` 使用 `TimeCheck` 超时检测
- 50+ 个 transact code 被跟踪
- 信任 UID 绕过多数检查
- 非信任调用方无法伪造 UID/PID

**shell 攻击面**: 无直接 shellCommand

---

### 3.2 AudioPolicyService (音频策略服务)

**功能**: 管理音频路由策略，决定音频流输出到哪个设备（扬声器、耳机、蓝牙等）。

**原理**:
- 运行于 `audioserver` 进程
- 维护音频端口、模块、路由规则
- 处理电话状态、助手服务 UID 等对路由的影响

**App 交互**:
```java
AudioManager am = getSystemService(AudioManager.class);
am.setSpeakerphoneOn(true);
am.setMode(AudioManager.MODE_IN_CALL);
am.startBluetoothSco();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_AUDIO_POLICY` (system/privileged) | 管理音频策略 | `shellCommand` |

**Binder 权限验证**:
- `onTransact()` — 阻止非服务 UID 的敏感事务（~50 个受保护事务）
- 被阻止的事务包括：`startOutput`, `stopOutput`, `releaseOutput`, `getInputForAttr`, `startInput` 等
- 系统独占事务：`setDeviceConnectionState`, `handleDeviceConfigChange`, `setPhoneState` 等
- `getPermissionController` — 需要 `isAudioServerOrSystemServerUid`
- 通知回调过滤：`isServiceUid(mUid)` 检查

**SELinux**: `audioserver` 域

**transact 攻击面**: **MODERATE**
- `onTransact` 显式阻止非服务 UID 的敏感事务
- 90+ 个 `BINDER_METHOD_ENTRY` 被跟踪

**shell 攻击面**: 
- `shellCommand()` 需要 `MANAGE_AUDIO_POLICY`
- 唯一命令：`purge_permission-cache`

---

### 3.3 CameraService (相机服务)

**功能**: 管理相机设备的打开、配置和帧捕获。

**原理**:
- 运行于 `cameraserver` 进程
- 维护相机设备列表和客户端连接
- 处理相机权限、UID 状态、传感器隐私

**App 交互**:
```java
CameraManager cm = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
cm.openCamera("0", new CameraDevice.StateCallback() {
    @Override
    public void onOpened(@NonNull CameraDevice camera) {
        // 创建 CaptureSession 和 CaptureRequest
    }
}, null);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `CAMERA` (dangerous) | 访问相机 | `hasPermissionsForCamera` |
| `SYSTEM_CAMERA` (privileged) | 访问系统相机 | `hasPermissionsForSystemCamera` |
| `MANAGE_CAMERA` (privileged) | 管理相机 | `shellCommand` |
| `CAMERA_HEADLESS_SYSTEM_USER` (system) | 无头系统用户相机 | 权限检查 |
| `CAMERA_PRIVACY_ALLOWLIST` (internal) | 相机隐私白名单 | 权限检查 |
| `CAMERA_SEND_SYSTEM_EVENTS` (system) | 发送系统事件 | 权限检查 |
| `CAMERA_OPEN_CLOSE_LISTENER` (system) | 监听相机开关 | 权限检查 |
| `CAMERA_INJECT_EXTERNAL_CAMERA` (system) | 注入外部相机 | 权限检查 |

**Binder 权限验证**:
- `validateClientPermissionsLocked()` — 最全面的客户端验证：
  1. 系统相机拒绝检查 (`shouldRejectSystemCameraConnection`)
  2. CAMERA 权限检查 (`hasPermissionsForCamera`)
  3. UID 活跃状态检查 (`mUidPolicy->isUidActive`)
  4. 传感器隐私检查 (`mSensorPrivacyPolicy->isSensorPrivacyEnabled`)
  5. 多用户前台检查
  6. 无头系统用户检查
- `callerHasSystemUid()` — `getCallingUid() < AID_APP_START`
- `isTrustedCallingUid()` — `AID_MEDIA`, `AID_CAMERASERVER`, `AID_RADIO`
- `resolveClientUid()` — 非信任调用方无法伪造 UID
- `injectSessionParams` — 需要 `CAMERA_INJECT_EXTERNAL_CAMERA`
- `filterSensitiveMetadataIfNeeded` — 无 CAMERA 权限时移除敏感元数据

**SELinux**: `cameraserver` 域，`coredomain`，`camera_service_server`

**transact 攻击面**: **LOW**
- 最全面的客户端验证
- `onTransact()` 处理 `SHELL_COMMAND_TRANSACTION` 需要 `MANAGE_CAMERA`

**shell 攻击面**: 
- `shellCommand` 需要 `MANAGE_CAMERA`
- 命令：`set-uid-state`, `reset-uid-state`, `get-uid-state`, `set-rotate-and-crop`, `get-rotate-and-crop`, `set-autoframing`, `get-autoframing`, `set-image-dump-mask`, `get-image-dump-mask`, `set-camera-mute`, `set-stream-use-case-override`, `clear-stream-use-case-override`, `set-zoom-override`, `watch`, `set-watchdog`, `help`

---

### 3.4 DrmServer/DRM 管理服务

**功能**: 管理 DRM 会话的创建、验证和销毁，与 DRM 插件交互。

**原理**:
- 运行于 `drmserver` 进程
- 维护 DRM 客户端列表
- 处理解密/转换会话

**App 交互**:
```java
DrmManagerClient client = new DrmManagerClient();
// 处理 DRM 内容
DrmInfoRequest request = new DrmInfoRequest(DrmInfoRequest.TYPE_REGISTRATION_INFO, "video/wvm");
DrmInfo info = client.acquireDrmInfo(request);
```

**Manifest 权限及功效**: 无特殊权限要求（基于 token）

**Binder 权限验证**:
- 无显式权限检查
- 基于 `uniqueId` token 的安全模型
- `dump()` 需要 `DUMP` 权限

**SELinux**: `drmserver` 域，`coredomain`，`mlstrustedsubject`，`net_domain`

**transact 攻击面**: **MODERATE**
- 无显式权限检查
- 依赖 token 机制
- 唯一有网络访问权限的媒体服务

**shell 攻击面**: 无

---

### 3.5 MediaPlayerService (媒体播放服务)

**功能**: 管理媒体播放器的创建和控制。

**原理**:
- 运行于 `mediaserver` 进程
- 维护播放器客户端列表
- 处理媒体资源管理

**App 交互**:
```java
MediaPlayer mp = MediaPlayer.create(context, Uri.parse("content://media/external/audio/media/1"));
mp.start();
```

**Manifest 权限及功效**: 无特殊权限要求

**Binder 权限验证**: 无显式权限检查

**SELinux**: `mediaserver` 域，`coredomain`

**transact 攻击面**: **MODERATE**
- 无显式权限检查
- 依赖 SELinux 策略

**shell 攻击面**: 无

---

### 3.6 ResourceManagerService (媒体资源管理服务)

**功能**: 管理媒体编解码器资源的分配和回收。

**原理**:
- 运行于 `mediaserver` 进程
- 维护资源列表和进程信息
- 处理资源回收决策

**App 交互**: 间接通过 MediaCodec/MediaPlayer

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MEDIA_RESOURCE_OVERRIDE_PID` (internal) | 覆盖 PID | `overridePid` |
| `GET_PROCESS_STATE_AND_OOM_SCORE` (internal) | 获取进程状态和 OOM 分数 | `overrideProcessInfo` |

**Binder 权限验证**:
- `addResource` — 非信任 PID/UID 被覆盖为调用方 PID/UID
- `overridePid` — 需要 `MEDIA_RESOURCE_OVERRIDE_PID`
- `overrideProcessInfo` — 需要 `GET_PROCESS_STATE_AND_OOM_SCORE`
- `dump` — 需要 `DUMP` 权限
- 资源回收优先级逻辑：`getLowestPriorityBiggestClient_l`, `getAllClients_l`

**SELinux**: `mediaserver` 域

**transact 攻击面**: **LOW-MODERATE**
- 关键操作有权限检查
- 资源回收逻辑可能被滥用

**shell 攻击面**: 无

---

### 3.7 MediaExtractorService (媒体提取服务)

**功能**: 解析媒体文件，提取音视频轨道和元数据。

**原理**:
- 运行于独立进程（`media.extractor`）
- 使用 Minijail 沙箱 + seccomp 策略
- 通过 FD 接收文件（不能直接打开数据文件）

**App 交互**:
```java
MediaExtractor extractor = new MediaExtractor();
extractor.setDataSource(path);
MediaFormat format = extractor.getTrackFormat(0);
```

**Manifest 权限及功效**: 无特殊权限要求

**Binder 权限验证**: 无显式权限检查

**SELinux**: `mediaextractor` 域，`coredomain`，`mlstrustedsubject`

**transact 攻击面**: **LOW**
- Minijail 沙箱 + seccomp 策略限制
- 不能直接打开数据文件（必须通过 FD）
- 网络访问被禁止

**shell 攻击面**: 无

---

### 3.8 MediaSwCodecService (软件编解码器服务)

**功能**: 提供软件编解码器（H.264, H.265, VP9 等）的实现。

**原理**:
- 运行于独立进程（`media.swcodec`）
- 使用 Minijail 沙箱 + seccomp 策略
- 注册编解码器服务

**App 交互**:
```java
MediaCodec codec = MediaCodec.createDecoderByType("video/avc");
codec.configure(format, surface, null, 0);
codec.start();
```

**Manifest 权限及功效**: 无特殊权限要求

**Binder 权限验证**: 无显式权限检查

**SELinux**: `media.swcodec` 域

**transact 攻击面**: **LOW**
- Minijail 沙箱 + seccomp 策略限制
- 网络访问被禁止

**shell 攻击面**: 无

---

### 3.9 TunerService (调谐器服务)

**功能**: 管理 TV 调谐器设备的访问。

**原理**:
- 注册为 `android.media.tv.tuner.TunerService`
- 支持懒加载 HAL

**App 交互**:
```java
Tuner tuner = new Tuner(context, null, Tuner.TUNER_TYPE_LIVE);
tuner.openDvbFrontEnd();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `ACCESS_TV_SHARED_FILTER` (privileged) | 访问共享过滤器 | `openSharedFilter` |

**Binder 权限验证**:
- `openSharedFilter` — 需要 `ACCESS_TV_SHARED_FILTER` + PID 匹配验证

**SELinux**: 独立域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 3.10 MediaMetrics (媒体指标服务)

**功能**: 收集音频/视频使用统计数据，上报到 StatsD。

**原理**:
- 运行于 `audioserver` 进程
- 收集 AudioTrack/AudioRecord 状态
- 上报到 StatsD

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- `recordingAllowed()` — 使用 `permission::PermissionChecker`（运行时权限）
- `startRecording()` — `checkPermissionForStartDataDeliveryFromDatasource`
- `finishRecording()` — `finishDataDeliveryFromDatasource`

**SELinux**: `audioserver` 域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 3.11 TranscodingService (转码服务)

**功能**: 管理媒体文件的转码（格式转换、分辨率调整等）。

**原理**:
- 通过媒体编解码器基础设施实现
- 管理转码会话

**App 交互**:
```java
MediaTranscodingManager mtm = getSystemService(MediaTranscodingManager.class);
mtm.addTranscodingRequest(request, executor, callback);
```

**Manifest 权限及功效**: 无特殊权限要求

**Binder 权限验证**: 无显式权限检查

**SELinux**: 依赖底层编解码器服务域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

## 媒体服务总结

| 维度 | 分析 |
|------|------|
| **权限检查模式** | 混合模式：UID 检查 + 权限字符串检查 + 信任/非信任调用方区分 |
| **UID 检查** | `isServiceUid` (< AID_APP_START), `isAudioServerUid` (== AID_AUDIOSERVER) 等 |
| **SELinux 保护** | 每个媒体服务有独立域，禁止网络访问（除 drmserver） |
| **沙箱技术** | mediaextractor 和 media.swcodec 使用 Minijail + seccomp |
| **transact 风险** | AudioFlinger 和 AudioPolicyService 有 onTransact 保护；DRM/MediaPlayer 无显式检查 |
| **shell 风险** | AudioPolicyService shellCommand 需要 MANAGE_AUDIO_POLICY |
| **关键漏洞点** | 1. DRM 服务无显式权限检查（token 模型） 2. MediaPlayer 无显式权限检查 3. 信任 UID 绕过 4. drmserver 有网络访问权限 |

---

## 四、系统核心守护进程安全分析

### 4.1 Init (系统初始化)

**功能**: 系统第一个用户空间进程，负责启动所有系统服务、管理属性、处理 uevent。

**原理**:
- PID 1，所有系统服务的祖先
- 解析 `.rc` 文件定义服务启动顺序
- 通过 Unix domain socket 接收控制命令
- 管理 property_service

**App 交互**: 无直接 binder IPC，通过 property 和 init 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无 binder IPC，使用 Unix domain socket + `SO_PEERCRED` 验证

**SELinux**: `init` 域

**transact 攻击面**: **VERY LOW**（无 binder IPC）

**shell 攻击面**: 
- 通过 `ctl.start`/`ctl.stop`/`ctl.restart` 控制服务
- `CheckControlPropertyPerms()` 检查控制属性权限

---

### 4.2 Property Service (属性服务)

**功能**: 管理系统属性（`ro.*`, `persist.*`, `sys.*` 等），提供全局键值存储。

**原理**:
- 通过 Unix domain socket 接收读写请求
- 维护属性数据库
- 处理属性触发器（`property:` 触发器）

**App 交互**:
```java
// 读取系统属性
String value = System.getProperty("ro.build.version.sdk");
// 通过 Build 类读取
String fingerprint = Build.FINGERPRINT;
```

**Manifest 权限及功效**: N/A（SELinux 控制）

**Binder 权限验证**: 无 binder IPC

**SELinux**: `init` 域（property_service 运行于 init 进程）

**权限检查**:
- `CheckPermissions()` — 基础权限检查
- `CheckMacPerms()` — SELinux MAC 检查
- `CheckControlPropertyPerms()` — 控制属性权限检查
- `CanReadProperty()` — 验证源上下文对目标上下文的 "file/read" 权限
- `SO_PEERCRED` 获取 pid/uid/gid，`getpeercon()` 获取 SELinux 上下文

**transact 攻击面**: **VERY LOW**（无 binder IPC）

**shell 攻击面**: 
- `getprop`/`setprop` 命令
- 控制属性需要相应权限

---

### 4.3 Vold (存储卷守护进程)

**功能**: 管理存储卷的挂载、卸载、加密和格式化。

**原理**:
- 维护卷列表和挂载状态
- 处理文件系统操作
- 管理外部存储和 OBB
- 使用 `ENFORCE_SYSTEM_OR_ROOT` 宏保护敏感操作

**App 交互**:
```java
StorageManager sm = getSystemService(StorageManager.class);
List<StorageVolume> volumes = sm.getStorageVolumes();
sm.mountObb(path, key, callback);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_EXTERNAL_STORAGE` (privileged) | 管理外部存储 | 框架层 |
| `MOUNT_UNMOUNT_FILESYSTEMS` (system) | 挂载/卸载文件系统 | 框架层 |
| `DUMP` (system/privileged) | dump 操作 | `dump()` |

**Binder 权限验证**:
- `ENFORCE_SYSTEM_OR_ROOT` 宏 — 多数操作需要 `AID_SYSTEM` 或 `AID_ROOT`
- `CheckUidOrRoot()` — `uid == expectedUid || uid == AID_ROOT`
- `CHECK_ARGUMENT_ID`, `CHECK_ARGUMENT_PATH`, `CHECK_ARGUMENT_HEX` — 输入验证
- 路径遍历检测：`/../` 检测
- 安全键盘检查：`mSecureKeyguardShowing` 延迟磁盘操作直到解锁
- 用户零门控：`mStartedUsers.find(0)` 检查

**SELinux**: `vold` 域，`coredomain`

**transact 攻击面**: **HIGH**
- 多数操作需要 `AID_SYSTEM` 或 `AID_ROOT`
- 文件系统操作（mount, unmount, format, partition）有 UID 检查
- 加密操作（fbeEnable, encryptFstab）有 UID 检查
- 输入验证：路径遍历检测、hex 验证、ID 格式检查

**shell 攻击面**: 
- 通过 CommandListener 处理 shell 命令
- 需要 `AID_SYSTEM` 或 `AID_ROOT`

---

### 4.4 Netd (网络守护进程)

**功能**: 管理网络接口、防火墙规则、DNS、带宽控制。

**原理**:
- 维护网络栈配置
- 处理防火墙规则
- 管理带宽和 QoS
- 使用 `ENFORCE_NETWORK_STACK_PERMISSIONS()` 宏

**App 交互**:
```java
ConnectivityManager cm = getSystemService(ConnectivityManager.class);
cm.requestNetwork(request, callback);
cm.bindProcessToNetwork(network);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `NETWORK_STACK` (internal) | 网络栈访问 | `ENFORCE_NETWORK_STACK_PERMISSIONS` |
| `MAINLINE_NETWORK_STACK` (internal) | 主线网络栈 | `ENFORCE_NETWORK_STACK_PERMISSIONS` |
| `CONNECTIVITY_INTERNAL` (internal) | 内部连接性 | `ENFORCE_ANY_PERMISSION` |
| `CONNECTIVITY_USE_RESTRICTED_NETWORKS` (internal) | 使用受限网络 | `ENFORCE_ANY_PERMISSION` |
| `NETWORK_BYPASS_PRIVATE_DNS` (internal) | 绕过私有 DNS | `ENFORCE_ANY_PERMISSION` |
| `DUMP` (system/privileged) | dump 操作 | 权限检查 |

**Binder 权限验证**:
- `ENFORCE_NETWORK_STACK_PERMISSIONS()` — 检查 `NETWORK_STACK` 或 `MAINLINE_NETWORK_STACK`
- `checkAnyPermission()` — `AID_SYSTEM` 自动允许（避免死锁）
- `AID_NETWORK_STACK` 允许 `MAINLINE_NETWORK_STACK`
- `NETD_BIG_LOCK_RPC` — 大锁保护

**SELinux**: `netd` 域，`coredomain`，`bpfdomain`

**transact 攻击面**: **HIGH**
- `AID_SYSTEM` 绕过权限检查（文档说明：system server 有 NETWORK_STACK 权限，无安全差异）
- 如果 system server 被攻破，netd 网络控制可被滥用
- 所有网络操作需要 `NETWORK_STACK_PERMISSIONS`

**shell 攻击面**: 
- 通过 CommandListener 处理 shell 命令
- 需要相应权限

---

### 4.5 LMKD (低内存杀手守护进程)

**功能**: 在系统内存不足时杀死进程以释放内存。

**原理**:
- 通过 Unix domain socket 接收命令
- 维护进程优先级列表
- 根据内存压力杀死进程

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无 binder IPC，使用 Unix socket + `SCM_CREDENTIALS`

**SELinux**: `lmkd` 域，`coredomain`

**权限检查**:
- `LMK_TARGET` — 速率限制（1000ms 一次）防 DoS
- `LMK_PROCPRIO` — 验证 `oomadj` 范围 [-1000, 1000]，验证 `ptype` 范围
- `LMK_PROCREMOVE` — 仅注册 PID 可以移除记录
- `LMK_PROCPURGE` — 仅清除请求者 PID 创建的记录
- `LMK_PROCKILL` — "NOT expected at all" — 记录为错误
- `pidfd_open()` 用于无竞态进程跟踪

**transact 攻击面**: **VERY LOW**（无 binder IPC）

**shell 攻击面**: 无

---

### 4.6 GatekeeperD (Gatekeeper 守护进程)

**功能**: 管理 Gatekeeper 注册、验证和删除操作。

**原理**:
- 处理 Gatekeeper 事务
- 与 Trusty/TEE 中的 Gatekeeper TA 通信

**App 交互**: 通过 LockSettingsService 间接交互

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `ACCESS_KEYGUARD_SECURE_STORAGE` (system) | 访问 Keyguard 安全存储 | `enroll`, `verify`, `deleteUser` |
| `DUMP` (system/privileged) | dump 操作 | `dump` |

**Binder 权限验证**:
- `enroll()` — 需要 `ACCESS_KEYGUARD_SECURE_STORAGE`
- `verify()` — 需要 `ACCESS_KEYGUARD_SECURE_STORAGE`
- `deleteUser()` — 需要 `ACCESS_KEYGUARD_SECURE_STORAGE`
- `dump()` — 需要 `DUMP`
- GSI 支持：User ID >= 1000000 被拒绝

**SELinux**: `gatekeeperd` 域，`coredomain`

**transact 攻击面**: **LOW**
- 所有操作需要 `ACCESS_KEYGUARD_SECURE_STORAGE`

**shell 攻击面**: 无

---

### 4.7 Installd (安装守护进程)

**功能**: 管理应用数据的创建、清理、快照和恢复。

**原理**:
- 处理应用数据目录操作
- 管理 dexopt/ART 编译
- 处理快照和恢复
- 使用 UID-based 访问控制

**App 交互**: 无直接公共 API，通过 PackageManagerService 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- `checkUid()` — `uid == expectedUid || uid == AID_ROOT`
- `ENFORCE_UID(AID_SYSTEM)` 宏 — 几乎所有操作需要 `AID_SYSTEM`
- 输入验证：`checkArgumentPath()`, `checkArgumentFileName()`, `checkArgumentUuid()`, `checkArgumentPackageName()`, `checkArgumentAppId()`
- 路径遍历检测：`/../` 检测、相对路径、null 字节、换行符
- AppId 范围验证：`FIRST_APPLICATION_UID` 到 `LAST_APPLICATION_UID`
- 细粒度锁：`UserLock` + `PackageLock`

**SELinux**: `installd` 域，`coredomain`

**transact 攻击面**: **MEDIUM**
- UID-based 访问控制（无 binder 权限检查）
- 依赖调用方为预期 UID
- 输入验证严格

**shell 攻击面**: 无

---

### 4.8 ServiceManager (服务管理器)

**功能**: 管理系统服务的注册和查找。

**原理**:
- 维护服务名称到 IBinder 的映射
- 处理服务注册/注销
- 管理服务查找权限

**App 交互**:
```java
IBinder binder = ServiceManager.getService("service_name");
```

**Manifest 权限及功效**: N/A（SELinux 控制）

**Binder 权限验证**:
- `addService()` — `multiuser_get_app_id(ctx.uid) >= AID_APP` → 拒绝（App UID 不能添加服务）
- `canAddService()` → `mAccess->canAdd()` → SELinux `selinux_check_access()`
- `getService()` — `mAccess->canFind()` → SELinux 检查
- 隔离应用被阻止查找非白名单服务
- `tryUnregisterService()` — 仅注册 PID 可以注销

**SELinux**: `servicemanager` 域，`coredomain`

**transact 攻击面**: **MEDIUM**
- 所有访问由 SELinux 控制
- App UID 不能添加服务
- 隔离应用被限制

**shell 攻击面**: 无

---

### 4.9 Apexd (APEX 管理)

**功能**: 管理 APEX 模块的激活、停用和回滚。

**原理**:
- 维护 APEX 模块列表
- 处理模块激活流程
- 管理快照和回滚

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- `CheckCallerIsRoot()` — 仅 `AID_ROOT` 允许
- `CheckCallerSystemOrRoot()` — `AID_ROOT` 或 `AID_SYSTEM` 允许
- `CheckDebuggable()` — 需要 `ro.debuggable=1`

**操作权限表**:

| 操作 | 所需 UID |
|------|----------|
| `stagePackages` | Root only |
| `unstagePackages` | System or Root |
| `submitStagedSession` | System or Root |
| `markStagedSessionReady` | System or Root |
| `markStagedSessionSuccessful` | System or Root |
| `getSessions` | System or Root |
| `getActivePackages` | System or Root |
| `abortStagedSession` | System or Root |
| `revertActiveSessions` | System or Root |
| `snapshotCeData` | System or Root |
| `restoreCeData` | System or Root |
| `markBootCompleted` | System or Root |
| `installAndActivatePackage` | System or Root |
| `resumeRevertIfNeeded` | Root only + debuggable |
| `remountPackages` | Root only + debuggable |
| `recollectPreinstalledData` | Root only + debuggable |
| `recollectDataApex` | Root only + debuggable |

**SELinux**: `apexd` 域，`coredomain`

**transact 攻击面**: **HIGH**
- 所有操作需要 `AID_ROOT` 或 `AID_SYSTEM`
- 模块管理是高权限操作

**shell 攻击面**: 
- `shellCommand` 无显式权限检查
- 命令：`stagePackages`, `getAllPackages`, `getActivePackages`, `activatePackage`, `deactivatePackage`, `getStagedSessionInfo`, `submitStagedSession`, `remountPackages`

---

### 4.10 UpdateEngine (OTA 更新引擎)

**功能**: 管理 OTA 更新的下载、验证和应用。

**原理**:
- 处理 A/B 更新
- 管理 payload 应用
- 协调启动控制

**App 交互**:
```java
UpdateEngine ue = new UpdateEngine();
ue.bind(callback, handler);
ue.applyPayload(url, offset, size, headerKeyValuePairs);
```

**Manifest 权限及功效**: N/A（SELinux 控制）

**Binder 权限验证**:
- 无显式权限检查
- 完全依赖 SELinux 策略

**SELinux**: `update_engine` 域，`coredomain`

**transact 攻击面**: **HIGH**
- 无显式权限检查
- 仅依赖 SELinux 策略
- `applyPayload()` 接受任意 URL + offset + size
- `applyPayloadFd()` 接受 ParcelFileDescriptor

**shell 攻击面**: 无

---

### 4.11 Storaged (存储统计)

**功能**: 收集和存储使用统计数据。

**原理**:
- 收集每个 UID 的 I/O 统计
- 暴露给 dumpsys

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- `dump()` — 需要 `AID_SHELL` 或 `DUMP`

**SELinux**: `storaged` 域，`coredomain`，`mlstrustedsubject`

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 4.12 Tombstoned (Tombstone 收集)

**功能**: 收集和管理进程崩溃时的 tombstone 数据。

**原理**:
- 监听 debuggerd 信号
- 收集 tombstone 数据
- 暴露给 dumpsys

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- 无显式权限检查
- 通过 SELinux 和文件权限控制

**SELinux**: `tombstoned` 域，`coredomain`

**transact 攻击面**: **MODERATE**
- 无显式权限检查
- 依赖 SELinux 策略

**shell 攻击面**: 无

---

### 4.13 DebuggerD (调试器守护进程)

**功能**: 生成进程崩溃时的 core dump 和 tombstone。

**原理**:
- 通过 ptrace 附加到崩溃进程
- 收集寄存器、堆栈、内存信息
- 生成 tombstone 文件

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- `pid_contains_tid()` — 验证线程属于进程
- `get_tracer()` — 检测进程是否已被跟踪

**SELinux**: `debuggerd` 域，`coredomain`

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 4.14 CredStore (凭证存储)

**功能**: 管理应用凭证的存储和检索。

**原理**:
- 注册为 "android.security.identity"
- 处理凭证操作

**App 交互**: 通过 CredentialManager API

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无显式权限检查

**SELinux**: `credstore` 域

**transact 攻击面**: **MODERATE**

**shell 攻击面**: 无

---

### 4.15 Keystore2 (密钥存储 2)

**功能**: 管理应用密钥的生成、存储和使用。

**原理**:
- Rust 实现
- 注册为 `android.system.keystore2.IKeystoreService/default`
- 管理 APC、Authorization、Metrics、UserManager、LegacyKeystore

**App 交互**:
```java
// 通过 AndroidKeyStore 间接交互
KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
ks.load(null);
```

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无显式权限检查（在入口点）

**SELinux**: `keystore2` 域

**transact 攻击面**: **MODERATE**

**shell 攻击面**: 无

---

### 4.16 BootStat (启动统计)

**功能**: 测量和记录启动时间。

**原理**:
- CLI 工具，非持久服务
- 读取 `/proc`，写入 statsd

**App 交互**: 无

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无

**SELinux**: N/A（CLI 工具）

**transact 攻击面**: **VERY LOW**（无 binder IPC）

**shell 攻击面**: 无

---

### 4.17 Usbd (USB 守护进程)

**功能**: 处理 USB 事件和模式切换。

**原理**:
- 最小守护进程
- 在充电器模式下退出
- 调用 `setCurrentUsbFunctions()` 到 HAL

**App 交互**: 无

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无

**SELinux**: `usbd` 域

**transact 攻击面**: **VERY LOW**

**shell 攻击面**: 无

---

### 4.18 LLKD (锁死检测)

**功能**: 检测系统锁死并触发 kernel panic。

**原理**:
- 独立守护进程
- `prctl(PR_SET_DUMPABLE, 0)` — 防止 core dump
- `SCHED_BATCH` 调度

**App 交互**: 无

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无

**SELinux**: `llkd` 域

**transact 攻击面**: **VERY LOW**

**shell 攻击面**: 无

---

## 系统核心守护进程总结

| 维度 | 分析 |
|------|------|
| **权限检查模式** | 混合模式：UID 检查 (`AID_SYSTEM`/`AID_ROOT`) + 权限字符串检查 + SELinux |
| **UID 检查** | `ENFORCE_SYSTEM_OR_ROOT` (vold), `ENFORCE_UID(AID_SYSTEM)` (installd), `CheckCallerIsRoot` (apexd) |
| **SELinux 保护** | 所有守护进程有独立 SELinux 域 |
| **transact 风险** | **netd** (AID_SYSTEM 绕过), **vold** (文件系统操作), **apexd** (模块管理), **update_engine** (无显式检查) 风险最高 |
| **shell 风险** | apexd shellCommand 无显式权限检查 |
| **关键漏洞点** | 1. netd AID_SYSTEM 绕过 2. update_engine 无显式权限检查 3. installd UID-based 无 binder 权限 4. apexd shellCommand 无权限检查 |

---

## 五、Trusty/安全服务

### 5.1 Trusty Gatekeeper

**功能**: 通过 Trusty TEE 实现 Gatekeeper 注册和验证。

**原理**:
- 运行于 `gatekeeperd` 域
- 通过 `/dev/trusty-ipc-dev0` 与 Trusty TA 通信
- 处理 `enroll`, `verify`, `deleteUser`, `deleteAllUsers`

**App 交互**: 通过 Gatekeeper HAL 间接交互

**Manifest 权限及功效**: N/A（框架层处理）

**Binder 权限验证**:
- 无显式 Android 权限检查
- UID 参数传递给 Trusty TA
- 无调用方 UID 验证

**SELinux**: `gatekeeperd` 域

**transact 攻击面**: **LOW**
- 框架层权限检查在前
- 缓冲区大小：`SEND_BUF_SIZE = 8192`, `RECV_BUF_SIZE = 8192`

**shell 攻击面**: 无

---

### 5.2 Trusty Keymaster

**功能**: 通过 Trusty TEE 实现密钥生成、导入、导出、签名等。

**原理**:
- 运行于 `keymasterd` 域
- 通过 Trusty IPC 转发命令到 TA
- 支持 4 个服务：`TrustyKeyMintDevice`, `TrustySecureClock`, `TrustySharedSecret`, `TrustyRemotelyProvisionedComponentDevice`

**App 交互**: 通过 Keymint HAL 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- 无显式权限检查
- 所有命令直接转发到 Trusty TA
- `KM_CONFIGURE_VENDOR_PATCHLEVEL` 需要 SELinux 权限读取系统属性

**SELinux**: `keymasterd` 域

**transact 攻击面**: **LOW**
- 框架层权限检查在前
- 线程池：`ABinderProcess_setThreadPoolMaxThreadCount(0)`（懒初始化）

**shell 攻击面**: 无

---

### 5.3 Trusty ConfirmationUI

**功能**: 通过 Trusty TEE 实现安全确认 UI。

**原理**:
- 运行于 `confirmationui` 域
- 安全输入设备独占访问 (`grabAllEvDevsAndRegisterCallbacks`)
- 状态机：`None → Starting → SetupDone → Interactive → Terminating`
- 输入握手使用 nonce/signature 验证

**App 交互**: 通过 ConfirmationUI HAL 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无显式权限检查

**SELinux**: `confirmationui` 域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 5.4 Trusty Storage Proxy

**功能**: 代理 Trusty TA 的存储操作，提供看门狗监控。

**原理**:
- 监控存储命令超时
- 看门狗超时：`kDefaultTimeoutMs = 500ms`, `kMaxTimeoutMs = 10s`
- 跟踪 `cmd`, `op_id`, `flags`

**App 交互**: 无直接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无

**SELinux**: 存储相关域

**transact 攻击面**: **VERY LOW**

**shell 攻击面**: 无

---

## 六、HAL 服务

### 6.1 Biometrics Face HAL (面部识别)

**功能**: 提供面部识别 HAL 实现。

**原理**:
- 注册为 `android.hardware.biometrics.face@1.0`
- 单线程 RPC：`configureRpcThreadpool(1, true)`

**App 交互**: 通过 BiometricManager 间接交互

**Manifest 权限及功效**: N/A（框架层处理）

**Binder 权限验证**: 无显式权限检查

**SELinux**: `hal_face_default` 域

**transact 攻击面**: **LOW**
- 框架层权限检查在前

**shell 攻击面**: 无

---

### 6.2 Biometrics Fingerprint HAL (指纹识别)

**功能**: 提供指纹识别 HAL 实现。

**原理**:
- 注册为 `android.hardware.biometrics.fingerprint@2.2`
- 单线程 RPC

**App 交互**: 通过 BiometricManager 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无显式权限检查

**SELinux**: `hal_fingerprint_default` 域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 6.3 WiFi HAL

**功能**: 提供 WiFi HAL 实现。

**原理**:
- AIDL 服务：`aidl::android::hardware::wifi::Wifi/descriptor/default`
- 支持懒加载服务注册
- 线程池：`ABinderProcess_setThreadPoolMaxThreadCount(1)`

**App 交互**: 通过 WifiManager 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无显式权限检查

**SELinux**: `hal_wifi_default` 域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 6.4 Sensors HAL

**功能**: 提供传感器 HAL 实现。

**原理**:
- 使用 FMQ (Fast Message Queue) 进行事件传递
- `injectSensorData()` — 允许注入传感器事件（潜在欺骗风险）
- `configDirectReport()` 和 `registerDirectChannel()` 返回 `EX_UNSUPPORTED_OPERATION`

**App 交互**: 通过 SensorManager 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无显式权限检查

**SELinux**: `hal_sensors_default` 域

**transact 攻击面**: **MODERATE**
- `injectSensorData()` 允许注入传感器事件
- 可能被滥用以欺骗应用

**shell 攻击面**: 无

---

### 6.5 Camera Provider HAL

**功能**: 提供相机 Provider HAL 实现。

**原理**:
- 注册为 `android.hardware.camera.provider@2.5`
- 实例：`legacy/0`
- 支持懒加载服务注册

**App 交互**: 通过 CameraManager 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无显式权限检查

**SELinux**: `hal_camera_default` 域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

## 七、包服务

### 7.1 TelecomServiceImpl (电话服务)

**功能**: 管理电话呼叫、会议、音频路由。

**原理**:
- 运行于 `system_server` 进程
- 维护电话呼叫状态
- 协调音频路由

**App 交互**:
```java
TelecomManager tm = getSystemService(TelecomManager.class);
// 拨打电话（需权限）
tm.placeCall(uri, extras);
// 管理电话账户
tm.registerPhoneAccount(account);
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `MANAGE_OWN_CALLS` (normal) | 管理自身呼叫 | `enforcePermission` |
| `MODIFY_PHONE_STATE` (system) | 修改电话状态 | `enforcePermission` |
| `READ_PHONE_STATE` (dangerous) | 读取电话状态 | `enforcePermission` |
| `READ_PRIVILEGED_PHONE_STATE` (system) | 读取特权电话状态 | `enforcePermission` |
| `READ_PHONE_NUMBERS` (dangerous) | 读取电话号码 | `enforcePermission` |
| `WRITE_SECURE_SETTINGS` (system) | 写入安全设置 | `enforcePermission` |
| `DUMP` (system/privileged) | dump 操作 | `enforcePermission` |

**Binder 权限验证**:
- `enforceCallingPackage()` — 验证调用方包身份
- `enforceUserHandleMatchesCaller()` — 验证用户句柄
- `enforcePhoneAccountIsNotManaged()` — 防止管理账户
- `enforceRegisterSimSubscriptionPermission()` — SIM 注册
- `enforceRegisterMultiUser()` — 多用户注册
- `enforceRegisterSkipCallFiltering()` — 跳过呼叫过滤
- `isPrivilegedUid()` — 检查 ROOT_UID, SYSTEM_UID, SHELL_UID
- `enforceCrossUserPermission()` — 跨用户访问控制

**SELinux**: `system_server` 域

**transact 攻击面**: **HIGH**
- 50+ AIDL 方法
- 复杂权限验证
- 异常报告安全事件

**shell 攻击面**: 
- `BasicShellCommandHandler` 实现
- Shell 专用命令：`setSystemDialer`

---

### 7.2 Telephony Service (电话服务)

**功能**: 管理移动网络、SIM 卡、短信等。

**原理**:
- 运行于 `system_server` 进程
- 维护电话状态
- 协调与调制解调器的通信

**App 交互**:
```java
TelephonyManager tm = getSystemService(TelephonyManager.class);
// 获取网络运营商
String operator = tm.getNetworkOperatorName();
// 获取设备 ID（需权限）
String imei = tm.getDeviceId();
```

**Manifest 权限及功效**:

| 权限 | 功效 | 检查方式 |
|------|------|----------|
| `READ_PHONE_STATE` (dangerous) | 读取电话状态 | `enforceCallingOrSelfPermission` |
| `MODIFY_PHONE_STATE` (system) | 修改电话状态 | `enforceCallingOrSelfPermission` |
| `READ_PRIVILEGED_PHONE_STATE` (system) | 读取特权电话状态 | `enforceCallingOrSelfPermission` |
| `CARRIER_FILTER_SMS` (system) | 过滤短信 | `SmsPermissions` |

**Binder 权限验证**:
- `TelephonyPermissions` 验证
- `CarrierPrivilegesTracker` 运营商特权检查
- `SmsPermissions` 短信权限检查
- `Binder.getCallingUid()` 大量使用
- `UserHandle.getCallingUserId()` 用户隔离
- `ActivityManager.getCurrentUser()` 前台用户检查

**SELinux**: `system_server` 域

**transact 攻击面**: **HIGH**
- 100+ AIDL 方法
- 直接调制解调器通信路径
- ICC APDU 传输、NV 读写、网络选择模式控制

**shell 攻击面**: 无

---

### 7.3 Car Service (车机服务)

**功能**: 管理车机系统的核心服务。

**原理**:
- 代理模式：`CarService` 代理到 `CarServiceImpl`
- 31 个 binder 线程（`MAX_BINDER_THREADS = 31`）
- `START_STICKY` 保持服务存活

**App 交互**:
```java
Car car = Car.createCar(context);
CarPropertyManager cpm = (CarPropertyManager) car.getCarManager(Car.PROPERTY_SERVICE);
```

**Manifest 权限及功效**: 在 `CarServiceImpl` 中检查

**Binder 权限验证**: 委托给 `CarServiceImpl`

**SELinux**: `system_server` 域

**transact 攻击面**: **MODERATE**

**shell 攻击面**: 无

---

## 八、车机服务

### 8.1 WatchdogProcessService (看门狗服务)

**功能**: 监控车机进程健康状态，杀死无响应进程。

**原理**:
- 客户端注册 + binder 死亡监控
- 健康检查超时：`TIMEOUT_CRITICAL`, `TIMEOUT_MODERATE`, `TIMEOUT_NORMAL`
- VHAL 心跳监控：`kDefaultVhalCheckIntervalSec = 3s`
- 会话 ID 验证

**App 交互**: 通过 ICarWatchdogService 间接交互

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- `IPCThreadState::self()->getCallingUid()` 客户端识别
- `multiuser_get_user_id(callingUid)` 用户 ID 提取
- `IPCThreadState::self()->getCallingPid()` 进程识别

**SELinux**: 车机相关域

**transact 攻击面**: **MODERATE**
- `dumpAndKillAllProcesses()` — 强大的进程终止能力
- 基于 PID 的客户端识别

**shell 攻击面**: 无

---

### 8.2 EvsManager (外部视觉系统管理器)

**功能**: 管理车机外部摄像头系统。

**原理**:
- AIDL 接口
- 协调摄像头资源

**App 交互**: 通过 EvsManager API

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无显式权限检查

**SELinux**: 车机相关域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

## 九、模块服务

### 9.1 StatsD (统计守护进程)

**功能**: 收集系统统计信息，上报到 StatsD。

**原理**:
- 注册为 `stats`
- `AIBinder_setRequestingSid(binder.get(), true)` — 请求调用方 SELinux 上下文
- 9 个线程池
- `UidMap` UID 到包映射

**App 交互**: 无直接公共 API

**Manifest 权限及功效**: N/A

**Binder 权限验证**:
- SELinux 上下文验证
- `StatsSocketListener` 基于 socket 的通信

**SELinux**: `statsd` 域

**transact 攻击面**: **LOW**

**shell 攻击面**: 无

---

### 9.2 Derive SDK (SDK 级别推导)

**功能**: 在启动时推导 SDK 级别。

**原理**:
- 命令行工具，非持久服务
- 挂载点：`/apex`
- 操作：`PrintHeader`, `PrintDump`, `SetSdkLevels`

**App 交互**: 无

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无

**SELinux**: N/A

**transact 攻击面**: **VERY LOW**（无 binder IPC）

**shell 攻击面**: 无

---

### 9.3 Microdroid Launcher (微虚拟机启动器)

**功能**: 在隔离环境中加载和运行 payload。

**原理**:
- 创建隔离的 linker namespace (`ANDROID_NAMESPACE_TYPE_ISOLATED`)
- 受限库访问白名单：`libc.so`, `libm.so`, `libdl.so`, `liblog.so` 等
- 入口点：`AVmPayload_main`

**App 交互**: 无

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无

**SELinux**: 隔离域

**transact 攻击面**: **VERY LOW**（无 binder IPC）

**shell 攻击面**: 无

---

## 十、恢复模式服务

### 10.1 Recovery (恢复模式)

**功能**: 在恢复模式下执行 OTA 安装、数据擦除等操作。

**原理**:
- 无 Android 权限模型
- 需要物理访问
- 电池电量检查：`BATTERY_OK_PERCENTAGE = 20%`
- 启动原因阻止列表：`kernel_panic`, `Panic`
- 用户确认数据擦除
- Bootloader Control Block (BCB) 通信

**App 交互**: 无

**Manifest 权限及功效**: N/A

**Binder 权限验证**: 无

**SELinux**: `recovery` 域

**transact 攻击面**: **VERY LOW**（无 binder IPC）

**shell 攻击面**: 
- 命令行接口：`/cache/recovery/command`
- BCB 与 bootloader 通信

---

## 全局总结

### 攻击面评级总表

| 服务类别 | 最高风险服务 | transact 风险 | shell 风险 | 关键发现 |
|----------|-------------|---------------|------------|----------|
| **Framework Java** | AccessibilityManagerService | MODERATE | LOW | `@RequiresNoPermission` 方法可被直接调用 |
| **Native 系统** | SurfaceFlinger, InputDispatcher | HIGH | LOW | Backdoor codes 和无内置权限检查 |
| **媒体服务** | DrmServer, MediaPlayer | MODERATE | LOW | Token 模型和无显式检查 |
| **系统核心** | netd, vold, apexd, update_engine | HIGH | LOW | AID_SYSTEM 绕过和无显式检查 |
| **Trusty/安全** | Trusty Gatekeeper | LOW | NONE | 框架层权限检查在前 |
| **HAL 服务** | Sensors HAL | MODERATE | NONE | `injectSensorData()` 欺骗风险 |
| **包服务** | TelecomServiceImpl, PhoneInterfaceManager | HIGH | LOW | 50-100+ AIDL 方法，复杂权限 |
| **车机服务** | WatchdogProcessService | MODERATE | NONE | 进程终止能力 |
| **模块服务** | StatsD | LOW | NONE | SELinux 上下文验证 |
| **恢复模式** | Recovery | VERY LOW | LOW | 无 binder IPC |

### IBinder.transact() 攻击可行性分析

| 条件 | 可行性 | 说明 |
|------|--------|------|
| **无权限方法** | ✅ 可行 | `@RequiresNoPermission` 方法可直接调用 |
| **需 normal 权限方法** | ⚠️ 需权限 | 需声明对应权限 |
| **需 system 权限方法** | ❌ 不可行 | 需 system/privileged 权限 |
| **需 AID_SYSTEM** | ❌ 不可行 | 需 system server 身份 |
| **SELinux 保护** | ❌ 不可行 | SELinux 阻止 app 访问服务 |

### IBinder.shellCommand() 攻击可行性分析

| 条件 | 可行性 | 说明 |
|------|--------|------|
| **无权限 shellCommand** | ⚠️ 需 SHELL_UID | GpuService, APEX 无权限检查 |
| **需权限 shellCommand** | ❌ 需 SHELL_UID + 权限 | 多数需要特定权限 |
| **dump() 方法** | ⚠️ 需 SHELL_UID | 输出可能泄露信息 |

### 关键安全发现

1. **SurfaceFlinger Backdoor Codes (1000-1045)**: 绕过正常权限检查，仅需 `AID_SYSTEM` 或 `HARDWARE_TEST`
2. **InputDispatcher 无内置权限检查**: `injectInputEvent` 依赖框架层 `INJECT_EVENTS` 权限
3. **netd AID_SYSTEM 绕过**: 避免死锁但扩大攻击面
4. **update_engine 无显式权限检查**: 完全依赖 SELinux
5. **GpuService shellCommand 无权限检查**: 可执行 `vkjson`, `vkprofiles`
6. **APEX shellCommand 无显式权限检查**: 可执行 `stagePackages`, `remountPackages`
7. **Sensors HAL injectSensorData()**: 可注入伪造传感器事件
8. **Trusty 服务无显式权限检查**: 依赖框架层权限检查在前

### 防御建议

1. **移除 SurfaceFlinger backdoor codes**: 迁移到 AIDL 接口并添加权限检查
2. **InputDispatcher 添加内置权限检查**: 不依赖框架层
3. **netd 移除 AID_SYSTEM 绕过**: 使用更细粒度的权限控制
4. **update_engine 添加显式权限检查**: 不完全依赖 SELinux
5. **GpuService/APEX shellCommand 添加权限检查**: 防止 SHELL_UID 滥用
6. **Sensors HAL 限制 injectSensorData()**: 添加权限检查
7. **Trusty 服务添加 UID 验证**: 不完全依赖框架层

---

## 附录：SELinux 域速查表

| 服务 | SELinux 域 | coredomain | mlstrustedsubject |
|------|-----------|------------|-------------------|
| SurfaceFlinger | `surfaceflinger` | ✓ | ✓ |
| GpuService | `gpuservice` | ✓ | ✗ |
| InputFlinger | `inputflinger` | ✓ | ✗ |
| CameraServer | `cameraserver` | ✓ | ✗ |
| AudioServer | `audioserver` | ✓ | ✗ |
| Vold | `vold` | ✓ | ✗ |
| Netd | `netd` | ✓ | ✗ |
| Gatekeeperd | `gatekeeperd` | ✓ | ✗ |
| Installd | `installd` | ✓ | ✗ |
| ServiceManager | `servicemanager` | ✓ | ✗ |
| Apexd | `apexd` | ✓ | ✗ |
| Update Engine | `update_engine` | ✓ | ✗ |
| Storaged | `storaged` | ✓ | ✓ |
| Tombstoned | `tombstoned` | ✓ | ✗ |
| Debuggerd | `debuggerd` | ✓ | ✗ |
| CredStore | `credstore` | ✗ | ✗ |
| Keystore2 | `keystore2` | ✗ | ✗ |
| MediaExtractor | `mediaextractor` | ✓ | ✓ |
| MediaServer | `mediaserver` | ✓ | ✗ |
| DrmServer | `drmserver` | ✓ | ✓ |
| StatsD | `statsd` | ✗ | ✗ |
| LMKD | `lmkd` | ✓ | ✗ |
| BootStat | N/A | N/A | N/A |
| Usbd | `usbd` | ✗ | ✗ |
| LLKD | `llkd` | ✗ | ✗ |
| Recovery | `recovery` | ✗ | ✗ |
| Init | `init` | ✗ | ✗ |
| SystemServer | `system_server` | ✓ | ✓ |

---

## 附录：权限检查方法速查

| 检查方法 | 使用场景 | 失败行为 |
|----------|----------|----------|
| `enforceCallingPermission()` | 调用方必须持有权限 | 抛出 SecurityException |
| `enforceCallingOrSelfPermission()` | 调用方或自身持有权限 | 抛出 SecurityException |
| `checkCallingPermission()` | 检查调用方权限 | 返回 PERMISSION_GRANTED/DENIED |
| `@EnforcePermission` | Android 15 新模式 | 自动检查权限 |
| `@RequiresPermission` | 文档/静态分析 | 无运行时效果 |
| `@RequiresNoPermission` | 明确无需权限 | 无运行时效果 |
| `Binder.getCallingUid()` | UID 验证 | 返回调用方 UID |
| `Process.SYSTEM_UID` | 系统 UID 检查 | 硬编码 1000 |
| `Process.SHELL_UID` | Shell UID 检查 | 硬编码 2000 |
| `Process.ROOT_UID` | Root UID 检查 | 硬编码 0 |
| `selinux_check_access()` | SELinux 权限检查 | 返回 0/非 0 |

---

*文档结束*


