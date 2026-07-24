# Android 15 AOSP 系统服务全景总结

> 生成日期: 2026-07-24  
> 基于: Android 15 AOSP 源码

---

## 构建变体说明

| 缩写 | 全称 | 说明 |
|------|------|------|
| **user** | User Build | 生产版本，无调试工具 |
| **userdebug** | Userdebug Build | 可调试版本，含调试工具 |
| **eng** | Engineering Build | 工程版本，含完整调试工具 |
| **emu** | Emulator | 模拟器(Cuttlefish)专用 |
| **rec** | Recovery | 恢复模式专用 |
| **all** | All Variants | 所有变体均包含 |

构建变体层级关系: `user` ⊂ `userdebug` ⊂ `eng`

---

## 一、Framework Java 服务 (运行于 system_server 内)

> 位置: `frameworks/base/services/`  
> 构建模块: `services` (java_library)  
> 输出变体: **all**

| 服务名称 | 源码路径 | 模块名 |
|----------|----------|--------|
| 核心服务 | `frameworks/base/services/` | `services` |
| 核心服务(core) | `frameworks/base/services/core/` | `services.core` |
| 无障碍服务 | `frameworks/base/services/accessibility/` | `services.accessibility` |
| 应用预测 | `frameworks/base/services/appprediction/` | `services.appprediction` |
| 桌面小部件 | `frameworks/base/services/appwidget/` | `services.appwidget` |
| 自动填充 | `frameworks/base/services/autofill/` | `services.autofill` |
| 备份服务 | `frameworks/base/services/backup/` | `services.backup` |
| 伴侣设备 | `frameworks/base/services/companion/` | `services.companion` |
| 应用函数 | `frameworks/base/services/appfunctions/` | `services.appfunctions` |
| 内容捕获 | `frameworks/base/services/contentcapture/` | `services.contentcapture` |
| 内容建议 | `frameworks/base/services/contentsuggestions/` | `services.contentsuggestions` |
| 上下文搜索 | `frameworks/base/services/contextualsearch/` | `services.contextualsearch` |
| 覆盖率 | `frameworks/base/services/coverage/` | `services.coverage` |
| 凭证管理 | `frameworks/base/services/credentials/` | `services.credentials` |
| 设备策略 | `frameworks/base/services/devicepolicy/` | `services.devicepolicy` |
| 功能标志 | `frameworks/base/services/flags/` | `services.flags` |
| MIDI | `frameworks/base/services/midi/` | `services.midi` |
| 音乐识别 | `frameworks/base/services/musicrecognition/` | `services.musicrecognition` |
| 网络服务 | `frameworks/base/services/net/` | `services.net` |
| 人物服务 | `frameworks/base/services/people/` | `services.people` |
| 权限管理 | `frameworks/base/services/permission/` | `services.permission` |
| 打印服务 | `frameworks/base/services/print/` | `services.print` |
| 性能收集 | `frameworks/base/services/profcollect/` | `services.profcollect` |
| 限制管理 | `frameworks/base/services/restrictions/` | `services.restrictions` |
| 搜索UI | `frameworks/base/services/searchui/` | `services.searchui` |
| 智能空间 | `frameworks/base/services/smartspace/` | `services.smartspace` |
| 监督模式 | `frameworks/base/services/supervision/` | `services.supervision` |
| 系统字幕 | `frameworks/base/services/systemcaptions/` | `services.systemcaptions` |
| 翻译服务 | `frameworks/base/services/translation/` | `services.translation` |
| 文字转语音 | `frameworks/base/services/texttospeech/` | `services.texttospeech` |
| 使用情况 | `frameworks/base/services/usage/` | `services.usage` |
| USB服务 | `frameworks/base/services/usb/` | `services.usb` |
| 语音交互 | `frameworks/base/services/voiceinteraction/` | `services.voiceinteraction` |
| 壁纸效果生成 | `frameworks/base/services/wallpapereffectsgeneration/` | `services.wallpapereffectsgeneration` |
| WiFi服务 | `frameworks/base/services/wifi/` | `services.wifi` |

---

## 二、Native 系统服务

### 2.1 SurfaceFlinger / GPU / 传感器

| 服务名称 | 源码路径 | 模块名 | Init RC | 输出变体 |
|----------|----------|--------|---------|----------|
| **surfaceflinger** | `frameworks/native/services/surfaceflinger/` | `surfaceflinger` | `surfaceflinger.rc` | **all** |
| **sensorservice** | `frameworks/native/services/sensorservice/` | `sensorservice` | - | **all** |
| **gpuservice** | `frameworks/native/services/gpuservice/` | `gpuservice` | `gpuservice.rc` | **all** |
| **inputflinger** | `frameworks/native/services/inputflinger/` | `libinputflinger` | - | **all** (运行于system_server) |
| **audiomanager** | `frameworks/native/services/audiomanager/` | `libaudiomanager` | - | **all** (库) |
| **powermanager** | `frameworks/native/services/powermanager/` | `libpowermanager` | - | **all** (库) |
| **batteryservice** | `frameworks/native/services/batteryservice/` | `libbatteryservice_headers` | - | **all** (库) |
| **memtrackproxy** | `frameworks/native/services/memtrackproxy/` | `libmemtrackproxy` | - | **all** (库) |
| **vibratorservice** | `frameworks/native/services/vibratorservice/` | `libvibratorservice` | - | **all** (库) |
| **displayservice** | `frameworks/native/services/displayservice/` | `libdisplayservicehidl` | - | **all** (库) |
| **schedulerservice** | `frameworks/native/services/schedulerservice/` | - | - | **all** (库) |
| **stats** | `frameworks/native/services/stats/` | `libstatshidl` | - | **all** (库) |

