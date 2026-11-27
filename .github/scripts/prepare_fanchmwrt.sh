#!/usr/bin/env bash
set -euo pipefail

# 准备 FanchmWrt 编译目录：应用补丁、注入 diffconfig 与自定义 files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OPENWRT_DIR="${1:?Usage: $0 <openwrt_source_dir> [diffconfig] [--no-led-patch] [--no-istore]}"
shift

CONFIG_FILE="${REPO_ROOT}/configs/bt-r320.diffconfig"
SKIP_LED_PATCH=0
SKIP_ISTORE=0

if [ "${#}" -gt 0 ] && [[ "${1}" != --* ]]; then
  CONFIG_FILE="${1}"
  shift
fi

for arg in "$@"; do
  case "${arg}" in
    --no-led-patch)
      SKIP_LED_PATCH=1
      ;;
    --no-istore)
      SKIP_ISTORE=1
      ;;
    *)
      echo "ERROR: Unknown option: ${arg}" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "${OPENWRT_DIR}" ]; then
  echo "ERROR: OpenWrt source directory not found: ${OPENWRT_DIR}" >&2
  exit 1
fi

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "ERROR: Config file not found: ${CONFIG_FILE}" >&2
  exit 1
fi

if [ -d "${REPO_ROOT}/patches" ]; then
  echo "==> Applying patches from ${REPO_ROOT}/patches ..."
  shopt -s nullglob
  for patch_file in "${REPO_ROOT}"/patches/*.patch; do
    patch_name="$(basename "${patch_file}")"
    if [ "${SKIP_LED_PATCH}" -eq 1 ] && [[ "${patch_name}" == *add-status-leds* ]]; then
      echo "Skipping optional LED patch: ${patch_name}"
      continue
    fi
    echo "Checking patch: ${patch_name}"
    git -C "${OPENWRT_DIR}" apply --check "${patch_file}"
    git -C "${OPENWRT_DIR}" apply "${patch_file}"
    echo "Applied: ${patch_name}"
  done
  shopt -u nullglob
fi

if [ -d "${REPO_ROOT}/files" ]; then
  if find "${REPO_ROOT}/files" -mindepth 1 ! -name '.gitkeep' | grep -q .; then
    echo "==> Copying custom files overlay ..."
    mkdir -p "${OPENWRT_DIR}/files"
    rsync -a --exclude='.gitkeep' "${REPO_ROOT}/files/" "${OPENWRT_DIR}/files/"
  fi
fi

echo "==> Copying diffconfig to .config ..."
cp -f "${CONFIG_FILE}" "${OPENWRT_DIR}/.config"

if [ "${SKIP_ISTORE}" -eq 1 ]; then
  echo "==> Disabling iStore entries in .config ..."
  sed -i '/^CONFIG_PACKAGE_luci-app-store=/d;/^CONFIG_PACKAGE_luci-compat=/d' "${OPENWRT_DIR}/.config"
fi

echo "==> Preparation completed."
