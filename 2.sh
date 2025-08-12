#!/bin/bash
# Script patch boot.img để boot vào Arch Linux ARM thay vì Android
# Yêu cầu: Ubuntu/Debian, có sẵn boot.img, file Arch rootfs tar.gz

set -e

# ====== Cấu hình ======
BOOT_IMG="boot.img"                     # Đường dẫn tới boot.img gốc
ARCH_ROOTFS="ArchLinuxARM-armv7.tar.gz"  # Rootfs Arch Linux ARM (tải từ archlinuxarm.org)
WORKDIR="$(pwd)/patch_boot"
RAMDISK_DIR="$WORKDIR/ramdisk"
KERNEL_DIR="$WORKDIR/kernel"
OUT_IMG="boot_patched.img"

# ====== Kiểm tra gói cần thiết ======
sudo apt update
sudo apt install -y abootimg bsdtar mkbootimg

# ====== Chuẩn bị thư mục ======
rm -rf "$WORKDIR"
mkdir -p "$RAMDISK_DIR" "$KERNEL_DIR"

echo "[*] Giải nén boot.img..."
abootimg -x "$BOOT_IMG" -o "$WORKDIR"

echo "[*] Giải nén ramdisk..."
mkdir "$RAMDISK_DIR/original"
cd "$RAMDISK_DIR/original"
gunzip -c "$WORKDIR"/initrd.img | cpio -id

# ====== Thay rootfs ======
echo "[*] Xóa rootfs cũ và thay bằng Arch..."
ROOT_MNT="$RAMDISK_DIR/original/root"
sudo rm -rf "$ROOT_MNT"
mkdir -p "$ROOT_MNT"

# Giải nén Arch rootfs, bỏ qua cảnh báo xattr
sudo bsdtar --no-xattrs -xpf "$ARCH_ROOTFS" -C "$ROOT_MNT"

# ====== Chỉnh init script ======
echo "[*] Chỉnh sửa init để mount rootfs..."
INIT_FILE="$RAMDISK_DIR/original/init"
sudo sed -i 's|/init.rc|/sbin/init|g' "$INIT_FILE"

# ====== Đóng gói lại ramdisk ======
echo "[*] Đóng gói lại ramdisk..."
cd "$RAMDISK_DIR/original"
find . | cpio -o -H newc | gzip > "$WORKDIR/new_initrd.img"

# ====== Tạo boot.img mới ======
echo "[*] Tạo boot.img mới..."
mkbootimg --kernel "$WORKDIR/zImage" \
          --ramdisk "$WORKDIR/new_initrd.img" \
          --base 0x10000000 \
          -o "$OUT_IMG"

echo "[+] Hoàn tất! File boot.img đã patch: $OUT_IMG"
