# AOSP Android 15 device executable source index

This is a source-only index. It uses `generic_system`/GSI as the common Android
baseline, then lists device-family additions. Entries are executable module or
installed command names followed by their source/build-definition location.

It does not claim that every entry is callable by the unprivileged `shell` SELinux
domain. Product flags, architecture, build variant, APEX selection and proprietary
vendor packages still affect the final image.

## Product baseline

- Common product list: `build/make/target/product/base_system.mk`
- Handheld additions: `build/make/target/product/handheld_system.mk`
- Media additions: `build/make/target/product/media_system.mk`
- GSI additions: `build/make/target/product/generic_system.mk`
- Runtime/ART APEX selection: `build/make/target/product/runtime_libart.mk`
- Generic vendor/recovery baseline: `build/make/target/product/base_vendor.mk`

## GSI common: framework shell commands

| Installed command | Source/build definition |
|---|---|
| `abx`, `abx2xml`, `xml2abx` | `frameworks/base/cmds/abx/Android.bp` |
| `am` | `frameworks/base/cmds/am/Android.bp` |
| `appops` | `frameworks/base/cmds/appops/Android.bp` |
| `appwidget` | `frameworks/base/cmds/appwidget/Android.bp` |
| `bmgr` | `frameworks/base/cmds/bmgr/Android.bp` |
| `bu` | `frameworks/base/cmds/bu/Android.bp` | backup
| `content` | `frameworks/base/cmds/content/Android.bp` | 本地数据库，短信啊，之类的
| `device_config` | `frameworks/base/cmds/device_config/Android.bp` |
| `dpm` | `frameworks/base/cmds/dpm/Android.bp` |
| `hid` | `frameworks/base/cmds/hid/Android.bp` |
| `ime` | `frameworks/base/cmds/ime/Android.bp` |
| `incident-helper-cmd` | `frameworks/base/cmds/incident_helper/Android.bp` |
| `input` | `frameworks/base/cmds/input/Android.bp` |
| `locksettings` | `frameworks/base/cmds/locksettings/Android.bp` |
| `monkey` | `development/cmds/monkey/Android.bp` |
| `pm` | `frameworks/base/cmds/pm/Android.bp` |
| `requestsync` | `frameworks/base/cmds/requestsync/Android.bp` |
| `settings` | `frameworks/base/cmds/settings/Android.bp` |
| `sm` | `frameworks/base/cmds/sm/Android.bp` |
| `svc` | `frameworks/base/cmds/svc/Android.bp` |
| `uiautomator` | `frameworks/base/cmds/uiautomator/cmds/uiautomator/Android.bp` |
| `uinput` | `frameworks/base/cmds/uinput/Android.bp` |
| `vr` | `frameworks/base/cmds/vr/Android.bp` |
| `wm` | `frameworks/base/cmds/wm/Android.bp` |

## GSI common: native and Rust executables

