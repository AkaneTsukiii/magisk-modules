#!/system/bin/sh
# Build boot.img với Alpine Linux cho J2 Prime (không Android)
# Yêu cầu: root, magiskboot, wget, tar, cpio
# Sau khi build, flash boot-linux.img qua TWRP

set -e

ALPINE_VER="3.20.0"
ALPINE_ARCH="armhf"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ALPINE_ARCH}/alpine-minirootfs-${ALPINE_VER}-${ALPINE_ARCH}.tar.gz"
WORKDIR="/data/local/tmp/linux_boot_build"

echo "[*] Tạo thư mục tạm..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[*] Tìm phân vùng boot..."
BOOT_PART=$(ls -l /dev/block/by-name | grep boot | awk '{print $9}')
BOOT_DEV="/dev/block/by-name/$BOOT_PART"

if [ ! -e "$BOOT_DEV" ]; then
    echo "[!] Không tìm thấy phân vùng boot!"
    exit 1
fi

echo "[*] Sao lưu boot.img gốc..."
su -c "dd if=$BOOT_DEV of=$WORKDIR/boot.img"

echo "[*] Tải magiskboot nếu chưa có..."
if [ ! -f magiskboot ]; then
    wget https://github.com/topjohnwu/magiskboot/releases/latest/download/magiskboot-arm -O magiskboot
    chmod +x magiskboot
fi

echo "[*] Giải nén boot.img..."
./magiskboot unpack boot.img

echo "[*] Xóa ramdisk Android..."
mkdir ramdisk
cd ramdisk
if [ -f ../ramdisk.cpio ]; then
    cpio -id < ../ramdisk.cpio
    rm -rf *
fi
cd ..

echo "[*] Tải Alpine ${ALPINE_VER} (${ALPINE_ARCH})..."
wget "$ALPINE_URL" -O alpine.tar.gz

echo "[*] Giải nén Alpine vào ramdisk..."
tar -xzf alpine.tar.gz -C ramdisk

echo "[*] Tạo init tối giản..."
cat > ramdisk/init <<'EOF'
#!/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs devtmpfs /dev
exec /bin/sh
EOF
chmod +x ramdisk/init

echo "[*] Đóng gói ramdisk mới..."
cd ramdisk
find . | cpio -H newc -o > ../new-ramdisk.cpio
cd ..

echo "[*] Repack boot.img với Alpine..."
./magiskboot repack boot.img new-boot.img

echo "[*] Lưu boot-linux.img ra /sdcard..."
cp new-boot.img /sdcard/boot-linux.img

echo "[+] Hoàn tất! Vào TWRP và flash /sdcard/boot-linux.img vào phân vùng Boot."