### 2.2 Automotive Display

| 服务名称 | 源码路径 | 模块名 | Init RC | 输出变体 |
|----------|----------|--------|---------|----------|
| **automotive.display** | `frameworks/native/services/automotive/display/` | `android.frameworks.automotive.display@1.0-service` | `android.frameworks.automotive.display@1.0-service.rc` | **all** (车机) |

---

## 三、媒体服务 (Media Services)

> 位置: `frameworks/av/services/` 及 `frameworks/av/media/`

| 服务名称 | 源码路径 | 模块名 | Init RC | 输出变体 |
|----------|----------|--------|---------|----------|
| **audioflinger** | `frameworks/av/services/audioflinger/` | `libaudioflinger` | - | **all** (运行于audioserver) |
| **audioserver** | `frameworks/av/media/audioserver/` | `audioserver` | `audioserver.rc` | **all** |
| **audiopolicyservice** | `frameworks/av/services/audiopolicy/service/` | `libaudiopolicyservice` | - | **all** (库) |
| **mediametrics** | `frameworks/av/services/mediametrics/` | `mediametrics` | `mediametrics.rc` | **all** |
| **mediaswcodec** | `frameworks/av/services/mediacodec/` | `mediaswcodec` | `mediaswcodec.rc` | **all** |
| **media.codec (OMX)** | `frameworks/av/services/mediacodec/` | `android.hardware.media.omx@1.0-service` | `android.hardware.media.omx@1.0-service.rc` | **all** |
| **mediaextractor** | `frameworks/av/services/mediaextractor/` | `mediaextractor` | `mediaextractor.rc` | **all** |
| **cameraserver** | `frameworks/av/camera/cameraserver/` | `cameraserver` | `cameraserver.rc` | **all** (手机/手持设备) |
| **libcameraservice** | `frameworks/av/services/camera/libcameraservice/` | `libcameraservice` | - | **all** (库) |
| **drmserver** | `frameworks/av/drm/drmserver/` | `drmserver` | `drmserver.rc` | **all** |
| **mediaserver** | `frameworks/av/media/mediaserver/` | `mediaserver` | `mediaserver.rc` | **all** |
| **media.resource.manager** | `frameworks/av/services/mediaresourcemanager/` | `libresourcemanagerservice` | - | **all** (库) |
| **media.log** | `frameworks/av/services/medialog/` | `libmedialogservice` | - | **all** (库) |
| **media.tuner** | `frameworks/av/services/tuner/` | `mediatuner` | `mediatuner.rc` | **all** (TV/调谐器) |
| **virtual_camera** | `frameworks/av/services/camera/virtualcamera/` | `virtual_camera` | `virtual_camera.hal.rc` | **emu** |
| **media.transcoding** | `frameworks/av/apex/` | `media.transcoding` | `mediatranscoding.rc` | **all** |

---

## 四、系统核心守护进程 (System Core Daemons)

> 位置: `system/core/`, `system/vold/`, `system/netd/` 等

| 服务名称 | 源码路径 | 模块名 | Init RC | 输出变体 |
|----------|----------|--------|---------|----------|
| **init** | `system/core/init/` | `init` | `init.rc` | **all** |
| **ueventd** | `system/core/init/` | `ueventd` | `init.rc` | **all** |
| **logd** | `system/logging/logd/` | `logd` | `logd.rc` | **all** |
| **logcatd** | `system/logging/logcat/` | `logcatd` | `logcatd.rc` | **all** |
| **vold** | `system/vold/` | `vold` | `vold.rc` | **all** |
| **netd** | `system/netd/server/` | `netd` | `netd.rc` | **all** |
| **lmkd** | `system/memory/lmkd/` | `lmkd` | `lmkd.rc` | **all** |
| **healthd/charger** | `system/core/healthd/` | `charger` | - | **all** |
| **gatekeeperd** | `system/core/gatekeeperd/` | `gatekeeperd` | `gatekeeperd.rc` | **all** |
| **watchdogd** | `system/core/watchdogd/` | `watchdogd` | - | **all** |
| **usbd** | `system/core/usbd/` | `usbd` | `usbd.rc` | **all** |
| **storaged** | `system/core/storaged/` | `storaged` | `storaged.rc` | **all** |
| **bootstat** | `system/core/bootstat/` | `bootstat` | `bootstat.rc` | **all** |
| **llkd** | `system/core/llkd/` | `llkd` | - | **all** |
| **debuggerd** | `system/core/debuggerd/` | `debuggerd` | - | **all** |
| **dmesgd** | `system/dmesgd/` | `dmesgd` | `dmesgd.rc` | **all** |
| **apexd** | `system/apex/apexd/` | `apexd` | `apexd.rc` | **all** |
| **gsid** | `system/gsid/` | `gsid` | `gsid.rc` | **all** |
| **update_engine** | `system/update_engine/` | `update_engine` | `update_engine.rc` | **all** |
| **hwservicemanager** | `system/hwservicemanager/` | `hwservicemanager` | `hwservicemanager.rc` | **all** |
| **servicemanager** | `frameworks/native/cmds/servicemanager/` | `servicemanager` | `servicemanager.rc` | **all** |
| **vndservicemanager** | `frameworks/native/cmds/servicemanager/` | `vndservicemanager` | `vndservicemanager.rc` | **all** |
| **installd** | `frameworks/native/cmds/installd/` | `installd` | `installd.rc` | **all** |
| **dumpstate** | `frameworks/native/cmds/dumpstate/` | `dumpstate` | `dumpstate.rc` | **all** |
| **incidentd** | `frameworks/base/cmds/incidentd/` | `incidentd` | `incidentd.rc` | **all** |
| **bootanimation** | `frameworks/base/cmds/bootanimation/` | `bootanimation` | `bootanim.rc` | **all** |
| **idmap2d** | `frameworks/base/cmds/idmap2/idmap2d/` | `idmap2d` | `idmap2d.rc` | **all** |
| **rss_hwm_reset** | `frameworks/native/cmds/rss_hwm_reset/` | `rss_hwm_reset` | `rss_hwm_reset.rc` | **all** |
| **boottrace** | `frameworks/native/cmds/atrace/` | `boottrace` | `atrace.rc` | **all** |
| **tombstoned** | `system/core/debuggerd/` | `tombstoned` | - | **all** |
| **profcollectd** | `system/extras/profcollectd/` | `profcollectd` | `profcollectd.rc` | **userdebug/eng** |
| **lpdumpd** | `system/extras/partition_tools/` | `lpdumpd` | `lpdumpd.rc` | **all** |
| **cppreopts** | `system/extras/cppreopts/` | `cppreopts` | `cppreopts.rc` | **all** |
| **bootio** | `system/extras/boottime_tools/bootio/` | `bootio` | `bootio.rc` | **all** |
| **prng_seeder** | `system/core/` | `prng_seeder` | - | **all** |
| **snapuserd** | `system/core/fs_mgr/libsnapshot/snapuserd/` | `snapuserd` | - | **all** |
| **odsign** | `system/` | `odsign` | - | **all** |
| **credstore** | `system/security/credstore/` | `credstore` | - | **all** |
| **keystore2** | `system/security/keystore2/` | `keystore2` | - | **all** |
| **mdnsd** | `system/netd/` | `mdnsd` | - | **all** |
| **wificond` | `system/connectivity/wificond/` | `wificond` | - | **all** |
| **traced** | `system/extras/simpleperf/` | `traced` | - | **all** |
| **traced_probes** | `system/extras/simpleperf/` | `traced_probes` | - | **all** |
| **heapprofd` | `system/extras/heapprofd/` | `heapprofd` | - | **all** |
| **aconfigd** | `system/` | `aconfigd` | - | **all** |