| Installed command/module | Source/build definition |
|---|---|
| `aconfigd` | `system/server_configurable_flags/aconfigd/Android.bp` |
| `aflags` | `build/make/tools/aconfig/aflags/Android.bp` | // root
| `android.system.suspend-service` | `system/hardware/interfaces/suspend/1.0/default/Android.bp` |
| `apexd` | `system/apex/apexd/Android.bp` | //root
| `app_process`, `app_process32`, `app_process64` | `frameworks/base/cmds/app_process/Android.bp` |
| `atrace` | `frameworks/native/cmds/atrace/Android.bp` |
| `audioserver` | `frameworks/av/media/audioserver/Android.bp` |
| `auditctl` | `system/logging/logd/Android.bp` |
| `awk` | `external/one-true-awk/Android.bp` |
| `bc` | `external/bc/Android.bp` |
| `bcc` | `frameworks/compile/libbcc/tools/bcc/Android.bp` |
| `blank_screen` | `hardware/interfaces/light/utils/Android.bp` |
| `blkid` | `external/e2fsprogs/misc/Android.bp` |
| `bootanimation` | `frameworks/base/cmds/bootanimation/Android.bp` |
| `bootstat` | `system/core/bootstat/Android.bp` |
| `bpfloader` | `system/bpf/loader/Android.bp` |
| `bugreport` | `frameworks/native/cmds/bugreport/Android.bp` |
| `bugreportz` | `frameworks/native/cmds/bugreportz/Android.bp` |
| `bzip2` | `external/bzip2/Android.bp` |
| `cameraserver` | `frameworks/av/camera/cameraserver/Android.bp` |
| `charger` | `system/core/healthd/Android.bp` |
| `cmd` | `frameworks/native/cmds/cmd/Android.bp` |
| `cpu-target-features` | `bionic/cpu_target_features/Android.bp` |
| `credstore` | `system/security/identity/Android.bp` |
| `debuggerd` | `system/core/debuggerd/Android.bp` |
| `dmctl` | `system/core/fs_mgr/tools/Android.bp` |
| `dmesgd` | `system/dmesgd/Android.bp` |
| `dnsmasq` | `external/dnsmasq/src/Android.bp` |
| `drmserver` | `frameworks/av/drm/drmserver/Android.bp` |
| `dump.erofs` | `external/erofs-utils/Android.bp` |
| `dumpstate` | `frameworks/native/cmds/dumpstate/Android.bp` |
| `dumpsys` | `frameworks/native/cmds/dumpsys/Android.bp` |
| `e2fsck` | `external/e2fsprogs/e2fsck/Android.bp` |
| `flags_health_check` | `system/server_configurable_flags/disaster_recovery/Android.bp` |
| `fsck.erofs`, `mkfs.erofs` | `external/erofs-utils/Android.bp` |
| `fsck.exfat` | `external/exfatprogs/fsck/Android.bp` |
| `fsck.f2fs`, `make_f2fs` | `external/f2fs-tools/Android.bp` |
| `fsck_msdos` | `external/fsck_msdos/Android.bp` |
| `gatekeeperd` | `system/core/gatekeeperd/Android.bp` |
| `gpu_counter_producer` | `frameworks/base/cmds/gpu_counter_producer/Android.bp` |
| `gpuservice` | `frameworks/native/services/gpuservice/Android.bp` |
| `gsid`, `gsi_tool` | `system/gsid/Android.bp` |
| `heapprofd`, `heapprofd_client` | `external/perfetto/Android.bp` |
| `idmap2`, `idmap2d` | `frameworks/base/cmds/idmap2/Android.bp` |
| `incident` | `frameworks/base/cmds/incident/Android.bp` |
| `incidentd` | `frameworks/base/cmds/incidentd/Android.bp` |
| `incident_helper` | `frameworks/base/cmds/incident_helper/Android.bp` |
| `init`, `ueventd` | `system/core/init/Android.bp` |
| `installd` | `frameworks/native/cmds/installd/Android.bp` |
| `ip` | `external/iproute2/ip/Android.bp` |
| `iptables` | `external/iptables/iptables/Android.bp` |
| `kcmdlinectrl` | `system/extras/kcmdlinectrl/Android.bp` |
| `keystore2` | `system/security/keystore2/Android.bp` |
| `ld.mc` | `frameworks/compile/mclinker/tools/mcld/Android.bp` |
| `ldd` | `bionic/linker/Android.bp` |
| `linker`, `linker64` | `bionic/linker/Android.bp` |
| `llkd` | `system/core/llkd/Android.bp` |
| `lmkd` | `system/memory/lmkd/Android.bp` |
| `logcat` | `system/logging/logcat/Android.bp` |
| `logd` | `system/logging/logd/Android.bp` |
| `logwrapper` | `system/logging/logwrapper/Android.bp` |
| `lpdump` | `system/extras/partition_tools/Android.bp` |
| `lshal` | `frameworks/native/cmds/lshal/Android.bp` |
| `mdnsd` | `external/mdnsresponder/Android.bp` |
| `mediaextractor` | `frameworks/av/services/mediaextractor/Android.bp` |
| `mediametrics` | `frameworks/av/services/mediametrics/Android.bp` |
| `mediaserver` | `frameworks/av/media/mediaserver/Android.bp` |
| `mini-keyctl` | `system/core/mini_keyctl/Android.bp` |
| `misctrl` | `bootable/recovery/bootloader_message/Android.bp` |
| `mke2fs`, `tune2fs` | `external/e2fsprogs/misc/Android.bp` |
| `mkfs.exfat` | `external/exfatprogs/mkfs/Android.bp` |
| `mtectrl` | `system/extras/mtectrl/Android.bp` |
| `ndc`, `netd` | `system/netd/server/Android.bp` |
| `newfs_msdos` | `external/newfs_msdos/Android.bp` |
| `odsign` | `system/security/ondevice-signing/Android.bp` |
| `perfetto` | `external/perfetto/Android.bp` |
| `ping`, `ping6` | `external/iputils/Android.bp` |
| `pintool` | `system/extras/pinner/Android.bp` |
| `printflags` | `build/make/tools/aconfig/printflags/Android.bp` |
| `prng_seeder` | `system/security/prng_seeder/Android.bp` |
| `reboot` | `system/core/reboot/Android.bp` |
| `recovery-persist`, `recovery-refresh` | `bootable/recovery/Android.bp` |
| `resize2fs` | `external/e2fsprogs/resize/Android.bp` |
| `rss_hwm_reset` | `frameworks/native/cmds/rss_hwm_reset/Android.bp` |
| `run-as` | `system/core/run-as/Android.bp` |
| `screencap` | `frameworks/base/cmds/screencap/Android.bp` |
| `screenrecord` | `frameworks/av/cmds/screenrecord/Android.bp` |
| `sdcard` | `system/core/sdcard/Android.bp` |
| `secdiscard` | `system/vold/Android.bp` |
| `sensorservice` | `frameworks/native/services/sensorservice/Android.bp` |
| `service` | `frameworks/native/cmds/service/Android.bp` |
| `servicemanager` | `frameworks/native/cmds/servicemanager/Android.bp` |
| `settaskprofile` | `system/core/libprocessgroup/tools/Android.bp` |
| `sfdo` | `frameworks/native/cmds/sfdo/Android.bp` |
| `sgdisk` | `external/gptfdisk/Android.bp` |
| `sh` | `external/mksh/Android.bp` |
| `simpleperf` | `system/extras/simpleperf/Android.bp` |
| `simpleperf_app_runner` | `system/extras/simpleperf/simpleperf_app_runner/Android.bp` |
| `snapshotctl` | `system/core/fs_mgr/libsnapshot/Android.bp` |
| `snapuserd` | `system/core/fs_mgr/libsnapshot/snapuserd/Android.bp` |
| `storaged` | `system/core/storaged/Android.bp` |
| `surfaceflinger` | `frameworks/native/services/surfaceflinger/Android.bp` |
| `tc` | `external/iproute2/tc/Android.bp` |
| `tcpdump` | `external/tcpdump/Android.bp` |
| `tombstoned` | `system/core/debuggerd/Android.bp` |
| `traced`, `traced_probes`, `traced_perf`, `trigger_perfetto`, `mm_events` | `external/perfetto/Android.bp` |
| `uncrypt` | `bootable/recovery/uncrypt/Android.bp` |
| `update_engine`, `update_engine_sideload`, `update_engine_client` | `system/update_engine/Android.bp` |
| `update_verifier` | `bootable/recovery/update_verifier/Android.bp` |
| `usbd` | `system/core/usbd/Android.bp` |
| `vdc`, `vold`, `secdiscard` | `system/vold/Android.bp` |
| `vintf` | `system/libvintf/Android.bp` |
| `watchdogd` | `system/core/watchdogd/Android.bp` |
| `wificond` | `system/connectivity/wificond/Android.bp` |
| `ziptool` | `system/libziparchive/Android.bp` |

