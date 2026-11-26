# Actions-fanchmwrt-bt-r320

面向 **Globitel BT-R320**（MediaTek MT7981B / 1GB DDR4 / 128GB eMMC / MT7531AE）的 **FanchmWrt（`fanchmwrt-25.12.6`）** 轻量级云编译与本地构建仓库。

> ✅ **沿用现有分区与 WebUI U-Boot**：本仓库通过补丁将 `globitel_bt-r320` 切换为传统 eMMC `kernel`（`p4`）+ `rootfs`（`p5`）模式（产物为 `*-squashfs-sysupgrade.bin`），**无需修改您已刷入的 WebUI U-Boot，也不改变现有 GPT 分区表**，完整保留 `factory` 与 `userdata` / `primary` 数据分区。

---

## 1. 仓库目录结构

```text
Actions-fanchmwrt-bt-r320/
├── .github/
│   ├── scripts/
│   │   └── prepare_fanchmwrt.sh                      # 应用补丁、files 覆盖与 diffconfig 注入脚本
│   └── workflows/
│       └── build-bt-r320.yml                         # GitHub Actions 云编译工作流
├── configs/
│   └── bt-r320.diffconfig                            # BT-R320 精简配置文件（USB/Samba4/Docker/中文）
├── files/
│   └── .gitkeep                                      # 自定义文件覆盖目录（对应 OpenWrt files/）
├── patches/
│   ├── 001-mediatek-bt-r320-legacy-emmc-layout.patch # 切回传统 kernel+rootfs 布局，保留现网 U-Boot
│   └── 002-mediatek-bt-r320-add-status-leds.patch    # 补全 GPIO 10/11/12 红绿蓝三色系统状态灯
├── .gitattributes                                    # 强制 .sh/.patch/.yml/.diffconfig 使用 LF 换行
├── .gitignore
└── README.md
```

---

## 2. 技术特性与硬件适配

- **上游源码**：`fanchmwrt/fanchmwrt`（默认分支 `fanchmwrt-25.12.6`，Linux 6.12 内核）
- **分区与引导兼容性**（`001-mediatek-bt-r320-legacy-emmc-layout.patch`）：
  - `chosen` 使用 `bootargs-override = "root=PARTLABEL=rootfs rootwait";`
  - 镜像格式改为 `sysupgrade-tar`（`*-squashfs-sysupgrade.bin`，包含 `SUPPORTED_DEVICES += bt,r320-emmc`）
  - `platform.sh` 升级路径改为 `CI_KERNPART="kernel"` / `CI_ROOTPART="rootfs"` / `emmc_do_upgrade`
  - 保留 `p1 (u-boot-env)`、`p2 (factory)`、`p3 (fip / WebUI U-Boot)` 与额外数据分区（如 `userdata`、`primary`）不被覆盖
- **硬件驱动与状态灯**：
  - 无线采用开源 `mt76` 驱动（`kmod-mt7915e`、`kmod-mt7981-firmware`、`mt7981-wo-firmware`），从 `factory` 分区自动提取校准与 MAC
  - USB 3.0 已启用 GPIO 14 VBUS 5V 供电控制
  - `002-mediatek-bt-r320-add-status-leds.patch` 补齐 GPIO 10（红）、GPIO 11（绿）、GPIO 12（蓝）状态灯及 `led-boot` / `led-failsafe` / `led-running` / `led-upgrade` 别名
- **预装功能（`configs/bt-r320.diffconfig`）**：
  - **FanchmWrt 原生特性**：`shortcut-fe` 快速转发、`fwx` / `fwxd` 应用过滤与防火墙套件
  - **USB 与多文件系统**：`usbutils`、`lsblk`、`fdisk`、`blkid`、`kmod-usb-storage-uas`、`kmod-fs-exfat`、`kmod-fs-ntfs3`、`kmod-fs-f2fs`、`luci-app-hd-idle`
  - **文件共享**：`luci-app-samba4`
  - **Docker 容器**：`docker`、`dockerd`、`docker-compose`、`luci-app-dockerman`、`kmod-br-netfilter`、`kmod-veth`、`iptables-nft`、`ip6tables-nft`、`DOCKER_CGROUP_OPTIONS`、`DOCKER_NET_MACVLAN`、`DOCKER_STO_EXT4`
  - **管理与本地化**：`luci-app-ttyd` 及全套 `-zh-cn` 中文语言包

