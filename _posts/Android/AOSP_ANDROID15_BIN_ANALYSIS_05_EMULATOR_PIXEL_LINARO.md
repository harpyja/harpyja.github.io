# AOSP Android15 模拟器组件、Pixel 特有组件和 Linaro 设备组件分析

本文档分析 AOSP Android15 中 Goldfish/Ranchu 模拟器、Cuttlefish 模拟器、Google Tensor/Pixel 家族以及 Linaro 设备的特有组件。

---

## 第一部分：Goldfish/Ranchu 模拟器组件

**产品选择**: `device/generic/goldfish/product/generic.mk`

### 1.1 `qemu-props` — QEMU 属性服务

**功能**: 在模拟器中传递 QEMU 参数到 Android 系统属性。

**原理**:
```
qemu-props
  │
  ├── 读取 QEMU 参数（通过 QEMU pipe）
  ├── 解析参数
  └── 设置系统属性
        ├── qemu.sf.lcd_density
        ├── qemu.hw.mainkeys
        └── 更多...
```

### 1.2 `mac80211_create_radios` — 创建虚拟 WiFi  radio

**源码位置**: `device/generic/goldfish/wifi/mac80211_create_radios/main.cpp`

**功能**: 在模拟器中创建虚拟 WiFi radio 设备。

**原理**:
```
mac80211_create_radios
  │
  ├── 通过 netlink 连接到 mac80211_hwsim
  ├── 发送 HWSIM_CMD_NEW_RADIO 命令
  └── 创建虚拟 radio 设备
```

**相关内核特性**:
- **mac80211_hwsim**: 内核中的 mac80211 硬件模拟器
- **netlink**: 内核与用户空间通信
- **nl80211**: 无线配置接口

### 1.3 `dhcpclient` — DHCP 客户端

**功能**: 在模拟器中获取 IP 地址。

**原理**:
- 发送 DHCP Discover
- 接收 DHCP Offer
- 发送 DHCP Request
- 接收 DHCP Ack

### 1.4 `libgoldfish-rild` — Goldfish RIL 守护进程

**功能**: 模拟器中的 Radio Interface Layer 守护进程。

**原理**:
- 模拟手机通信功能
- 通过 QEMU pipe 与主机通信
- 支持短信、通话、数据连接模拟

### 1.5 Goldfish HAL 服务

| 服务 | 功能 |
|------|------|
| `android.hardware.graphics.composer3-service.ranchu` | 图形合成器 HAL |
| `android.hardware.media.c2@1.0-service-goldfish` | 媒体编解码器 HAL |
| `android.hardware.graphics.allocator-service.ranchu` | 图形分配器 HAL |
| `android.hardware.biometrics.fingerprint-service.ranchu` | 指纹 HAL |
| `android.hardware.gnss-service.ranchu` | GNSS HAL |
| `android.hardware.camera.provider.ranchu` | 相机 HAL |

### 1.6 Goldfish 初始化脚本

| 脚本 | 功能 |
|------|------|
| `init.ranchu.adb.setup.sh` | ADB 设置 |
| `init_ranchu_device_state.sh` | 设备状态初始化 |
| `init.ranchu-core.sh` | 核心初始化 |
| `init.ranchu-net.sh` | 网络初始化 |

### 1.7 模拟器中选取的 HAL 服务

```
hardware/interfaces/atrace/1.0/default/
hardware/interfaces/audio/common/all-versions/default/service/
hardware/interfaces/biometrics/face/aidl/default/
hardware/interfaces/bluetooth/aidl/default/
hardware/interfaces/contexthub/aidl/default/
hardware/interfaces/dumpstate/aidl/default/
hardware/interfaces/gatekeeper/1.0/software/
hardware/interfaces/health/aidl/default/
hardware/interfaces/identity/aidl/default/
hardware/interfaces/light/aidl/default/
hardware/interfaces/power/aidl/default/
hardware/interfaces/power/stats/aidl/default/
hardware/interfaces/security/keymint/aidl/default/
hardware/interfaces/sensors/aidl/multihal/
hardware/interfaces/thermal/2.0/default/
hardware/interfaces/usb/aidl/default/
hardware/interfaces/uwb/aidl/default/
hardware/interfaces/vibrator/aidl/default/
hardware/interfaces/wifi/aidl/default/
```

