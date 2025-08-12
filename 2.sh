#!/bin/bash
# Script patch boot.img để chèn Arch Linux rootfs (bỏ qua cảnh báo tar)
# Yêu cầu: Ubuntu/Debian có sẵn: abootimg, cpio, tar

BOOT_IMG="boot.img"       # File boot.img gốc
ARCH_ROOTFS="arch-rootfs.tar.gz"  # File rootfs Arch Linux
TMP_DIR="boot_unpack"
NEW_BOOT="boot_patched.img"

# Kiểm tra file
if [[ ! -f "$BOOT_IMG" || ! -f "$ARCH_ROOTFS" ]]; then
    echo "❌ Thiếu boot.img hoặc arch-rootfs.tar.gz"
    exit 1
fi

# Cài công cụ nếu chưa có
sudo apt update
sudo apt install -y abootimg cpio

# Bước 1: Giải nén boot.img
rm -rf "$TMP_DIR"
mkdir "$TMP_DIR"
cd "$TMP_DIR" || exit
abootimg -x "../$BOOT_IMG"

# Bước 2: Giải nén initramfs
mkdir initramfs
cd initramfs || exit
cat ../initrd.img | gzip -d | cpio -idmv

# Bước 3: Chèn Arch rootfs (bỏ qua cảnh báo tar)
mkdir -p arch
echo "📦 Giải nén Arch rootfs..."
tar --warning=no-unknown-keyword --no-xattrs -xzf "../../$ARCH_ROOTFS" -C arch

# (Tùy chỉnh init script nếu cần, vd: init -> chroot vào Arch)
cat << 'EOF' > init
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -o bind /dev /dev
exec chroot /arch /bin/bash
EOF
chmod +x init

# Bước 4: Đóng gói lại initramfs
find . | cpio -o -H newc | gzip > ../new_initrd.img
cd ..

# Bước 5: Tạo boot.img mới
abootimg --create "../$NEW_BOOT" -k zImage -r new_initrd.img -f bootimg.cfg

cd ..
echo "✅ Đã tạo $NEW_BOOT"
