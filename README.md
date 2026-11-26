# Actions-fanchmwrt-bt-r320

面向 **Globitel BT-R320**（MediaTek MT7981B / 1GB DDR4 / 128GB eMMC / MT7531AE）的 **FanchmWrt（`fanchmwrt-25.12.6`）** 轻量级云编译与本地构建仓库。

> ✅ **分区与 U-Boot 兼容模式**：本仓库通过补丁将 `globitel_bt-r320` 切换为传统 eMMC `kernel`（`p4`）+ `rootfs`（`p5`）方案（产物为 `*-squashfs-sysupgrade.bin`），**完整沿用设备现有 GPT 分区表与已刷入的 WebUI U-Boot**，同时保留 `p6 (userdata)` 与 `p7 (primary)` 数据分区。

## 1. 仓库目录结构

```text
Actions-fanchmwrt-bt-r320/
├── .github/
│   ├── scripts/
│   │   └── prepare_fanchmwrt.sh                     # 应用补丁、files 覆盖与 diffconfig 注入脚本
│   └── workflows/
│       └── build-bt-r320.yml                        # GitHub Actions 云编译工作流
├── configs/
│   └── bt-r320.diffconfig                           # BT-R320 精简配置文件（USB/Samba4/Docker/中文）
├── files/
│   └── .gitkeep                                     # 自定义文件覆盖目录（对应 OpenWrt files/）
├── patches/
│   ├── 001-mediatek-bt-r320-legacy-emmc-layout.patch # 切回传统 kernel+rootfs eMMC 布局，保留现网 U-Boot
│   └── 002-mediatek-bt-r320-add-status-leds.patch   # 补全 GPIO 10/11/12 红绿蓝三色系统状态灯
└── README.md
```

## 2. 技术特性说明

- **上游源码**：`fanchmwrt/fanchmwrt`（默认分支 `fanchmwrt-25.12.6`，Linux 6.12 内核）
- **保留现有分区与 U-Boot**：`001-mediatek-bt-r320-legacy-emmc-layout.patch` 将根挂载改为 `PARTLABEL=rootfs`、镜像格式改为 `sysupgrade-tar`（`sysupgrade.bin`）、升级脚本改为 `CI_KERNPART="kernel"` / `CI_ROOTPART="rootfs"` / `emmc_do_upgrade`，不生成也不刷写 `gpt.bin` 与 `fip`。
- **硬件驱动与状态灯**：开源 `mt76` 无线驱动（`kmod-mt7915e`）、GPIO 14 USB VBUS 供电、MT7531 交换机、`factory` 规范 MAC 提取，以及 `002` 补丁补齐的 GPIO 10/11/12 三色状态灯。
- **预装扩展功能**（`configs/bt-r320.diffconfig`）：
  - USB 3.0 与文件系统支持（`usbutils`、`lsblk`、`fdisk`、`blkid`、`kmod-usb-storage-uas`、`exfat`、`ntfs3`、`f2fs`、`luci-app-hd-idle`）
  - `luci-app-samba4`（Samba4 文件共享）
  - `docker` + `dockerd` + `docker-compose` + `luci-app-dockerman`（含 `DOCKER_CGROUP_OPTIONS`、`DOCKER_NET_MACVLAN`、`DOCKER_STO_EXT4`、`iptables-nft`）
  - `luci-app-ttyd` 及全套简体中文语言包

## 3. 云编译（GitHub Actions）

1. 打开仓库的 **Actions -> Build FanchmWrt for Globitel BT-R320 -> Run workflow**。
2. 可选参数：
   - `fanchmwrt_branch`：默认 `fanchmwrt-25.12.6`
   - `apply_led_patch`：是否应用 GPIO 10/11/12 状态灯补丁（默认 `true`）
   - `upload_release`：是否发布到 GitHub Release（默认 `true`）
3. 编译完成后下载 `*-squashfs-sysupgrade.bin`（及应急用的 `*-initramfs-recovery.itb`、`sha256sums.txt`）。

## 4. 刷机简要说明

1. **备份关键分区**：SSH 登录现有 237 固件备份 `factory`（`p2`）、`fip`（`p3`）、`u-boot-env`（`p1`）到本地留底。
2. **刷入新固件**：进入设备现有的 **WebUI U-Boot** 刷机页面，直接上传 `*-squashfs-sysupgrade.bin` 刷入即可（无需修改 U-Boot 或 GPT 分区表，`userdata`/`primary` 分区数据保留）。
3. 详细备份、核验与回滚步骤见外层目录 `docs/03_刷机备份与救砖回滚指南.md`。