---

## 3. 云编译（GitHub Actions）

1. 打开仓库页面的 **Actions -> Build FanchmWrt for Globitel BT-R320 -> Run workflow**。
2. 可选输入参数：
   - `fanchmwrt_branch`：上游分支名（默认 `fanchmwrt-25.12.6`）
   - `apply_led_patch`：是否应用 GPIO 10/11/12 状态灯补丁（默认 `true`）
   - `upload_release`：是否自动发布到 GitHub Release（默认 `true`）
3. 编译完成后，从 Workflow Artifacts 或 Release 下载 `*-globitel_bt-r320-squashfs-sysupgrade.bin`（及应急恢复镜像 `*-initramfs-recovery.itb`、`sha256sums.txt`）。

---

## 4. 本地编译（Ubuntu 22.04）

```bash
# 1. 拉取本构建仓与 FanchmWrt 上游源码
git clone https://github.com/EasongChung/Actions-fanchmwrt-bt-r320.git
cd Actions-fanchmwrt-bt-r320
git clone --depth=1 -b fanchmwrt-25.12.6 https://github.com/fanchmwrt/fanchmwrt.git fanchmwrt-src

# 2. 更新并安装 Feeds
cd fanchmwrt-src
./scripts/feeds update -a && ./scripts/feeds install -a
cd ..

# 3. 应用补丁与配置（如需跳过 002 状态灯补丁，可在末尾追加 --no-led-patch）
chmod +x .github/scripts/prepare_fanchmwrt.sh
./.github/scripts/prepare_fanchmwrt.sh ./fanchmwrt-src ./configs/bt-r320.diffconfig

# 4. 展开配置、下载源码并编译
cd fanchmwrt-src
make defconfig
make download -j8
make -j"$(nproc)" || make -j1 V=s
```

编译产物位于 `fanchmwrt-src/bin/targets/mediatek/filogic/`。

---

## 5. 刷机与安全注意事项

| 分区 | `PARTLABEL` | 典型用途 | 刷机影响 |
| :--- | :--- | :--- | :--- |
| `p1` | `u-boot-env` | U-Boot 环境变量 | 保留不变 |
| `p2` | `factory` | 无线校准与 MAC | 保留不变（仍建议刷前备份） |
| `p3` | `fip` | WebUI U-Boot | 保留不变 |
| `p4` | `kernel` | 内核与设备树 | 更新为 FanchmWrt Linux 6.12 |
| `p5` | `rootfs` | 根文件系统与 Overlay | 更新为 FanchmWrt SquashFS + Overlay |
| `p6+` | `userdata` / `primary` 等 | 用户扩展数据区 | 保留不被擦除 |

1. **刷前备份**：首次切换系统前，强烈建议通过 SSH 使用 `dd` 备份 `factory`、`fip`、`u-boot-env` 与 `mmcblk0boot0` 到本地电脑留底。
2. **刷入方式（推荐 WebUI U-Boot）**：
   - 进入设备现有的 WebUI U-Boot 刷机界面，直接上传 `*-globitel_bt-r320-squashfs-sysupgrade.bin` 刷入即可。
   - 若从 237 闭源固件系统内通过 SSH 升级，**务必使用 `sysupgrade -n`**（切勿保留 237 闭源无线/防火墙旧配置）。
3. **刷后数据区与 Docker**：刷入后可在 LuCI **系统 -> 挂载点** 重新挂载原有的 `userdata` / `primary` 分区，并建议将 Docker `data-root` 指向大容量数据分区（而非占用 `p5` Overlay）。
4. **回滚**：因原 WebUI U-Boot 与分区表未被修改，如需退回原固件，重新进入 WebUI U-Boot 刷入原版 `sysupgrade.bin` 即可。