## GSI common: OTA helpers and wrapper links

| Installed command | Source/build definition |
|---|---|
| `cppreopts.sh`, `preloads_copy.sh`, `preopt2cachename` | `system/extras/cppreopts/Android.bp` |
| `otapreopt`, `otapreopt_chroot`, `otapreopt_script`, `otapreopt_slot` | `frameworks/native/cmds/installd/Android.bp` |
| `netutils-wrapper-1.0` | `system/netd/netutils_wrappers/Android.bp` |
| `ip-wrapper-1.0`, `ip6tables-wrapper-1.0`, `iptables-wrapper-1.0`, `ndc-wrapper-1.0`, `tc-wrapper-1.0` | `system/netd/netutils_wrappers/Android.bp` |
| `abb` | `packages/modules/adb/Android.bp` |
| `remount` (debuggable builds) | `system/core/fs_mgr/Android.bp` |

## Toybox

- Binary and symlink list: `external/toybox/Android.bp`
- Command implementations: `external/toybox/toys/`
- Shared implementation: `external/toybox/lib/`

The following installed names are symlinks to `toybox`:

```text
[ acpi base64 basename blockdev brctl cal cat chattr chcon chgrp chmod chown
chroot chrt cksum clear comm cmp cp cpio cut date dd devmem df diff dirname
dmesg dos2unix du echo egrep env expand expr fallocate false fgrep file find
flock fmt free fsync getconf getenforce getfattr getopt gpiodetect gpiofind
gpioget gpioinfo gpioset grep groups gunzip gzip head hostname hwclock
i2cdetect i2cdump i2cget i2cset i2ctransfer iconv id ifconfig inotifyd insmod
install ionice iorenice kill killall load_policy ln log logger logname losetup
ls lsattr lsmod lsof lspci lsusb md5sum memeater mkdir mkfifo mknod mkswap
mktemp microcom modinfo more mount mountpoint mv nc netcat netstat nice nl
nohup nproc nsenter od paste patch pgrep pidof pkill pmap printenv printf ps
pwd readelf readlink realpath renice restorecon rm rmdir rmmod rtcwake runcon
sed sendevent seq setenforce setfattr setsid sha1sum sha224sum sha256sum
sha384sum sha512sum sleep sort split stat strings stty swapoff swapon sync
sysctl tac tail tar taskset tee test time timeout top touch tr true truncate
tty uclampset ulimit umount uname uniq unix2dos unlink unshare uptime usleep
uudecode uuencode uuidgen vi vmstat watch wc which whoami xargs xxd yes zcat
```

