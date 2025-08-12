#!/bin/bash
# Script patch boot.img để chèn Arch Linux ARM rootfs cho J2 Prime (ARMv7)
# Yêu cầu: Ubuntu/Debian có sẵn: abootimg, cpio, tar, wget

BOOT_IMG="boot.img"      # File boot.img gốc
TMP_DIR="boot_unpack"
NEW_BOOT="boot_patched.img"
ARCH_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz"
ARCH_ROOTFS="arch-rootfs.tar.gz"

# Kiểm tra file boot.img
if [[ ! -f "$BOOT_IMG" ]]; then
    echo "❌ Không tìm thấy $BOOT_IMG"
    exit 1
fi

# Cài công cụ nếu chưa có
sudo apt update
sudo apt install -y abootimg cpio wget

# Bước 1: Tải rootfs Arch Linux ARM
if [[ ! -f "$ARCH_ROOTFS" ]]; then
    echo "🌐 Đang tải Arch Linux ARM rootfs..."
    wget -O "$ARCH_ROOTFS" "$ARCH_URL"
else
    echo "✅ Đã có $ARCH_ROOTFS, bỏ qua bước tải."
fi

# Bước 2: Giải nén boot.img
rm -rf "$TMP_DIR"
mkdir "$TMP_DIR"
cd "$TMP_DIR" || exit
abootimg -x "../$BOOT_IMG"

# Bước 3: Giải nén initramfs
mkdir initramfs
cd initramfs || exit
cat ../initrd.img | gzip -d | cpio -idmv

# Bước 4: Giải nén rootfs Arch vào /arch (bỏ qua cảnh báo)
mkdir -p arch
echo "📦 Giải nén Arch rootfs..."
tar --warning=no-unknown-keyword --no-xattrs -xzf "../../$ARCH_ROOTFS" -C arch

# Bước 5: Tạo init script để chroot vào Arch
cat << 'EOF' > init
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -o bind /dev /dev
exec chroot /arch /bin/bash
EOF
chmod +x init

# Bước 6: Đóng gói lại initramfs
find . | cpio -o -H newc | gzip > ../new_initrd.img
cd ..

# Bước 7: Tạo boot.img mới
abootimg --create "../$NEW_BOOT" -k zImage -r new_initrd.img -f bootimg.cfg

cd ..
echo "✅ Hoàn tất! File boot mới: $NEW_BOOT"