---

## 第二部分：Cuttlefish 模拟器组件

**产品选择**: `device/google/cuttlefish/shared/` 和 `device/google/cuttlefish/vsoc_*/`

### 2.1 `checkpoint_gc` — 检查点垃圾回收

**功能**: 清理不再需要的检查点数据。

### 2.2 `socket_vsock_proxy` — Socket vsock 代理

**功能**: 在主机和 vsock 之间代理 socket 连接。

**原理**:
- 监听 vsock 连接
- 转发到主机 socket
- 支持双向通信

### 2.3 `tombstone_transmit` / `tombstone_producer` — Tombstone 传输

**功能**: 将 tombstone 从 guest 传输到 host。

**原理**:
```
tombstone_transmit
  │
  ├── 监控 guest 中的 tombstone 文件
  ├── 读取新产生的 tombstone
  └── 通过 vsock 传输到 host
```

### 2.4 `suspend_blocker` — 挂起阻止器

**功能**: 阻止 guest 进入挂起状态。

**原理**:
- 调用 power HAL 接口
- 获取 wake lock
- 阻止系统挂起

### 2.5 `snapshot_hook_pre_suspend` / `snapshot_hook_post_resume` — 快照钩子

**功能**: 在挂起前/恢复后执行快照操作。

### 2.6 `dlkm_loader` — 可加载内核模块加载器

**源码位置**: `device/google/cuttlefish/guest/commands/dlkm_loader/dlkm_loader.cpp`

**功能**: 加载 vendor 的可加载内核模块（DLKM）。

**原理**:
```
dlkm_loader
  │
  ├── 读取 /vendor/lib/modules/modules.load
  ├── 加载所有列出的模块
  └── 设置 vendor.dlkm.modules.ready 属性
```

### 2.7 `bt_vhci_forwarder` — 蓝牙 VHCI 转发器

**功能**: 转发蓝牙 VHCI（Virtual HCI）数据。

### 2.8 `cuttlefish_sensor_injection` — 传感器注入

**功能**: 向模拟器注入传感器数据。

**原理**:
- 接收来自主机的传感器数据
- 通过注入接口发送到 Android 传感器框架
- 支持加速度计、陀螺仪、磁力计等

### 2.9 `rename_netiface` — 重命名网络接口

**功能**: 重命名网络接口（用于稳定的接口命名）。

### 2.10 `setup_wifi` — WiFi 设置

**功能**: 在 Cuttlefish 中设置 WiFi。

### 2.11 `init.wifi_apex` — WiFi APEX 初始化

**功能**: 初始化 WiFi APEX 模块。

### 2.12 `libcuttlefish-rild` — Cuttlefish RIL 守护进程

**功能**: Cuttlefish 中的 Radio Interface Layer 守护进程。

### 2.13 Cuttlefish HAL 服务

| 服务 | 功能 |
|------|------|
| `android.hardware.camera.provider@2.7-external-vsock-service` | 外部相机 HAL |
| `android.hardware.confirmationui-service.cuttlefish` | 确认 UI HAL |
| `android.hardware.health-service.cuttlefish` | 健康 HAL |
| `android.hardware.health.storage-service.cuttlefish` | 存储健康 HAL |
| `android.hardware.light-service.cuttlefish` | 灯光 HAL |
| `android.hardware.identity-service.remote` | 身份 HAL |
| `android.hardware.nfc-service.cuttlefish` | NFC HAL |
| `android.hardware.oemlock-service.remote` | OEM 锁 HAL |
| `android.hardware.gatekeeper-service.remote` | 门禁 HAL |
| `android.hardware.security.keymint-service.rust` | KeyMint HAL (Rust) |