---

## 五、Trusty/安全服务 (Secure Services)

> 位置: `system/core/trusty/`

| 服务名称 | 源码路径 | 模块名 | Init RC | 输出变体 |
|----------|----------|--------|---------|----------|
| **trusty.gatekeeper** | `system/core/trusty/gatekeeper/` | `android.hardware.gatekeeper-service.trusty` | `android.hardware.gatekeeper-service.trusty.rc` | **all** (Trusty设备) |
| **trusty.keymaster** | `system/core/trusty/keymaster/` | `android.hardware.security.keymint-service.trusty` | - | **all** (Trusty设备) |
| **trusty.confirmationui** | `system/core/trusty/confirmationui/` | `android.hardware.confirmationui-service.trusty` | `android.hardware.confirmationui-service.trusty.rc` | **all** (Trusty设备) |
| **trusty.storageproxyd** | `system/core/trusty/storage/proxy/` | `storageproxyd` | `rpmb_dev.rc` | **all** (Trusty设备) |
| **trusty.spiproxyd** | `system/core/trusty/utils/spiproxyd/` | `spiproxyd` | `proxy.rc` | **all** (Trusty设备) |
| **trusty.coverage-controller** | `system/core/trusty/utils/coverage-controller/` | `coverage-controller` | - | **eng** |
| **trusty.rpmb_dev** | `system/core/trusty/utils/rpmb_dev/` | `rpmb_dev` | `rpmb_dev.rc` | **all** (Trusty设备) |
| **trusty.secretkeeper** | `system/core/trusty/secretkeeper/` | `secretkeeper` | - | **all** (Trusty设备) |
| **trusty.secure_dpu** | `system/core/trusty/secure_dpu/` | `secure_dpu` | - | **all** (Trusty设备) |
| **trusty.apploader** | `system/core/trusty/apploader/` | `apploader` | - | **all** (Trusty设备) |
| **trusty.metrics** | `system/core/trusty/metrics/` | `metrics` | - | **all** (Trusty设备) |

---

## 六、硬件接口服务 (HAL Services)

> 位置: `hardware/interfaces/` (HIDL/AIDL)