Several names share one implementation file. For example `egrep`/`fgrep` use
`toys/posix/grep.c`, checksum commands use the corresponding checksum toy, GPIO
commands use `toys/other/gpiod.c`, and I2C commands use
`toys/other/i2ctools.c`.

## Toolbox

- Binary and implementations: `system/core/toolbox/Android.bp`
- Installed names: `toolbox`, `getevent`, `getprop`, `modprobe`, `setprop`,
  `start`, `stop`
- Main sources: `system/core/toolbox/toolbox.c`, `getevent.c`, `getprop.cpp`,
  `modprobe.cpp`, `setprop.cpp`, `start.cpp`

## Default APEX bin directories

| Installed executable | APEX | Source/build definition |
|---|---|---|
| `adbd` | `com.android.adbd` | `packages/modules/adb/Android.bp` |
| `art_boot` | `com.android.art` | `art/tools/Android.bp` |
| `art_exec` | `com.android.art` | `art/libarttools/Android.bp` |
| `artd` | `com.android.art` | `art/artd/Android.bp` |
| `dalvikvm`, `dalvikvm32`, `dalvikvm64` | `com.android.art` | `art/dalvikvm/Android.bp` |
| `dex2oat`, `dex2oat32`, `dex2oat64` | `com.android.art` | `art/dex2oat/Android.bp` |
| `dexdump` | `com.android.art` | `art/dexdump/Android.bp` |
| `dexlist` | `com.android.art` | `art/dexlist/Android.bp` |
| `dexopt_chroot_setup` | `com.android.art` | `art/dexopt_chroot_setup/Android.bp` |
| `dexoptanalyzer` | `com.android.art` | `art/dexoptanalyzer/Android.bp` |
| `oatdump` | `com.android.art` | `art/oatdump/Android.bp` |
| `odrefresh` | `com.android.art` | `art/odrefresh/Android.bp` |
| `profman` | `com.android.art` | `art/profman/Android.bp` |
| `linkerconfig` | `com.android.runtime` | `system/linkerconfig/Android.bp` |
| `crash_dump32`, `crash_dump64` | `com.android.runtime` | `system/core/debuggerd/Android.bp` |
| `linker`, `linker64` | `com.android.runtime` | `bionic/linker/Android.bp` |
| `mediatranscoding` | `com.android.media` | `frameworks/av/media/module/service.mediatranscoding/Android.bp` |
| `mediaswcodec` | `com.android.media.swcodec` | `frameworks/av/services/mediacodec/Android.bp` |
| `clatd` | `com.android.tethering` | `packages/modules/Connectivity/clatd/Android.bp` |
| `ethtool` | `com.android.tethering` | `external/ethtool/Android.bp` |
| `netbpfload` | `com.android.tethering` | `packages/modules/Connectivity/bpf/loader/Android.bp` |
| `ot-daemon` | `com.android.tethering` | `external/ot-br-posix/Android.bp` |
| `boringssl_self_test32`, `boringssl_self_test64` | `com.android.conscrypt` | `external/boringssl/selftest/Android.bp` |
| `statsd` | `com.android.os.statsd` | `packages/modules/StatsD/statsd/Android.bp` |
| `derive_classpath`, `derive_sdk` | `com.android.sdkext` | `packages/modules/SdkExtensions/derive_classpath/Android.bp`, `derive_sdk/Android.bp` |
| `crosvm` (AVF) | `com.android.virt` | `external/crosvm/Android.bp` |
| `fd_server` (AVF) | `com.android.virt` | `packages/modules/Virtualization/android/fd_server/Android.bp` |
| `virtmgr`, `early_virtmgr` (AVF) | `com.android.virt` | `packages/modules/Virtualization/android/virtmgr/Android.bp` |
| `virtualizationservice` (AVF) | `com.android.virt` | `packages/modules/Virtualization/android/virtualizationservice/Android.bp` |
| `vm` (AVF) | `com.android.virt` | `packages/modules/Virtualization/android/vm/Android.bp` |
| `vfio_handler`, `vmnic` (feature flags) | `com.android.virt` | `packages/modules/Virtualization/android/virtualizationservice/` |

