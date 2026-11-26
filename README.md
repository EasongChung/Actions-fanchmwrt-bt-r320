# Actions-fanchmwrt-bt-r320

Globitel BT-R320（MediaTek MT7981B / 1GB DDR4 / eMMC / MT7531AE）的 FanchmWrt（`fanchmwrt-25.12.6`）固件构建仓库。

本仓库采用外挂补丁与增量配置方式构建固件，构建目标保持设备既有 eMMC GPT 分区表及现有 U-Boot 不变，生成标准 `sysupgrade-tar` 格式镜像（`*-squashfs-sysupgrade.bin`）。

## 1. 仓库结构

```text
Actions-fanchmwrt-bt-r320/
├── .github/
│   ├── scripts/
│   │   └── prepare_fanchmwrt.sh                      # 补丁校验/应用、文件覆盖与配置注入脚本
│   └── workflows/
│       └── build-bt-r320.yml                         # GitHub Actions 云构建工作流
├── configs/
│   └── bt-r320.diffconfig                            # BT-R320 增量配置文件
├── files/
│   └── .gitkeep                                      # 自定义文件覆盖目录（对应源码 files/）
├── patches/
│   ├── 001-mediatek-bt-r320-legacy-emmc-layout.patch # 适配传统 kernel + rootfs 分区布局
│   └── 002-mediatek-bt-r320-add-status-leds.patch    # 补全 GPIO 10/11/12 红绿蓝状态灯
├── .gitattributes
├── .gitignore
└── README.md
```

## 2. 技术说明

- **基础源码**：`fanchmwrt/fanchmwrt`（默认分支 `fanchmwrt-25.12.6`，Linux 6.12 内核）。
- **分区与引导适配**（`patches/001-mediatek-bt-r320-legacy-emmc-layout.patch`）：
  - 设备树 `chosen` 节点设置 `bootargs-override = "root=PARTLABEL=rootfs rootwait";`，移除 `production` FIT 节点依赖。
  - 构建产物切换为 `sysupgrade-tar`（`*-squashfs-sysupgrade.bin`），并补充 `SUPPORTED_DEVICES += bt,r320-emmc`。
  - 升级脚本 `platform.sh` 设为 `CI_KERNPART="kernel"` 与 `CI_ROOTPART="rootfs"`（`emmc_do_upgrade`）。
  - 构建过程不覆盖 `u-boot-env`、`factory`、`fip` 及其他既有数据分区。
- **硬件驱动与状态灯**：
  - 无线采用开源 `mt76` 驱动（`kmod-mt7915e`、`kmod-mt7981-firmware`、`mt7981-wo-firmware`），从 `factory` 分区读取校准数据与 MAC 地址。
  - USB 3.0 启用 GPIO 14 VBUS 5V 供电控制。
  - `patches/002-mediatek-bt-r320-add-status-leds.patch` 定义 GPIO 10（红）、GPIO 11（绿）、GPIO 12（蓝）系统状态灯及 `led-boot` / `led-failsafe` / `led-running` / `led-upgrade` 别名。
- **配置内容**（`configs/bt-r320.diffconfig`）：
  - USB 存储与文件系统：`usbutils`、`lsblk`、`fdisk`、`blkid`、`kmod-usb-storage-uas`、`kmod-fs-exfat`、`kmod-fs-ntfs3`、`kmod-fs-f2fs`、`luci-app-hd-idle`。
  - 文件共享与容器：`luci-app-samba4`、`docker`、`dockerd`、`docker-compose`、`luci-app-dockerman`、`kmod-br-netfilter`、`kmod-veth`、`iptables-nft`、`ip6tables-nft`、`DOCKER_CGROUP_OPTIONS`、`DOCKER_NET_MACVLAN`、`DOCKER_STO_EXT4`。
  - 终端与本地化：`luci-app-ttyd` 及简体中文语言包。

## 3. GitHub Actions 云构建

1. 进入仓库 **Actions -> Build FanchmWrt for Globitel BT-R320 -> Run workflow**。
2. 构建参数：
   - `fanchmwrt_branch`：上游分支名，默认 `fanchmwrt-25.12.6`。
   - `apply_led_patch`：是否应用 GPIO 10/11/12 状态灯补丁，默认 `true`。
   - `upload_release`：是否发布至 GitHub Release，默认 `true`。
3. 构建完成后，在 Workflow Artifacts 或 Release 页面获取 `*-globitel_bt-r320-squashfs-sysupgrade.bin`、`*-initramfs-recovery.itb` 及 `sha256sums.txt`。

## 4. 本地构建（Ubuntu 22.04）

```bash
# 1. 拉取构建仓库与上游源码
git clone https://github.com/EasongChung/Actions-fanchmwrt-bt-r320.git
cd Actions-fanchmwrt-bt-r320
git clone --depth=1 -b fanchmwrt-25.12.6 https://github.com/fanchmwrt/fanchmwrt.git fanchmwrt-src

# 2. 更新并安装 Feeds
cd fanchmwrt-src
./scripts/feeds update -a && ./scripts/feeds install -a
cd ..

# 3. 应用补丁与配置（如需跳过 002 状态灯补丁，在末尾追加 --no-led-patch）
chmod +x .github/scripts/prepare_fanchmwrt.sh
./.github/scripts/prepare_fanchmwrt.sh ./fanchmwrt-src ./configs/bt-r320.diffconfig

# 4. 展开配置、下载源码并编译
cd fanchmwrt-src
make defconfig
make download -j8
make -j"$(nproc)" || make -j1 V=s
```

构建产物输出至 `fanchmwrt-src/bin/targets/mediatek/filogic/`。

## 5. 分区映射与刷写说明

适用传统 eMMC 分区表布局参考如下：

| `PARTLABEL` | 用途 | 刷写影响 |
| :--- | :--- | :--- |
| `u-boot-env` | U-Boot 环境变量 | 保持不变 |
| `factory` | 无线校准与 MAC 地址 | 保持不变 |
| `fip` | U-Boot 引导程序 | 保持不变 |
| `kernel` | 内核与设备树镜像 | 更新为 FanchmWrt Linux 6.12 |
| `rootfs` | 根文件系统与 Overlay | 更新为 SquashFS + Overlay |
| `userdata` / `primary` 等 | 扩展数据分区 | 保持不变 |

### 刷写步骤

1. **备份关键分区**：首次迁移前通过 SSH 备份 `factory`、`fip`、`u-boot-env` 及 `mmcblk0boot0`，并保存至本地主机。
2. **校验哈希**：核对下载的 `*-globitel_bt-r320-squashfs-sysupgrade.bin` 与 `sha256sums.txt` 一致。
3. **刷入镜像**：
   - 方式一：进入设备现有 WebUI U-Boot 恢复界面，上传 `*-squashfs-sysupgrade.bin` 刷入。
   - 方式二：在原固件系统内通过 SSH 执行 `sysupgrade -n /tmp/*-globitel_bt-r320-squashfs-sysupgrade.bin`（跨底包切换须使用 `-n` 清除旧配置，避免无线与防火墙配置冲突）。
4. **后续维护**：刷入后可在 LuCI **系统 -> 挂载点** 重新挂载原有数据分区；如需将 Docker 存储迁移至大容量数据分区，可在 LuCI 修改 Docker `data-root` 路径。如需退回原固件，重新进入 WebUI U-Boot 刷入原版 `sysupgrade.bin` 即可。