| 接口名称 | 源码路径 | Init RC | 输出变体 |
|----------|----------|---------|----------|
| **android.hardware.audio** | `hardware/interfaces/audio/` | - | **all** |
| **android.hardware.audio.effect** | `hardware/interfaces/audio/effect/` | - | **all** |
| **android.hardware.authsecret** | `hardware/interfaces/authsecret/` | - | **all** |
| **android.hardware.automotive.audiocontrol** | `hardware/interfaces/automotive/audiocontrol/` | - | **车机** |
| **android.hardware.automotive.can** | `hardware/interfaces/automotive/can/` | `android.hardware.automotive.can.rc` | **车机** |
| **android.hardware.automotive.evs** | `hardware/interfaces/automotive/evs/` | - | **车机** |
| **android.hardware.automotive.remoteaccess** | `hardware/interfaces/automotive/remoteaccess/` | - | **车机** |
| **android.hardware.automotive.vehicle** | `hardware/interfaces/automotive/vehicle/` | - | **车机** |
| **android.hardware.biometrics.face** | `hardware/interfaces/biometrics/face/aidl/` | `face-default.rc` | **all** |
| **android.hardware.biometrics.fingerprint** | `hardware/interfaces/biometrics/fingerprint/aidl/` | `fingerprint-default.rc` | **all** |
| **android.hardware.bluetooth** | `hardware/interfaces/bluetooth/` | - | **all** |
| **android.hardware.boot** | `hardware/interfaces/boot/` | - | **all** |
| **android.hardware.broadcastradio** | `hardware/interfaces/broadcastradio/` | - | **all** |
| **android.hardware.camera.provider** | `hardware/interfaces/camera/provider/` | - | **all** |
| **android.hardware.cas** | `hardware/interfaces/cas/` | - | **all** |
| **android.hardware.composer.hwc3** | `hardware/interfaces/graphics/composer/` | - | **all** |
| **android.hardware.confirmationui** | `hardware/interfaces/confirmationui/` | `android.hardware.confirmationui@1.0-service.rc` | **all** |
| **android.hardware.contexthub** | `hardware/interfaces/contexthub/` | - | **all** |
| **android.hardware.drm** | `hardware/interfaces/drm/` | - | **all** |
| **android.hardware.dumpstate** | `hardware/interfaces/dumpstate/` | - | **all** |
| **android.hardware.fastboot** | `hardware/interfaces/fastboot/` | - | **all** |
| **android.hardware.gatekeeper** | `hardware/interfaces/gatekeeper/` | - | **all** |
| **android.hardware.gnss** | `hardware/interfaces/gnss/` | - | **all** |
| **android.hardware.graphics.allocator** | `hardware/interfaces/graphics/allocator/` | - | **all** |
| **android.hardware.graphics.mapper** | `hardware/interfaces/graphics/mapper/` | - | **all** |
| **android.hardware.health** | `hardware/interfaces/health/` | - | **all** |
| **android.hardware.identity** | `hardware/interfaces/identity/` | - | **all** |
| **android.hardware.input.processor** | `hardware/interfaces/input/` | - | **all** |
| **android.hardware.ir** | `hardware/interfaces/ir/` | - | **all** |
| **android.hardware.keymint** | `hardware/interfaces/security/keymint/` | - | **all** |
| **android.hardware.light** | `hardware/interfaces/light/aidl/` | `lights-default.rc` | **all** |
| **android.hardware.media.c2** | `hardware/interfaces/media/c2/` | `android.hardware.media.c2-default-service.rc` | **all** |
| **android.hardware.media.omx** | `hardware/interfaces/media/omx/` | `android.hardware.media.omx@1.0-service.rc` | **all** |
| **android.hardware.memtrack** | `hardware/interfaces/memtrack/` | - | **all** |
| **android.hardware.neuralnetworks** | `hardware/interfaces/neuralnetworks/` | - | **all** |
| **android.hardware.nfc** | `hardware/interfaces/nfc/` | - | **all** |
| **android.hardware.oemlock** | `hardware/interfaces/oemlock/` | - | **all** |
| **android.hardware.power** | `hardware/interfaces/power/aidl/` | `power-default.rc` | **all** |
| **android.hardware.power.stats** | `hardware/interfaces/power/stats/aidl/` | `power.stats-default.rc` | **all** |
| **android.hardware.radio** | `hardware/interfaces/radio/aidl/` | - | **手机** |
| **android.hardware.radio.config** | `hardware/interfaces/radio/config/` | - | **手机** |
| **android.hardware.rebootescrow** | `hardware/interfaces/rebootescrow/` | - | **all** |
| **android.hardware.secure_element** | `hardware/interfaces/secure_element/` | - | **all** |
| **android.hardware.security.authgraph** | `hardware/interfaces/security/authgraph/` | - | **all** |
| **android.hardware.security.keymint** | `hardware/interfaces/security/keymint/` | - | **all** |
| **android.hardware.security.rkp** | `hardware/interfaces/security/rkp/` | - | **all** |
| **android.hardware.security.secretkeeper** | `hardware/interfaces/security/secretkeeper/` | - | **all** |
| **android.hardware.sensors** | `hardware/interfaces/sensors/` | - | **all** |
| **android.hardware.soundtrigger** | `hardware/interfaces/soundtrigger/` | - | **all** |
| **android.hardware.tetheroffload** | `hardware/interfaces/tetheroffload/` | - | **all** |
| **android.hardware.thermal** | `hardware/interfaces/thermal/aidl/` | `thermal-example.rc` | **all** |
| **android.hardware.threadnetwork** | `hardware/interfaces/threadnetwork/` | - | **all** |
| **android.hardware.tv.cec** | `hardware/interfaces/tv/cec/` | - | **TV** |
| **android.hardware.tv.hdmi.cec** | `hardware/interfaces/tv/hdmi/cec/` | - | **TV** |
| **android.hardware.tv.hdmi.connection** | `hardware/interfaces/tv/hdmi/connection/` | - | **TV** |
| **android.hardware.tv.hdmi.earc** | `hardware/interfaces/tv/hdmi/earc/` | - | **TV** |
| **android.hardware.tv.tuner** | `hardware/interfaces/tv/tuner/` | - | **TV** |
| **android.hardware.usb** | `hardware/interfaces/usb/` | - | **all** |
| **android.hardware.usb.gadget** | `hardware/interfaces/usb/gadget/` | - | **all** |
| **android.hardware.uwb** | `hardware/interfaces/uwb/` | - | **all** |
| **android.hardware.vibrator** | `hardware/interfaces/vibrator/` | - | **all** |
| **android.hardware.weaver** | `hardware/interfaces/weaver/` | - | **all** |
| **android.hardware.wifi** | `hardware/interfaces/wifi/aidl/` | `android.hardware.wifi-service.rc` | **all** |