### 2.14 Cuttlefish APEX

```
com.google.cf.bt         # 蓝牙
com.google.cf.wifi       # WiFi
com.google.cf.wpa_supplicant  # WPA Supplicant
com.google.cf.rild       # RIL
com.google.cf.identity   # 身份
com.google.cf.nfc        # NFC
```

### 2.15 TV 和 Automotive 添加

**TV additions**:
```
hardware/interfaces/tv/hdmi/connection/aidl/default/
hardware/interfaces/tv/hdmi/cec/aidl/default/
hardware/interfaces/tv/hdmi/earc/aidl/default/
hardware/interfaces/tv/tuner/aidl/default/
hardware/interfaces/tv/input/aidl/default/
```

**Automotive additions**:
```
hardware/interfaces/automotive/
hardware/interfaces/broadcastradio/
hardware/interfaces/macsec/
device/google/cuttlefish/guest/hals/vehicle/
```

---

## 第三部分：Google Tensor/Pixel 家族特有组件

**设备树**: `device/google/gs-common/`（公共）+ 各代产品特有目录

### 3.1 通用 Pixel 调试工具

| 工具 | 功能 | 原理 |
|------|------|------|
| `gs_watchdogd` | Pixel 看门狗 | 硬件看门狗定时器 |
| `sscoredump` | 子系统核心转储 | 收集 SSCD（Subsystem Core Dump） |
| `dump_soc` | SoC 转储 | 转储 SoC 状态信息 |
| `dump_devfreq` | _devfreq 转储 | 转储 devfreq 状态 |
| `dump_perf` | 性能转储 | 转储性能状态 |
| `dump_camera` | 相机转储 | 转储相机状态 |
| `dump_display` | 显示转储 | 转储显示状态 |
| `dump_gxp` | GXP 转储 | 转储 GXP（神经处理器）状态 |
| `dump_storage` | 存储转储 | 转储存储状态 |
| `dump_modemlog` | Modem 日志转储 | 转储 Modem 日志 |

### 3.2 `insmod.sh` — 模块加载脚本

**功能**: 加载内核模块的辅助脚本。

### 3.3 `gpu_probe` — GPU 探测

**功能**: 探测和配置 GPU。

### 3.4 `misc_writer` — 杂项写入器

**功能**: 写入杂项分区数据。

### 3.5 `android.hardware.boot-service.default-pixel` — Pixel Boot 控制

**功能**: Pixel 的 Boot 控制 HAL。

### 3.6 `android.hardware.contexthub-service.generic` — ContextHub 服务

**功能**: 上下文中心 HAL，管理传感器集线器。

### 3.7 `android.hardware.sensors-service.multihal` — 多 HAL 传感器服务

**功能**: 支持多 HAL 的传感器服务。

### 3.8 Pixel 各代产品

| 家族 | 产品 | 定义位置 |
|------|------|----------|
| GS101 | raviole, bluejay | `device/google/gs101/device.mk` |
| GS201 | pantah, lynx, felix, tangorpro | `device/google/gs201/device.mk` |
| Zuma | shusky, akita | `device/google/zuma/device.mk` |
| Zuma Pro | caimito, comet | `device/google/zumapro/device.mk` |

### 3.9 Pixel 特有源码目录

```
device/google/gs-common/ramdump_and_coredump/
device/google/gs-common/aoc/
device/google/gs-common/storage/
device/google/gs-common/dauntless/
system/chre/
system/core/trusty/utils/trusty-ut-ctrl/
system/core/trusty/libtrusty/tipc-test/
external/sg3_utils/
```

### 3.10 未包含的专有组件

```
vendor/google_devices/
vendor/google/whitechapel/
vendor/google_nos/
vendor/samsung_slsi/telephony/
vendor/broadcom/gps/
vendor/goodix/udfps/
vendor/qorvo/uwb/
```

---

## 第四部分：Linaro 设备组件

