#!/usr/bin/env bash
set -euo pipefail

# 准备 FanchmWrt 编译目录：应用补丁、注入 diffconfig 与自定义 files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OPENWRT_DIR="${1:?Usage: $0 <openwrt_source_dir> [diffconfig] [--no-led-patch]}"
CONFIG_FILE="${2:-${REPO_ROOT}/configs/bt-r320.diffconfig}"
PATCH_MODE="${3:-}"

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
    if [ "${PATCH_MODE}" = "--no-led-patch" ] && [[ "${patch_name}" == *add-status-leds* ]]; then
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

echo "==> Preparation completed."