---

## 七、系统硬件接口服务

> 位置: `system/hardware/interfaces/`

| 接口名称 | 源码路径 | Init RC | 输出变体 |
|----------|----------|---------|----------|
| **android.system.suspend** | `system/hardware/interfaces/suspend/` | `android.system.suspend-service.rc` | **all** |
| **android.hardware.keystore2** | `system/hardware/interfaces/keystore2/` | - | **all** |
| **android.hardware.net** | `system/hardware/interfaces/net/` | - | **all** |

---

## 八、包服务 (Package Services)

> 位置: `packages/services/`

| 服务名称 | 源码路径 | 模块名 | 输出变体 |
|----------|----------|--------|----------|
| **Telecomm** | `packages/services/Telecomm/` | `Telecomm` | **手机** |
| **Telephony** | `packages/services/Telephony/` | `Telephony` | **手机** |
| **Mms** | `packages/services/Mms/` | `Mms` | **手机** |
| **Mtp** | `packages/services/Mtp/` | `Mtp` | **all** |
| **BuiltInPrintService** | `packages/services/BuiltInPrintService/` | `BuiltInPrintService` | **all** |
| **Car Service** | `packages/services/Car/service/` | `CarService` | **车机** |
| **DeviceAsWebcam** | `packages/services/DeviceAsWebcam/` | `DeviceAsWebcam` | **all** |
| **AlternativeNetworkAccess** | `packages/services/AlternativeNetworkAccess/` | `AlternativeNetworkAccess` | **all** |
| **Iwlan** | `packages/services/Iwlan/` | `Iwlan` | **all** |

---

## 九、车机服务 (Automotive Services)

> 位置: `packages/services/Car/`

| 服务名称 | 源码路径 | Init RC | 输出变体 |
|----------|----------|---------|----------|
| **carwatchdogd** | `packages/services/Car/cpp/watchdog/server/` | `carwatchdogd.rc` | **车机** |
| **cartelemetryd** | `packages/services/Car/cpp/telemetry/cartelemetryd/` | `android.automotive.telemetryd@1.0.rc` | **车机** |
| **evsmanagerd** | `packages/services/Car/cpp/evs/manager/aidl/` | `evsmanagerd.rc` | **车机** |
| **evs_app** | `packages/services/Car/cpp/evs/apps/default/` | `evs_app.rc` | **车机** |
| **carpowerpolicyd** | `packages/services/Car/cpp/powerpolicy/server/` | `carpowerpolicyd.rc` | **车机** |
| **cardisplayproxyd** | `packages/services/Car/cpp/displayproxy/` | `cardisplayproxyd.rc` | **车机** |
| **carbugreportd** | `packages/services/Car/cpp/bugreport/` | `carbugreportd.rc` | **车机** |
| **computepipe_router** | `packages/services/Car/cpp/computepipe/router/` | `android.automotive.computepipe.router@1.0.rc` | **车机** |
| **packagemanagerproxyd** | `packages/services/Car/cpp/packagemanagerproxy/service/` | `packagemanagerproxyd.rc` | **车机** |
| **com.android.car.procfsinspector** | `packages/services/Car/libs/procfs-inspector/server/` | `com.android.car.procfsinspector.rc` | **车机** |

---

## 十、模块服务 (Module Services)

> 位置: `packages/modules/`

| 服务名称 | 源码路径 | Init RC | 输出变体 |
|----------|----------|---------|----------|
| **statsd** | `packages/modules/StatsD/apex/` | `statsd.rc` | **all** |
| **derive_sdk** | `packages/modules/SdkExtensions/derive_sdk/` | `derive_sdk.rc` | **all** |
| **derive_classpath** | `packages/modules/SdkExtensions/derive_classpath/` | `derive_classpath.rc` | **all** |
| **uprobestats** | `packages/modules/UprobeStats/src/` | `UprobeStats.rc` | **all** |
| **bpfloader** | `packages/modules/Connectivity/bpf/loader/` | `netbpfload.rc` | **all** |
| **microdroid_manager** | `packages/modules/Virtualization/guest/microdroid_manager/` | `microdroid_manager.rc` | **emu** |
| **authfs_service** | `packages/modules/Virtualization/guest/authfs_service/` | `authfs_service.rc` | **emu** |
| **composd** | `packages/modules/Virtualization/build/compos/` | `composd.rc` | **emu** |
| **vfio_handler** | `packages/modules/Virtualization/build/apex/` | `vfio_handler.rc` | **emu** |
| **vmnic** | `packages/modules/Virtualization/build/apex/` | `vmnic.rc` | **emu** |
| **neuralnetworks (sample)** | `packages/modules/NeuralNetworks/driver/sample_aidl/` | `android.hardware.neuralnetworks-service-sample-all.rc` | **all** |

---

## 十一、APEX 服务

| 服务名称 | APEX 模块 | Init RC | 输出变体 |
|----------|-----------|---------|----------|
| **media.swcodec** | `com.android.media.swcodec` | `mediaswcodec.rc` | **all** |
| **media.transcoding** | `com.android.media` | `mediatranscoding.rc` | **all** |
| **statsd** | `com.android.os.statsd` | `statsd.rc` | **all** |
| **adbd** | `com.android.adbd` | `adbd.rc` | **all** |
| **apexd** | `com.android.apex` | `apexd.rc` | **all** |

---

## 十二、设备专属服务 (Device-Specific)

> 位置: `device/google/` (以 Pixel 为例)

