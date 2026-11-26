#!/usr/bin/env bash
set -euo pipefail

# 准备 FanchmWrt 编译目录：应用补丁、注入 diffconfig 与自定义 files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OPENWRT_DIR="${1:?Usage: $0 <openwrt_source_dir> [diffconfig] [--no-patch]}"
CONFIG_FILE="${2:-${REPO_ROOT}/configs/bt-r320.diffconfig}"
NO_PATCH="${3:-}"

if [ ! -d "${OPENWRT_DIR}" ]; then
  echo "ERROR: OpenWrt source directory not found: ${OPENWRT_DIR}" >&2
  exit 1
fi

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "ERROR: Config file not found: ${CONFIG_FILE}" >&2
  exit 1
fi

if [ "${NO_PATCH}" != "--no-patch" ] && [ -d "${REPO_ROOT}/patches" ]; then
  echo "==> Applying patches from ${REPO_ROOT}/patches ..."
  shopt -s nullglob
  for patch_file in "${REPO_ROOT}"/patches/*.patch; do
    echo "Checking patch: $(basename "${patch_file}")"
    git -C "${OPENWRT_DIR}" apply --check "${patch_file}"
    git -C "${OPENWRT_DIR}" apply "${patch_file}"
    echo "Applied: $(basename "${patch_file}")"
  done
  shopt -u nullglob
else
  echo "==> Skipping patches (${NO_PATCH:-none})."
fi

if [ -d "${REPO_ROOT}/files" ]; then
  # 仅当存在非 .gitkeep 文件时复制覆盖目录
  if find "${REPO_ROOT}/files" -mindepth 1 ! -name '.gitkeep' | grep -q .; then
    echo "==> Copying custom files overlay ..."
    mkdir -p "${OPENWRT_DIR}/files"
    rsync -a --exclude='.gitkeep' "${REPO_ROOT}/files/" "${OPENWRT_DIR}/files/"
  fi
fi

echo "==> Copying diffconfig to .config ..."
cp -f "${CONFIG_FILE}" "${OPENWRT_DIR}/.config"

echo "==> Preparation completed."