ART debug APEX additions: `dex2oatd`, `dexanalyze`, `dexoptanalyzerd`,
`imgdiag`, `imgdiagd`, `oatdumpd`, and `profmand`. Their definitions are under
`art/`; the package selection is in `art/build/apex/Android.bp`.

## Common userdebug/eng additions

| Installed command/module | Source/build definition |
|---|---|
| `adevice_fingerprint` | `tools/asuite/adevice/Android.bp` |
| `arping`, `tracepath`, `tracepath6`, `traceroute6` | `external/iputils/Android.bp` |
| `avbctl` | `external/avb/Android.bp` |
| `bootctl` | `system/extras/bootctl/Android.bp` |
| `dmuserd` | `system/core/fs_mgr/tools/Android.bp` |
| `evemu-record` | `frameworks/native/cmds/evemu-record/Android.bp` |
| `idlcli` | `frameworks/native/cmds/idlcli/Android.bp` |
| `iotop` | `system/extras/iotop/Android.bp` |
| `iperf3` | `external/iperf3/Android.bp` |
| `iw` | `external/iw/Android.bp` |
| `layertracegenerator` | `frameworks/native/services/surfaceflinger/Tracing/tools/Android.bp` |
| `logpersist.start` | `system/logging/logcat/Android.bp` |
| `ot-cli-ftd`, `ot-ctl` | `external/openthread/Android.bp` |
| `procrank`, `showmap` | `system/memory/libmeminfo/tools/Android.bp` |
| `profcollectd`, `profcollectctl` | `system/extras/profcollectd/Android.bp` |
| `record_binder` | `system/tools/aidl/Android.bp` |
| `sanitizer-status` | `tools/security/sanitizer-status/Android.bp` |
| `servicedispatcher` | `frameworks/native/libs/binder/Android.bp` |
| `sqlite3` | `external/sqlite/dist/Android.bp` |
| `ss` | `external/iproute2/misc/Android.bp` |
| `start_with_lockagent` | `frameworks/base/tools/lock_agent/Android.bp` |
| `strace` | `external/strace/Android.bp` |
| `su` | `system/extras/su/Android.bp` |
| `tinycap`, `tinyhostless`, `tinymix`, `tinypcminfo`, `tinyplay` | `external/tinyalsa/Android.bp` |
| `unwind_info`, `unwind_reg_info`, `unwind_symbols` | `system/unwinding/libunwindstack/Android.bp` |