| 服务名称 | 设备 | Init RC | 输出变体 |
|----------|------|---------|----------|
| **vendor.health-zumapro** | Pixel (zumapro) | `android.hardware.health-service.zumapro.rc` | **all** (Pixel) |
| **vendor.health-gs201** | Pixel (gs201) | `android.hardware.health-service.gs201.rc` | **all** (Pixel) |
| **vendor.boot-default** | Pixel | `android.hardware.boot-service.default-pixel.rc` | **all** (Pixel) |
| **vendor.dumpstate-default** | Pixel | `android.hardware.dumpstate-service.rc` | **all** (Pixel) |
| **vendor.power-hal-aidl** | Pixel | `android.hardware.power-service.pixel-libperfmgr.rc` | **all** (Pixel) |
| **vendor.thermal-hal** | Pixel | `android.hardware.thermal-service.pixel.rc` | **all** (Pixel) |
| **vendor.vibrator** | Pixel | `android.hardware.vibrator-service.cs40l25.rc` | **all** (Pixel) |
| **vendor.power.stats** | Pixel | `android.hardware.power.stats-service.pixel.rc` | **all** (Pixel) |
| **vendor.hwcomposer-3** | Pixel | `hwc3-pixel.rc` | **all** (Pixel) |
| **vendor.graphics.allocator** | Pixel | `android.hardware.graphics.allocator-aidl-service.rc` | **all** (Pixel) |
| **vendor.memtrack** | Pixel | `memtrack.rc` | **all** (Pixel) |
| **vendor.perfstatsd** | Pixel | `perfstatsd.rc` | **all** (Pixel) |
| **vendor.pixelstats_vendor** | Pixel | `pixelstats-vendor.zumapro.rc` | **all** (Pixel) |
| **vendor.usb** | Pixel | `android.hardware.usb-service-i2c11.rc` | **all** (Pixel) |
| **vendor.usb-gadget** | Pixel | `android.hardware.usb.gadget-service.rc` | **all** (Pixel) |
| **vendor.lights** | Pixel (tangorpro) | `android.hardware.lights-service.tangorpro.rc` | **all** (Pixel) |
| **vendor.drm-castkey** | Pixel (tangorpro) | `android.hardware.drm-service.castkey.rc` | **all** (Pixel) |
| **vendor.nfc** | 多种设备 | `android.hardware.nfc@1.2-service.rc` | **all** (含NFC设备) |
| **vendor.gnss** | 多种设备 | `android.hardware.gnss-service.rc` | **all** (含GNSS设备) |
| **vendor.threadnetwork** | 多种设备 | `threadnetwork_hal_service.rc` | **all** (含Thread设备) |
| **gs_watchdogd** | gs-common | `init.gs_watchdogd.rc` | **all** (gs设备) |
| **gnssd** | 多种设备 | `init.gnss.rc` | **all** (含GNSS设备) |

---

## 十三、模拟器专属服务 (Cuttlefish Emulator)

> 位置: `device/google/cuttlefish/`

| 服务名称 | 说明 | 输出变体 |
|----------|------|----------|
| **CuttlefishService** | Cuttlefish 核心服务 | **emu** |
| **socket_vsock_proxy** | VSock 代理 | **emu** |
| **tombstone_transmit** | Tombstone 传输 | **emu** |
| **tombstone_producer** | Tombstone 生产者 | **emu** |
| **suspend_blocker** | 休眠阻止器 | **emu** |
| **metrics_helper** | 指标助手 | **emu** |
| **snapshot_hook_post_resume** | 快照恢复后钩子 | **emu** |
| **snapshot_hook_pre_suspend** | 快照休眠前钩子 | **emu** |
| **checkpoint_gc** | 检查点GC | **emu** |
| **QualifiedNetworksService** | 合格网络服务 | **emu** |
| **GbaService** | GBA服务 | **emu** |
| **CFSatelliteService** | CF卫星服务 | **emu** |
| **dlkm_loader** | DLKM加载器 | **emu** |
| **com.google.cf.nfc** | CF NFC HAL | **emu** |
| **com.android.hardware.audio** | CF 音频 HAL | **emu** |
| **com.android.hardware.contexthub** | CF 上下文中心 HAL | **emu** |
| **com.android.hardware.drm.clearkey** | CF Clearkey DRM HAL | **emu** |
| **com.google.cf.confirmationui** | CF 确认UI HAL | **emu** |
| **com.android.hardware.dumpstate** | CF Dumpstate HAL | **emu** |
| **com.android.hardware.gatekeeper.cf_remote** | CF 远程Gatekeeper HAL | **emu** |
| **com.android.hardware.gatekeeper.nonsecure** | CF 非安全Gatekeeper | **emu** |
| **com.google.cf.health** | CF 健康 HAL | **emu** |
| **com.google.cf.health.storage** | CF 健康存储 HAL | **emu** |
| **com.android.hardware.input.processor** | CF 输入处理器 HAL | **emu** |
| **com.android.hardware.net.nlinterceptor** | CF Netlink拦截器 HAL | **emu** |
| **com.google.cf.light** | CF 灯光 HAL | **emu** |
| **com.android.hardware.keymint.rust_cf_remote** | CF 远程KeyMint HAL | **emu** |
| **com.android.hardware.security.authgraph** | CF AuthGraph HAL | **emu** |
| **com.android.hardware.security.secretkeeper** | CF SecretKeeper HAL | **emu** |
| **com.android.hardware.power** | CF 电源 HAL | **emu** |
| **com.android.hardware.tetheroffload** | CF 网络共享卸载 HAL | **emu** |
| **com.android.hardware.thermal** | CF 温控 HAL | **emu** |
| **com.android.hardware.neuralnetworks** | CF 神经网络 HAL | **emu** |
| **com.android.hardware.usb** | CF USB HAL | **emu** |
| **com.android.hardware.boot** | CF 启动 HAL | **emu** |
| **com.android.hardware.memtrack** | CF 内存追踪 HAL | **emu** |
| **android.hardware.fastboot@1.1-impl-mock** | CF Mock Fastboot HAL | **emu** |
| **fastbootd** | Fastboot 守护进程 | **emu** |
| **com.android.hardware.wifi** | CF WiFi HAL | **emu** |
| **com.google.cf.wifi** | CF WiFi | **emu** |
| **com.google.cf.wpa_supplicant** | CF WPA Supplicant | **emu** |
| **com.android.hardware.uwb** | CF UWB HAL | **emu** |
| **com.android.hardware.cas** | CF CAS HAL | **emu** |
| **com.android.hardware.threadnetwork** | CF Thread网络 HAL | **emu** |
| **ThreadNetworkDemoApp** | Thread网络演示应用 | **emu** |

