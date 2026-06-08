#!/bin/bash
set -e

DATA_DIR=$1
APP_SRC=${2:-}

mkdir -p "$DATA_DIR/bin" "$DATA_DIR/lib"

# Keep only the runtime payload needed by video_sei_enc. Logs/user data should
# be created at runtime, not baked into the OTA DATA image.
find "$DATA_DIR" -mindepth 1 -maxdepth 1 ! -name bin ! -name lib ! -name auto.sh ! -name ConfigUVC.sh ! -name sensor_cfg.ini -exec rm -rf {} +

if [ -n "$APP_SRC" ] && [ -x "$APP_SRC/video_sei_enc" ]; then
	cp -f "$APP_SRC/video_sei_enc" "$DATA_DIR/bin/video_sei_enc"
else
	echo "missing rebuilt video_sei_enc: $APP_SRC/video_sei_enc" >&2
	exit 1
fi

# Remove libraries not needed by video_sei_enc.
KEEP_LIBS=" libmsg.so libcvilink.so libsys.so libvi.so libvpss.so libvo.so librgn.so libgdc.so libvenc.so libcvi_bin.so libcvi_bin_isp.so libisp.so libae.so libaf.so libawb.so libini.so libmisc.so libcvi_audio.so libcvi_vqe.so libcvi_VoiceEngine.so libsbc.so libcvi_RES1.so libtinyalsa.so libcvi_ssp.so libcvitracer.so libsns_full.so libisp_algo.so "
for lib in "$DATA_DIR"/lib/*; do
	[ -e "$lib" ] || continue
	base=$(basename "$lib")
	case "$KEEP_LIBS" in
		*" $base "*) ;;
		*) rm -f "$lib" ;;
	esac
done

# Ensure startup uses only DATA app/libs plus base rootfs libs.
cat > "$DATA_DIR/auto.sh" <<'EOF'
#!/bin/sh
export LD_LIBRARY_PATH="/lib:/usr/lib:/mnt/data/lib"
/etc/run_usb.sh probe uvc
[ -x /mnt/data/ConfigUVC.sh ] && /mnt/data/ConfigUVC.sh
/etc/run_usb.sh probe uac1
UAC_FUNC=$(find /tmp/usb/usb_gadget/cvitek/functions -maxdepth 1 -name "uac1.*" | head -n 1)
if [ -n "$UAC_FUNC" ]; then
    echo 0 > "$UAC_FUNC/c_chmask" 2>/dev/null || true
    echo 3 > "$UAC_FUNC/p_chmask" 2>/dev/null || true
    echo 48000 > "$UAC_FUNC/p_srate" 2>/dev/null || true
    echo 2 > "$UAC_FUNC/p_ssize" 2>/dev/null || true
fi
/etc/run_usb.sh start
echo device > /proc/cviusb/otg_role 2>/dev/null || true
if [ -x /mnt/data/bin/video_sei_enc ]; then
    /mnt/data/bin/video_sei_enc > /dev/null 2>&1 &
fi
EOF
chmod +x "$DATA_DIR/auto.sh"

# Strip payloads again in case they were copied after the generic strip step.
STRIP=${CROSS_COMPILE_SDK:-riscv64-unknown-linux-musl-}strip
if ! command -v "$STRIP" >/dev/null 2>&1; then
	SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
	SEARCH_DIR=$SCRIPT_DIR
	while [ "$SEARCH_DIR" != "/" ]; do
		TOOL="$SEARCH_DIR/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-strip"
		if [ -x "$TOOL" ]; then
			STRIP=$TOOL
			break
		fi
		SEARCH_DIR=$(dirname "$SEARCH_DIR")
	done
fi
if command -v "$STRIP" >/dev/null 2>&1 || [ -x "$STRIP" ]; then
	find "$DATA_DIR" -type f -perm /111 -exec "$STRIP" --strip-all {} 2>/dev/null \; || true
	find "$DATA_DIR" -name '*.so*' -type f -exec "$STRIP" --strip-all {} 2>/dev/null \; || true
fi

du -sh "$DATA_DIR"/* | sort -rh