## Goldfish/Ranchu emulator additions

Product selection starts at `device/generic/goldfish/product/generic.mk`.

| Installed command/module | Source/build definition |
|---|---|
| `qemu-props` | `device/generic/goldfish/qemu-props/Android.bp` |
| `android.hardware.graphics.composer3-service.ranchu` | `device/generic/goldfish-opengl/system/hwc3/Android.bp` |
| `android.hardware.media.c2@1.0-service-goldfish` | `device/generic/goldfish-opengl/system/codecs/c2/service/Android.bp` |
| `android.hardware.graphics.allocator-service.ranchu` | `device/generic/goldfish/gralloc/Android.bp` |
| `libgoldfish-rild` | `device/generic/goldfish/radio/rild/Android.bp` |
| `android.hardware.biometrics.fingerprint-service.ranchu` | `device/generic/goldfish/fingerprint/Android.bp` |
| `android.hardware.gnss-service.ranchu` | `device/generic/goldfish/gnss/Android.bp` |
| `android.hardware.camera.provider.ranchu` | `device/generic/goldfish/camera/Android.bp` |
| `mac80211_create_radios` | `device/generic/goldfish/wifi/mac80211_create_radios/Android.bp` |
| `dhcpclient` | `device/generic/goldfish/dhcp/client/Android.bp` |
| `bt_vhci_forwarder`, `dlkm_loader` | `device/google/cuttlefish/guest/commands/` |
| `init.ranchu.adb.setup.sh` | `device/generic/goldfish/init.ranchu.adb.setup.sh` |
| `init_ranchu_device_state.sh` | `device/generic/goldfish/init_ranchu_device_state.sh` |
| `init.ranchu-core.sh` | `device/generic/goldfish/init.ranchu-core.sh` |
| `init.ranchu-net.sh` | `device/generic/goldfish/init.ranchu-net.sh` |
| `curl` (tablet product) | `external/curl/Android.bp` |

Goldfish also selects many reference/example HAL services from
`hardware/interfaces/*/default/`. The most useful source roots are:

