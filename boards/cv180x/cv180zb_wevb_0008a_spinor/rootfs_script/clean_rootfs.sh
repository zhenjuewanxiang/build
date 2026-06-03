#!/bin/bash
set -e

SYSTEM_DIR=$1

# Keep the minimal base system needed for UVC/video + OTA. This board targets
# a 16MB spinor A/B layout, so rootfs must stay below the ROOTFS slot size.
cp -f "$SYSTEM_DIR/mnt/system/usr/bin/alios_cli" "$SYSTEM_DIR/bin/" 2>/dev/null || true
rm -rf "$SYSTEM_DIR/mnt/system/usr"
rm -rf "$SYSTEM_DIR/mnt/system/lib"

# Network/debug services are not required for production OTA images.
rm -rf "$SYSTEM_DIR/etc/init.d/S01syslogd"
rm -rf "$SYSTEM_DIR/etc/init.d/S02klogd"
rm -rf "$SYSTEM_DIR/etc/init.d/S02sysctl"
rm -rf "$SYSTEM_DIR/etc/init.d/S20urandom"
rm -rf "$SYSTEM_DIR/etc/init.d/S23ntp"
rm -rf "$SYSTEM_DIR/etc/init.d/S40network"
rm -rf "$SYSTEM_DIR/etc/init.d/S50dropbear"
rm -rf "$SYSTEM_DIR/etc/init.d/S99~udhcpc"
rm -rf "$SYSTEM_DIR/bin/ntpd" "$SYSTEM_DIR/bin/ntpdate"
rm -rf "$SYSTEM_DIR/usr/sbin/dropbear" "$SYSTEM_DIR/usr/sbin/wpa_supplicant" "$SYSTEM_DIR/usr/sbin/wpa_cli"
rm -rf "$SYSTEM_DIR/etc/dropbear" "$SYSTEM_DIR/etc/network/hostapd.conf" "$SYSTEM_DIR/etc/network/udhcpd.conf"
rm -rf "$SYSTEM_DIR/mnt/cfg/secure.img"

# Disable debugfs mount in release images.
sed -i "/debugfs/d" "$SYSTEM_DIR/etc/fstab" 2>/dev/null || true

# WiFi is too large for the A/B layout. Keep USB/UVC and core CVI modules.
rm -rf "$SYSTEM_DIR/mnt/system/ko/3rd"
rm -f "$SYSTEM_DIR/mnt/system/ko/loadwifi.sh"
rm -f "$SYSTEM_DIR/mnt/system/ko/cvi_ipcm_test.ko"
rm -f "$SYSTEM_DIR/mnt/system/ko/efivarfs.ko"
rm -f "$SYSTEM_DIR/mnt/system/ko/usb_f_mass_storage.ko"
rm -f "$SYSTEM_DIR/mnt/system/ko/usb_f_serial.ko"
rm -f "$SYSTEM_DIR/mnt/system/ko/usb_f_acm.ko"
rm -f "$SYSTEM_DIR/mnt/system/ko/usb_f_eem.ko"
rm -f "$SYSTEM_DIR/mnt/system/ko/usb_f_ecm.ko"
rm -f "$SYSTEM_DIR/mnt/system/ko/usb_f_rndis.ko"
rm -f "$SYSTEM_DIR/mnt/system/ko/u_serial.ko"

# Remove optional C++/OpenMP runtime unless an app explicitly ships it in DATA.
rm -f "$SYSTEM_DIR/lib/libgomp.so"* "$SYSTEM_DIR/lib/libatomic.so"*

# Make sure OTA helpers are executable when supplied by overlay/packages.
chmod +x "$SYSTEM_DIR/usr/sbin/ota_update.sh" "$SYSTEM_DIR/usr/sbin/ota_mark_good.sh" 2>/dev/null || true
chmod +x "$SYSTEM_DIR/etc/init.d/S98ota_mark_good" 2>/dev/null || true

du -sh "$SYSTEM_DIR"/* | sort -rh