### 4.1 Dragonboard 添加

| 工具 | 功能 | 原理 |
|------|------|------|
| `pd-mapper` | 端口映射 | 管理端口映射 |
| `qrtr-ns` | Qualcomm IPC 路由命名空间 | QRTR 命名空间管理 |
| `qrtr-cfg` | QRTR 配置 | 配置 QRTR |
| `qrtr-lookup` | QRTR 查找 | 查找 QRTR 服务 |
| `rmtfs` | 远程文件系统 | 远程存储访问 |
| `tqftpserv` | TQFTP 服务 | 文件传输服务 |
| `bdaddr` | 蓝牙地址 | 设置蓝牙地址 |

### 4.2 QRTR (Qualcomm IPC Router)

**源码位置**: `device/linaro/dragonboard/shared/utils/qrtr/`

**功能**: Qualcomm IPC Router，用于处理器间通信。

**原理**:
```
qrtr
  │
  ├── 基于 GLib 的 IPC 路由
  ├── 服务注册和发现
  └── 消息路由
```

**子命令**:
- `qrtr-cfg`: 配置 QRTR
- `qrtr-ns`: 管理命名空间
- `qrtr-lookup`: 查找服务

### 4.3 RMTFS (Remote File System)

**功能**: 远程文件系统，访问远程处理器的存储。

**原理**:
- 通过共享内存通信
- 模拟本地文件系统
- 支持块设备访问

### 4.4 HiKey/HiKey960 添加

| 工具 | 功能 |
|------|------|
| `ssh` / `sftp` / `scp` / `sshd` / `ssh-keygen` / `start-ssh` | SSH 服务 |
| `stm32_flash` | STM32 固件烧录 |
| `nanoapp_cmd` | Nanoapp 命令 |
| `nanotool` | Nanoapp 工具 |
| `android.hardware.power@1.1-service.hikey-common` | 电源 HAL |

### 4.5 Poplar 添加

| 工具 | 功能 |
|------|------|
| `hiavplayer` | 音频视频播放 |
| `tee-supplicant` | OP-TEE 客户端 |
| `xtest` | OP-TEE 测试 |
| `optee_example_helloworld` | OP-TEE 示例 |
| `optee_example_random` | OP-TEE 随机数示例 |

### 4.6 OP-TEE (Open Portable Trusted Execution Environment)

**功能**: 开源可信执行环境。

**组件**:
- `tee-supplicant`: 用户空间客户端
- `xtest`: 测试套件
- `optee_example_*`: 示例应用

**相关内核特性**:
- **TrustZone**: ARM 安全扩展
- **TEE 驱动**: `/dev/tee0`

---

## 总结

| 平台 | 关键组件 | 用途 |
|------|----------|------|
| Goldfish | qemu-props, mac80211_create_radios, dhcpclient | Android 模拟器 |
| Cuttlefish | vsock_proxy, tombstone_transmit, dlkm_loader, sensor_injection | 高级模拟器 |
| Pixel/Tensor | dump_*, gs_watchdogd, sscoredump, misc_writer | Google 手机 |
| Dragonboard | qrtr-ns, rmtfs, tqftpserv | Qualcomm 开发板 |
| Poplar | tee-supplicant, xtest, optee_example_* | OP-TEE 开发板 |

---

## 附录：所有文档索引

| 文档 | 内容 |
|------|------|
| AOSP_ANDROID15_BIN_ANALYSIS_01 | GSI Framework Shell Commands |
| AOSP_ANDROID15_BIN_ANALYSIS_02 | GSI Native & Rust Executables |
| AOSP_ANDROID15_BIN_ANALYSIS_03 | APEX Binaries |
| AOSP_ANDROID15_BIN_ANALYSIS_04 | OTA Helpers, Toybox/Toolbox, userdebug/eng |
| AOSP_ANDROID15_BIN_ANALYSIS_05 | 模拟器组件、Pixel 特有组件、Linaro 设备组件 |
