# CV180ZB Spinor A/B OTA 使用说明

本文档适用于 `cv180zb_wevb_0008a_spinor` 的 16MB spinor 系统级 OTA 方案。

## 1. 方案说明

当前实现采用 BOOT/ROOTFS A/B 双分区：

| 分区 | 大小 | 说明 |
| --- | ---: | --- |
| BOOT | 3072KB | A 槽 boot.itb |
| BOOT_BAK | 3072KB | B 槽 boot.itb |
| ROOTFS | 2304KB | A 槽 rootfs.squashfs |
| ROOTFS_BAK | 2304KB | B 槽 rootfs.squashfs |
| DATA | 1664KB | 共享数据区，当前放置 `video_sei_enc` 和运行库 |
| ENV/ENV_BAK | 64KB + 64KB | U-Boot 环境变量，保存 OTA 状态 |
| OTA_META/PARAM/PARAM_BAK/MISC | 各 64KB | 预留/参数分区 |

FSBL 启动时先读取 `OTA_META` 分区选择槽位，U-Boot 启动后继续读取以下环境变量选择 BOOT/ROOTFS：

| 变量 | 含义 |
| --- | --- |
| `ota_active` | 当前确认可用的槽位，`A` 或 `B` |
| `ota_pending` | 待验证槽位，`A`、`B` 或 `none` |
| `ota_try` | 待验证槽位剩余启动次数 |
| `ota_version_active` | 当前确认版本号 |
| `ota_version_pending` | 待验证版本号 |

升级流程为：板端脚本写入非活动槽位，同时更新 U-Boot ENV 和 `OTA_META`，设置 `ota_pending` 和 `ota_try`，重启进入新槽位；系统启动成功后由 `/etc/init.d/S98ota_mark_good` 调用 `ota_mark_good.sh` 自动确认新槽位，并把 `OTA_META` 改为 `pending=none`。如果新系统无法启动或未确认，U-Boot 会在尝试次数用完后回退到 `ota_active` 槽位。

## 2. 首次部署要求

旧分区表没有 A/B 分区，不能直接在旧系统上无损切换到本方案。第一次使用需要整机烧录一次新镜像，并确保 U-Boot ENV 使用新默认值。

建议首次烧录后清空或重置 ENV，避免旧环境变量覆盖新的 `bootcmd`/`ota_*` 默认值。板端可用命令视产品调试方式选择：

```sh
fw_setenv ota_active A
fw_setenv ota_pending none
fw_setenv ota_try 0
/usr/sbin/ota_meta.sh write A none 0 initial
```

如 ENV 中保留了旧 `bootcmd`，需要在 U-Boot 控制台执行 `env default -a; saveenv` 后重启。

## 3. 镜像瘦身约束

当前分区尺寸要求如下，构建产物必须不超过限制：

| 镜像 | 最大大小 |
| --- | ---: |
| `boot.spinor` | 3072KB |
| `rootfs.spinor` | 2304KB |
| `data.spinor` | 1664KB |

已做的瘦身策略：

- BOOT 使用 LZMA 压缩内核，并在 `CONFIG_SKIP_RAMDISK=y` 时从 FIT 中移除 ramdisk 节点。
- ROOTFS 使用 squashfs xz 压缩。
- ROOTFS 删除调试/网络/WiFi/无关 USB gadget/可选运行库。
- DATA 只保留 `video_sei_enc`、启动脚本、UVC 配置和应用依赖库。
- `video_sei_enc` 和 DATA 运行库会再次 strip。

本次验证尺寸：

```text
boot.spinor raw    2917576 bytes
rootfs.spinor raw  1957888 bytes
data.spinor raw    <= 1703936 bytes
```

## 固件版本号

固件版本号统一放在工程目录的板级配置文件：

```text
build/boards/cv180x/cv180zb_wevb_0008a_spinor/firmware_version.conf
```

配置内容：

```text
FW_VERSION=1.0.0
FW_BOARD=cv180zb_wevb_0008a_spinor
FW_PRODUCT=v420
```

构建 rootfs 时会自动生成板端文件 `/etc/firmware_version`。

板端查看：

```sh
fw_version
cat /etc/firmware_version
```

发布新固件前，只修改 `firmware_version.conf` 中的 `FW_VERSION`。OTA 包 manifest 和固件内置 `FW_VERSION` 都从这个文件获取；OTA 启动确认时会优先使用该版本写入 `ota_version_active` 和 `OTA_META`。

## 4. 构建

确认 defconfig 中包含关键配置：

```text
CONFIG_DOUBLESDK=y
CONFIG_KERNEL_LZMA=y
CONFIG_KERNEL_COMPRESS="lzma"
CONFIG_TARGET_PACKAGE_MTD-UTILS=y
CONFIG_TARGET_PACKAGE_ENVTOOLS=y
# CONFIG_ROOTFS_FORMAT_OPTIMIZATION is not set
# CONFIG_TARGET_PACKAGE_WIFI is not set
```

按项目原有方式构建完整镜像，例如：