```text
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

## Cuttlefish emulator additions

Product selection starts under `device/google/cuttlefish/shared/` and the chosen
`device/google/cuttlefish/vsoc_*/` product.

| Installed command/module | Source/build definition |
|---|---|
| `checkpoint_gc` | `system/extras/checkpoint_gc/Android.bp` |
| `socket_vsock_proxy` | `device/google/cuttlefish/common/frontend/socket_vsock_proxy/Android.bp` |
| `tombstone_transmit`, `tombstone_producer` | `device/google/cuttlefish/guest/monitoring/tombstone_transmit/Android.bp` |
| `suspend_blocker` | `device/google/cuttlefish/guest/services/suspend_blocker/Android.bp` |
| `snapshot_hook_pre_suspend`, `snapshot_hook_post_resume` | `device/google/cuttlefish/guest/commands/snapshot_hook/Android.bp` |
| `dlkm_loader` | `device/google/cuttlefish/guest/commands/dlkm_loader/Android.bp` |
| `trusty_vm_launcher` (conditional) | `device/google/cuttlefish/guest/services/trusty_vm_launcher/Android.bp` |
| `cuttlefish_sensor_injection` | `device/google/cuttlefish/guest/commands/sensor_injection/Android.bp` |
| `rename_netiface` | `device/google/cuttlefish/guest/commands/rename_netiface/Android.bp` |
| `setup_wifi` | `device/google/cuttlefish/guest/commands/setup_wifi/Android.bp` |
| `init.wifi_apex` | `device/google/cuttlefish/guest/services/wifi/Android.bp` |
| `bt_vhci_forwarder` | `device/google/cuttlefish/guest/commands/bt_vhci_forwarder/Android.bp` |
| `libcuttlefish-rild` | `device/google/cuttlefish/guest/hals/rild/Android.bp` |
| `android.hardware.camera.provider@2.7-external-vsock-service` | `device/google/cuttlefish/guest/hals/camera/Android.bp` |
| `android.hardware.confirmationui-service.cuttlefish` | `device/google/cuttlefish/guest/hals/confirmationui/Android.bp` |
| `android.hardware.health-service.cuttlefish` | `device/google/cuttlefish/guest/hals/health/Android.bp` |
| `android.hardware.health.storage-service.cuttlefish` | `device/google/cuttlefish/guest/hals/health/storage/Android.bp` |
| `android.hardware.light-service.cuttlefish` | `device/google/cuttlefish/guest/hals/light/Android.bp` |
| `android.hardware.identity-service.remote` | `device/google/cuttlefish/guest/hals/identity/Android.bp` |
| `android.hardware.nfc-service.cuttlefish` | `device/google/cuttlefish/guest/hals/nfc/Android.bp` |
| `android.hardware.oemlock-service.remote` | `device/google/cuttlefish/guest/hals/oemlock/remote/Android.bp` |
| `android.hardware.gatekeeper-service.remote` | `device/google/cuttlefish/guest/hals/gatekeeper/remote/Android.bp` |
| `android.hardware.security.keymint-service.rust` | `device/google/cuttlefish/guest/hals/keymint/rust/Android.bp` |

Cuttlefish APEX payload lists are under `device/google/cuttlefish/apex/`, notably
`com.google.cf.bt`, `com.google.cf.wifi`, `com.google.cf.wpa_supplicant`,
`com.google.cf.rild`, `com.google.cf.identity`, and `com.google.cf.nfc`.

TV additions are defined in:

```text
hardware/interfaces/tv/hdmi/connection/aidl/default/
hardware/interfaces/tv/hdmi/cec/aidl/default/
hardware/interfaces/tv/hdmi/earc/aidl/default/
hardware/interfaces/tv/tuner/aidl/default/
hardware/interfaces/tv/input/aidl/default/
```

Automotive additions are selected by
`device/google/cuttlefish/shared/auto/device_vendor.mk`; implementations are under
`hardware/interfaces/automotive/`, `hardware/interfaces/broadcastradio/`,
`hardware/interfaces/macsec/`, and
`device/google/cuttlefish/guest/hals/vehicle/`.

## Google Tensor/Pixel family additions

The open device trees share executable sources under `device/google/gs-common/`.
Private vendor package fragments are absent from this checkout, so this section
is the open-source lower bound rather than a complete retail Pixel image.

| Installed command/module group | Source/build definition |
|---|---|
| `gs_watchdogd` | `device/google/gs-common/gs_watchdogd/Android.bp` |
| `sscoredump` | `device/google/gs-common/ramdump_and_coredump/Android.bp` |
| `dump_soc` | `device/google/gs-common/soc/Android.bp` |
| `dump_devfreq`, `dump_perf` | `device/google/gs-common/performance/Android.bp` |
| `dump_camera` | `device/google/gs-common/camera/Android.bp` |
| `dump_display`, display dump helpers | `device/google/gs-common/display/Android.bp` |
| `dump_gxp` | `device/google/gs-common/gxp/Android.bp` |
| `dump_storage` | `device/google/gs-common/storage/Android.bp` |
| `dump_modemlog` | `device/google/gs-common/modem/dump_modemlog/Android.bp` |
| `android.hardware.boot-service.default-pixel` | `device/google/gs-common/bootctrl/aidl/Android.bp` |
| `insmod.sh` | `device/google/gs-common/insmod/Android.bp` |
| `gpu_probe` | `hardware/google/pixel/gpu_probe/Android.bp` |
| `misc_writer` | `hardware/google/pixel/misc_writer/Android.bp` |
| `android.hardware.contexthub-service.generic` | `system/chre/host/hal_generic/Android.bp` |
| `android.hardware.sensors-service.multihal` | `hardware/interfaces/sensors/aidl/multihal/Android.bp` |

Per-generation product and executable selections:

| Family | Product/device definitions |
|---|---|
| GS101: raviole, bluejay | `device/google/gs101/device.mk`, `device/google/raviole/`, `device/google/bluejay/` |
| GS201: pantah, lynx, felix, tangorpro | `device/google/gs201/device.mk`, corresponding `device/google/<family>/` directories |
| Zuma: shusky, akita | `device/google/zuma/device.mk`, `device/google/shusky/`, `device/google/akita/` |
| Zuma Pro: caimito, comet | `device/google/zumapro/device.mk`, `device/google/caimito/`, `device/google/comet/` |

Common Pixel debug tools are selected in `device/google/gs-common/**/*.mk` and
the generation-specific `device.mk` files. Important source locations include:

```text
device/google/gs-common/ramdump_and_coredump/
device/google/gs-common/aoc/
device/google/gs-common/storage/
device/google/gs-common/dauntless/
system/chre/
system/core/trusty/utils/trusty-ut-ctrl/
system/core/trusty/libtrusty/tipc-test/
external/sg3_utils/
```

Unresolved proprietary additions are inherited from absent trees such as:

```text
vendor/google_devices/
vendor/google/whitechapel/
vendor/google_nos/
vendor/samsung_slsi/telephony/
vendor/broadcom/gps/
vendor/goodix/udfps/
vendor/qorvo/uwb/
```

## Linaro device additions

### Dragonboard

| Installed command/module | Source/build definition |
|---|---|
| `pd-mapper` | `device/linaro/dragonboard/shared/utils/pd-mapper/Android.bp` |
| `qrtr-ns`, `qrtr-cfg`, `qrtr-lookup` | `device/linaro/dragonboard/shared/utils/qrtr/Android.bp` |
| `rmtfs` | `device/linaro/dragonboard/shared/utils/rmtfs/Android.bp` |
| `tqftpserv` | `device/linaro/dragonboard/shared/utils/tqftpserv/Android.bp` |
| `bdaddr` | `device/linaro/dragonboard/shared/utils/bdaddr/Android.bp` |
| `dlkm_loader` | `device/google/cuttlefish/guest/commands/dlkm_loader/Android.bp` |
| `suspend_blocker` | `device/google/cuttlefish/guest/services/suspend_blocker/Android.bp` |
| `set_bdaddr.sh`, `set_hw.sh`, `set_udc.sh`, `set_ethaddr.sh` | `device/linaro/dragonboard/` |

Product selections are in `device/linaro/dragonboard/full.mk` and each board's
`device.mk`. Additional proprietary modules under `vendor/linaro/` are not present.

### HiKey/HiKey960

| Installed command/module | Source/build definition |
|---|---|
| `ssh`, `sftp`, `scp`, `sshd`, `ssh-keygen`, `start-ssh` | requested by `device/linaro/hikey/device-common.mk`; module definitions/sources are absent from this checkout |
| `stm32_flash` | `device/google/contexthub/util/stm32_flash/Android.bp` |
| `nanoapp_cmd` | `device/google/contexthub/util/nanoapp_cmd/Android.bp` |
| `nanotool` | `device/google/contexthub/util/nanotool/Android.bp` |
| `android.hardware.power@1.1-service.hikey-common` | `device/linaro/hikey/power/Android.mk` |
| `bcc` (conditional prebuilt) | selected by `device/linaro/hikey/hikey960/device-hikey960.mk` |

### Poplar

| Installed command/module | Source/build definition |
|---|---|
| `hiavplayer` (prebuilt) | `device/linaro/poplar/proprietary/hisilicon/Android.bp` |
| `tee-supplicant`, `xtest` (OP-TEE) | selected by `device/linaro/poplar/optee/optee-packages.mk`; sources under `external/optee_client/`, `external/optee_test/` |
| `optee_example_helloworld`, `optee_example_random`, other OP-TEE examples | selected by `device/linaro/poplar/optee/optee-packages.mk`; sources under `external/optee_examples/` |

## Reading rules

1. Search an installed name in this file first.
2. Open the referenced `Android.bp` or `Android.mk` and inspect `srcs`, `stem`,
   `symlinks`, `relative_install_path`, partition flags and `apex_available`.
3. Follow the product selection from `PRODUCT_PACKAGES` to determine whether a
   specific target includes it.
4. For an exact flashed-device list, compare this index with
   `adb shell 'find /system/bin /system_ext/bin /product/bin /vendor/bin /odm/bin /apex/*/bin -type f -o -type l'`.
