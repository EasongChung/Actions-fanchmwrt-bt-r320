# Actions-fanchmwrt-bt-r320

面向 **Globitel BT-R320**（MediaTek MT7981B / 1GB DDR4 / 128GB eMMC / MT7531AE）的 **FanchmWrt（`fanchmwrt-25.12.6`）** 轻量级云编译与本地构建仓库。

## 1. 仓库目录结构

```text
Actions-fanchmwrt-bt-r320/
├── .github/
│   ├── scripts/
│   │   └── prepare_fanchmwrt.sh                   # 应用补丁、files 覆盖与 diffconfig 注入脚本
│   └── workflows/
│       └── build-bt-r320.yml                      # GitHub Actions 云编译工作流
├── configs/
│   └── bt-r320.diffconfig                         # BT-R320 精简配置文件（USB/Samba4/Docker/中文）
├── files/
│   └── .gitkeep                                   # 自定义文件覆盖目录（对应 OpenWrt files/）
├── patches/
│   └── 001-mediatek-bt-r320-add-status-leds.patch # 补全 GPIO 10/11/12 红绿蓝三色系统状态灯
└── README.md
```

## 2. 技术特性说明

- **上游源码**：`fanchmwrt/fanchmwrt`（默认分支 `fanchmwrt-25.12.6`，Linux 6.12 内核）
- **原生板级支持**：`globitel_bt-r320`（开源 `mt76` 无线驱动 `kmod-mt7915e`、GPIO 14 USB VBUS 供电、MT7531 千兆交换机、eMMC GPT + FIT 引导）
- **FanchmWrt 特性**：内置 `shortcut-fe` 快速转发、`fwx` / `fwxd` 应用过滤与防火墙管理界面
- **状态灯补丁**：`patches/001-mediatek-bt-r320-add-status-leds.patch` 为原 DTS 补齐 GPIO 10（红）、GPIO 11（绿）、GPIO 12（蓝）状态灯及 `led-boot` / `led-failsafe` / `led-running` / `led-upgrade` 别名
- **预装扩展功能**（`configs/bt-r320.diffconfig`）：
  - USB 3.0 存储支持（`usbutils`、`lsblk`、`fdisk`、`blkid`、`kmod-usb-storage-uas`、`exfat`、`ntfs3`、`luci-app-hd-idle`）
  - `luci-app-samba4`（Samba4 文件共享）
  - `docker` + `dockerd` + `docker-compose` + `luci-app-dockerman`
  - `luci-app-ttyd` 及全套简体中文语言包

## 3. 云编译（GitHub Actions）

1. 将本仓库推送至 GitHub（`EasongChung/Actions-fanchmwrt-bt-r320`）。
2. 打开仓库的 **Actions -> Build FanchmWrt for Globitel BT-R320 -> Run workflow**。
3. 可选参数：
   - `fanchmwrt_branch`：默认 `fanchmwrt-25.12.6`
   - `apply_led_patch`：是否应用 GPIO 10/11/12 状态灯补丁（默认 `true`）
   - `upload_release`：是否发布到 GitHub Release（默认 `true`）
4. 编译完成后下载产物（含 `gpt.bin`、`preloader.bin`、`bl31-uboot.fip`、`initramfs-recovery.itb`、`squashfs-sysupgrade.itb`、`sha256sums.txt`）。

## 4. 本地编译（Ubuntu 22.04）

```bash
git clone --depth=1 -b fanchmwrt-25.12.6 https://github.com/fanchmwrt/fanchmwrt.git fanchmwrt-src
cd fanchmwrt-src
./scripts/feeds update -a && ./scripts/feeds install -a
cd ..
./.github/scripts/prepare_fanchmwrt.sh ./fanchmwrt-src ./configs/bt-r320.diffconfig
cd fanchmwrt-src
make defconfig
make download -j8
make -j"$(nproc)"
```

## 5. 刷机与安全警告（从 237 / 原厂固件迁移必读）

> ⚠️ **严禁在 237 固件或原厂旧分区表下直接 Web 强刷 `squashfs-sysupgrade.itb`！**
> 237 固件采用传统 eMMC `kernel + rootfs` 双分区布局（`sysupgrade.bin`），而 `fanchmwrt-25.12.6` 采用 OpenWrt 现代 **GPT + FIT (`fitblk`)** 布局（`production` 分区 + `/dev/fit0`）。直接强刷会导致无法引导。

1. **完整备份**：通过 SSH 登录当前 237 固件，使用 `dd` 完整备份 `factory`（无线校准与 MAC 所在关键分区）、`bl2`、`fip`、`ubootenv`（或全部前段分区）并导出到电脑。
2. **更新 GPT 与 U-Boot**：核对设备确认为 Globitel BT-R320（1GB DDR4 / eMMC）且备份已校验后，刷入本次编译生成的 `*-emmc-gpt.bin` 与 `*-emmc-bl31-uboot.fip`。
3. **通过 OpenWrt U-Boot 恢复界面刷机**：断电，电脑设静态 IP `192.168.1.2`，按住 Reset 键上电约 10 秒进入 U-Boot Web 页面，先刷入 `initramfs-recovery.itb` 或直接在恢复界面刷入 `squashfs-sysupgrade.itb`。
4. **后续升级**：完成上述架构切换后，后续升级 FanchmWrt 同架构版本可直接上传 `*-squashfs-sysupgrade.itb`。