```sh
source build/envsetup_soc.sh
defconfig cv180zb_wevb_0008a_spinor
build_all
```

构建完成后检查：

```sh
ls -l install/soc_cv180zb_wevb_0008a_spinor/rawimages/boot.spinor       install/soc_cv180zb_wevb_0008a_spinor/rawimages/rootfs.spinor       install/soc_cv180zb_wevb_0008a_spinor/rawimages/data.spinor
```

如果 `raw2cimg.py` 报 `larger than partition size`，需要继续瘦身对应镜像或重新调整分区大小。

## 5. 制作 OTA 包

`build_all` 完成后会自动生成 spinor A/B OTA 包，版本号来自 `firmware_version.conf`：

```text
/home/user/wk/v420/tmp/ota-<FW_VERSION>/
  manifest.env
  boot.spinor
  rootfs.spinor
  upgrade.ready
```

例如 `FW_VERSION=1.0.1` 时，输出目录为：

```text
/home/user/wk/v420/tmp/ota-1.0.1/
```

OTA 包包含非活动槽位需要写入的系统镜像：`boot.spinor`、`rootfs.spinor`、`manifest.env`。自动 SD 卡 OTA 还会检查 `upgrade.ready`，只有存在该文件才会触发自动升级。

如需单独重新生成 OTA 包，也可以手动执行，脚本会从 `firmware_version.conf` 读取版本号：

```sh
build/tools/common/ota_tool/make_spinor_ab_ota.sh   tmp/ota-1.0.1   cv180zb_wevb_0008a_spinor   install/soc_cv180zb_wevb_0008a_spinor/rawimages/boot.spinor   install/soc_cv180zb_wevb_0008a_spinor/rawimages/rootfs.spinor
```

建议把 OTA 包放在 SD 卡、U 盘、NFS 或上位机传输目录中，不建议放到 `/mnt/data`，因为 DATA 分区空间有限。

## 6. 板端升级

将 OTA 包放到板端可访问路径后，可以手动执行：

```sh
/usr/sbin/ota_update.sh /mnt/sd/ota-1.0.1
reboot
```

如果放到 SD 卡根目录下的 `ota/` 或 `ota-*` 目录，并保留 `upgrade.ready`，系统会在 SD 卡挂载后自动执行 OTA，成功写入后自动重启：

```text
/mnt/sd/ota/
  manifest.env
  boot.spinor
  rootfs.spinor
  upgrade.ready
```

`ota_update.sh` 会自动判断当前活动槽位，写入另一个槽位，并同步写入 `OTA_META`：

| 当前 `ota_active` | 写入目标 |
| --- | --- |
| `A` | `BOOT_BAK` + `ROOTFS_BAK` |
| `B` | `BOOT` + `ROOTFS` |

脚本依赖：

```text
fw_printenv
fw_setenv
flashcp
sha256sum
```

这些工具已通过 `MTD-UTILS` 和 `ENVTOOLS` 配置进入 rootfs。

## 7. 升级确认

重启后检查当前槽位：

```sh
cat /proc/cmdline | grep cvi_ota_slot
fw_printenv ota_active ota_pending ota_try ota_version_active ota_version_pending
```

正常情况下，系统启动脚本会自动确认成功，最终状态应类似：

```text
ota_active=B
ota_pending=none
ota_try=0
ota_version_active=1.0.1
```

如果需要手动确认当前槽位：

```sh
/usr/sbin/ota_mark_good.sh
```

## 8. 回滚

自动回滚：新槽位启动失败或未确认时，`ota_try` 用完后 U-Boot 会回到 `ota_active` 槽位。

手动切到另一个槽位试启动：

```sh
fw_setenv ota_pending A   # 或 B
fw_setenv ota_try 1
/usr/sbin/ota_meta.sh write B A 1 manual   # 当前 active 为 B 时手动试 A；反向同理
reboot
```

强制固定到 A 槽：

```sh
fw_setenv ota_active A
fw_setenv ota_pending none
fw_setenv ota_try 0
/usr/sbin/ota_meta.sh write A none 0 manual
reboot
```

强制固定到 B 槽：

```sh
fw_setenv ota_active B
fw_setenv ota_pending none
fw_setenv ota_try 0
/usr/sbin/ota_meta.sh write B none 0 manual
reboot
```

## 9. 注意事项

- DATA 当前是共享分区，不参与 A/B 回滚。系统 OTA 默认只更新 BOOT 和 ROOTFS。
- 当前 DATA 放置 `video_sei_enc` 和依赖库，如果后续要求应用也随系统 A/B 回滚，需要把应用移入 ROOTFS，或增加独立的应用 A/B 机制。
- 修改分区大小后必须同步更新 `partition_spinor.xml`、`partition_doublesdk_spinor.xml`，并重新生成 `/etc/fw_env.config`。如果 `OTA_META` 位置变化，还要同步 FSBL 中的 `OTA_META_PART_LOADADDR`。
- 每次量产前建议做一次断电测试：写入 OTA 包后，在首次新槽位启动前/启动中断电，确认设备最终能回退或继续启动。