---

## 十四、恢复模式服务 (Recovery)

| 服务名称 | 说明 | 输出变体 |
|----------|------|----------|
| **adbd.recovery** | 恢复模式ADB | **rec** |
| **charger.recovery** | 恢复模式充电 | **rec** |
| **init_second_stage.recovery** | 恢复模式第二阶段init | **rec** |
| **linker.recovery** | 恢复模式链接器 | **rec** |
| **recovery** | 恢复模式主程序 | **rec** |
| **servicemanager.recovery** | 恢复模式服务管理器 | **rec** |
| **shell_and_utilities_recovery** | 恢复模式Shell工具 | **rec** |
| **watchdogd.recovery** | 恢复模式看门狗 | **rec** |
| **update_engine_sideload** | OTA sideload | **rec** |

---

## 十五、调试专用服务 (Debug Builds Only)

> 这些服务仅在 `userdebug` 或 `eng` 构建中输出

| 服务名称 | 源码路径 | 输出变体 |
|----------|----------|----------|
| **profcollectd** | `system/extras/profcollectd/` | **userdebug/eng** |
| **thermal_logd** | `device/google/gs-common/thermal/` | **eng** |
| **strace** | `external/strace/` | **userdebug/eng** |
| **su** | `system/extras/su/` | **userdebug/eng** |
| **sanitizer-status** | `system/extras/sanitizer-status/` | **userdebug/eng** |
| **procrank** | `system/extras/procrank/` | **userdebug/eng** |
| **showmap** | `system/extras/showmap/` | **userdebug/eng** |
| **iotop** | `system/extras/iotop/` | **userdebug/eng** |
| **iperf3` | `external/iperf3/` | **userdebug/eng** |
| **sqlite3** | `external/sqlite/` | **userdebug/eng** |
| **ss** | `external/iproute2/` | **userdebug/eng** |
| **tracepath** | `external/iputils/` | **userdebug/eng** |
| **traceroute6** | `external/iputils/` | **userdebug/eng** |
| **unwind_info** | `system/libunwind/` | **userdebug/eng** |
| **record_binder** | `system/extras/` | **userdebug/eng** |
| **servicedispatcher** | `system/extras/` | **userdebug/eng** |
| **start_with_lockagent** | `system/extras/` | **userdebug/eng** |
| **logpersist.start** | `system/core/logd/` | **userdebug/eng** |
| **avbctl** | `system/extras/extras/` | **userdebug/eng** |
| **bootctl** | `system/extras/bootctl/` | **userdebug/eng** |
| **tinycap** | `external/tinyalsa/` | **userdebug/eng** |
| **tinymix** | `external/tinyalsa/` | **userdebug/eng** |
| **tinyplay** | `external/tinyalsa/` | **userdebug/eng** |
| **tinypcminfo** | `external/tinyalsa/` | **userdebug/eng** |
| **tinyhostless** | `external/tinyalsa/` | **userdebug/eng** |
| **update_engine_client** | `system/update_engine/` | **userdebug/eng** |
| **ot-cli-ftd` | `system/ot-cli/` | **userdebug/eng** |
| **ot-ctl** | `system/ot-ctl/` | **userdebug/eng** |
| **idlcli** | `system/idlcli/` | **userdebug/eng** |
| **evemu-record** | `external/evemu/` | **userdebug/eng** |
| **dmuserd** | `system/dmuserd/` | **userdebug/eng** |
| **adevice_fingerprint** | `system/extras/` | **userdebug/eng** |
| **layertracegenerator` | `frameworks/native/` | **userdebug/eng** |

---

## 十六、手持设备/手机专属服务

> 位置: `frameworks/base/cmds/`, `packages/apps/` 等

| 服务名称 | 源码路径 | 模块名 | 输出变体 |
|----------|----------|--------|----------|
| **bootanimation** | `frameworks/base/cmds/bootanimation/` | `bootanimation` | **手机** |
| **BasicDreams** | `packages/apps/BasicDreams/` | - | **手机** |
| **BluetoothMidiService** | `packages/apps/BluetoothMidiService/` | - | **手机** |
| **CalendarProvider** | `packages/providers/CalendarProvider/` | - | **手机** |
| **CameraExtensionsProxy` | `packages/apps/CameraExtensionsProxy/` | - | **手机** |
| **CaptivePortalLogin** | `packages/apps/CaptivePortalLogin/` | - | **手机** |
| **CertInstaller** | `packages/apps/CertInstaller/` | - | **手机** |
| **CredentialManager** | `packages/apps/CredentialManager/` | - | **手机** |
| **DeviceDiagnostics** | `packages/apps/DeviceDiagnostics/` | - | **手机** |
| **DocumentsUI** | `packages/apps/DocumentsUI/` | - | **手机** |
| **EasterEgg** | `packages/apps/EasterEgg/` | - | **手机** |
| **FusedLocation** | `packages/services/FusedLocation/` | - | **手机** |
| **InputDevices** | `packages/apps/InputDevices/` | - | **手机** |
| **KeyChain** | `packages/apps/KeyChain/` | - | **手机** |
| **ManagedProvisioning** | `packages/apps/ManagedProvisioning/` | - | **手机** |
| **MmsService** | `packages/services/Mms/` | - | **手机** |
| **MusicFX** | `packages/apps/MusicFX/` | - | **手机** |
| **PacProcessor** | `packages/apps/PacProcessor/` | - | **手机** |
| **PrintSpooler** | `packages/apps/PrintSpooler/` | - | **手机** |
| **screenrecord** | `frameworks/base/cmds/screenrecord/` | - | **手机** |
| **Telecom** | `packages/services/Telecomm/` | - | **手机** |
| **TeleService** | `packages/services/Telephony/` | - | **手机** |
| **Traceur` | `packages/apps/Traceur/` | - | **手机** |
| **VpnDialogs** | `packages/apps/VpnDialogs/` | - | **手机** |
| **vr** | `packages/apps/VR/` | - | **手机** |

---

## 十七、TV 专属服务

| 服务名称 | 源码路径 | 输出变体 |
|----------|----------|----------|
| **TvProvider** | `packages/providers/TvProvider/` | **TV** |
| **libmedia_tv_tuner** | `frameworks/av/media/` | **TV** (含调谐器) |
| **PackageInstaller_tv** | `packages/apps/PackageInstaller/` | **TV** |
| **com.android.media.tv.remoteprovider** | `frameworks/base/` | **TV** |

---

## 统计汇总

| 类别 | 服务数量 | 说明 |
|------|----------|------|
| Framework Java 服务 | ~35 | 运行于 system_server |
| Native 系统服务 | ~12 | SurfaceFlinger/GPU/传感器等 |
| 媒体服务 | ~15 | 音频/视频/相机/DRM |
| 系统核心守护进程 | ~40 | init/vold/netd/lmkd等 |
| Trusty/安全服务 | ~11 | 可信执行环境服务 |
| 硬件接口服务(HAL) | ~50 | HIDL/AIDL 硬件抽象层 |
| 包服务 | ~9 | Telephony/Car/Mms等 |
| 车机服务 | ~10 | 汽车电子服务 |
| 模块服务 | ~11 | statsd/derive_sdk等 |
| APEX 服务 | ~5 | 可更新系统组件 |
| 设备专属服务 | ~20+ | Pixel等设备专用 |
| 模拟器专属服务 | ~40+ | Cuttlefish 模拟器 |
| 恢复模式服务 | ~9 | Recovery 模式 |
| 调试专用服务 | ~30 | userdebug/eng 专用 |
| **总计** | **~300+** | 含所有变体 |

---

## 构建变体包含关系图

```
                        ┌─────────────────────────────┐
                        │         eng (工程版)          │
                        │  ┌─────────────────────────┐│
                        │  │    userdebug (调试版)    ││
                        │  │  ┌─────────────────────┐││
                        │  │  │   user (用户版)      │││
                        │  │  │                     │││
                        │  │  │  核心系统服务 (~150) │││
                        │  │  │  HAL 服务 (~50)      │││
                        │  │  │  Framework 服务 (~35)│││
                        │  │  └─────────────────────┘││
                        │  │  + 调试工具 (~30)        ││
                        │  │  + adb root             ││
                        │  │  + strace/su/procrank  ││
                        │  └─────────────────────────┘│
                        │  + eng专属工具              │
                        │  + thermal_logd            │
                        └─────────────────────────────┘

  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │  emulator    │  │    车机      │  │     TV       │  │   recovery   │
  │  (模拟器)    │  │  (Automotive)│  │              │  │  (恢复模式)   │
  │              │  │              │  │              │  │              │
  │ + Cuttlefish │  │ + CarService │  │ + TvProvider │  │ + recovery   │
  │ + microdroid │  │ + carwatchdog│  │ + tuner HAL  │  │ + adbd.rec   │
  │ + composd    │  │ + evsmanager │  │ + cec HAL    │  │ + charger.rec│
  │ + vfio       │  │ + vehicle HAL│  │              │  │              │
  │ + vmnic      │  │ + can HAL    │  │              │  │              │
  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

---

## 关键配置文件位置

| 文件 | 说明 |
|------|------|
| `build/make/core/main.mk` | 构建变体定义 (user/userdebug/eng) |
| `build/make/target/product/base_system.mk` | 基础系统包列表 |
| `build/make/target/product/generic_system.mk` | 通用系统包 |
| `build/make/target/product/handheld_system.mk` | 手持设备系统包 |
| `build/make/target/product/handheld_product.mk` | 手持设备产品包 |
| `build/make/target/product/handheld_vendor.mk` | 手持设备Vendor包 |
| `build/make/target/product/atv_system.mk` | TV系统包 |
| `device/google/cuttlefish/shared/device.mk` | 模拟器设备配置 |
| `device/google/gs-common/` | Pixel设备通用配置 |
| `system/core/rootdir/init.rc` | 核心init脚本 |
| `build/make/target/product/base_vendor.mk` | 基础Vendor包(含recovery) |
