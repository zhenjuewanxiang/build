#!/bin/sh
# Host-side helper to create a directory-style spinor A/B OTA package.
# Usage:
#   make_spinor_ab_ota.sh <output_dir> <board> <boot_raw> <rootfs_raw>
#   make_spinor_ab_ota.sh <output_dir> <board> <version|auto> <boot_raw> <rootfs_raw>

set -eu

usage()
{
	echo "Usage:" >&2
	echo "  $0 <output_dir> <board> <boot_raw> <rootfs_raw>" >&2
	echo "  $0 <output_dir> <board> <version|auto> <boot_raw> <rootfs_raw>" >&2
	exit 1
}

[ $# -eq 4 ] || [ $# -eq 5 ] || usage

OUT=$1
BOARD=$2
if [ $# -eq 4 ]; then
	VERSION=auto
	BOOT=$3
	ROOTFS=$4
else
	VERSION=$3
	BOOT=$4
	ROOTFS=$5
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd)
FW_CONFIG=${FW_VERSION_CONFIG:-}
if [ -z "$FW_CONFIG" ]; then
	FW_CONFIG=$(find "$TOP_DIR/build/boards" -path "*/$BOARD/firmware_version.conf" -print -quit 2>/dev/null || true)
fi

FW_VERSION=
FW_BOARD=$BOARD
FW_PRODUCT=
if [ -n "$FW_CONFIG" ] && [ -f "$FW_CONFIG" ]; then
	. "$FW_CONFIG"
	FW_BOARD=${FW_BOARD:-$BOARD}
fi

if [ "$VERSION" = auto ] || [ "$VERSION" = "-" ] || [ -z "$VERSION" ]; then
	if [ -z "$FW_VERSION" ]; then
		echo "FW_VERSION is missing. Check firmware_version.conf or pass version explicitly." >&2
		exit 1
	fi
	VERSION=$FW_VERSION
fi

mkdir -p "$OUT"
cp "$BOOT" "$OUT/boot.spinor"
cp "$ROOTFS" "$OUT/rootfs.spinor"
BOOT_SHA=$(sha256sum "$OUT/boot.spinor" | awk '{print $1}')
ROOTFS_SHA=$(sha256sum "$OUT/rootfs.spinor" | awk '{print $1}')
cat > "$OUT/manifest.env" <<EOF
OTA_BOARD=$BOARD
BOARD=$BOARD
VERSION=$VERSION
FW_VERSION=$VERSION
FW_BOARD=$FW_BOARD
FW_PRODUCT=$FW_PRODUCT
BOOT_SHA256=$BOOT_SHA
ROOTFS_SHA256=$ROOTFS_SHA
EOF
: > "$OUT/upgrade.ready"

echo "Created OTA package directory: $OUT"
