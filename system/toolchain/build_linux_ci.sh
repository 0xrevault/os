#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# CI-friendly kernel build script (Ubuntu/Debian)
# Usage:
#   toolchain/build_linux_ci.sh [linux_dir] [jobs]
# ----------------------------------------

LINUX_DIR="${1:-submodules/linux}"
JOBS="${2:-$(nproc)}"
OUT_DIR="${PWD}/out"

echo "::group::Install deps"
export DEBIAN_FRONTEND=noninteractive
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends \
    build-essential bc bison flex libssl-dev \
    libelf-dev dwarves python3 rsync device-tree-compiler \
    gcc-aarch64-linux-gnu
fi
echo "::endgroup::"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

echo "::group::Build kernel"
pushd "${LINUX_DIR}" >/dev/null
make -s mrproper || true
make -s defconfig
make -s -j"${JOBS}" Image.gz dtbs modules
popd >/dev/null
echo "::endgroup::"

echo "::group::Collect artifacts"
mkdir -p "${OUT_DIR}/dtbs"
cp -f "${LINUX_DIR}/arch/arm64/boot/Image.gz" "${OUT_DIR}/"
cp -f "${LINUX_DIR}/arch/arm64/boot/dts/st/"*.dtb "${OUT_DIR}/dtbs/" || true

KREL="$(make -s -C "${LINUX_DIR}" kernelrelease)"
make -s -C "${LINUX_DIR}" modules_install INSTALL_MOD_PATH="${OUT_DIR}/rootfs-mod"

tar -C "${OUT_DIR}/rootfs-mod" -I 'zstd -19' -cf "${OUT_DIR}/modules.tar.zst" . || true
echo "::endgroup::"

echo "[✓] CI build done. Artifacts in ${OUT_DIR}"