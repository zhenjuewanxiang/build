#!/bin/sh
# Host-side helper to create a directory-style spinor A/B OTA package.
# Usage: make_spinor_ab_ota.sh <output_dir> <board> <version> <boot_raw> <rootfs_raw>

set -eu
OUT=${1:?output_dir required}
BOARD=${2:?board required}
VERSION=${3:?version required}
BOOT=${4:?boot raw image required}
ROOTFS=${5:?rootfs raw image required}

mkdir -p "$OUT"
cp "$BOOT" "$OUT/boot.spinor"
cp "$ROOTFS" "$OUT/rootfs.spinor"
BOOT_SHA=$(sha256sum "$OUT/boot.spinor" | awk '{print $1}')
ROOTFS_SHA=$(sha256sum "$OUT/rootfs.spinor" | awk '{print $1}')
cat > "$OUT/manifest.env" <<EOF
OTA_BOARD=$BOARD
BOARD=$BOARD
VERSION=$VERSION
BOOT_SHA256=$BOOT_SHA
ROOTFS_SHA256=$ROOTFS_SHA
EOF

echo "Created OTA package directory: $OUT"
