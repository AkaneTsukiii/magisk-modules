#!/bin/bash
# Patch boot.img Android thành Arch Linux ARM (dùng abootimg, chạy trên Linux)
# Author: ChatGPT
# Yêu cầu: Ubuntu/Debian + boot.img gốc của máy

set -e

# ====== Cấu hình ======
BOOT_IMG="boot.img" # boot.img gốc
ARCH_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz"

# ====== Kiểm tra file boot.img ======
if [ ! -f "$BOOT_IMG" ]; then
    echo "❌ Không tìm thấy $BOOT_IMG. Đặt file boot.img gốc vào cùng thư mục script."
    exit 1
fi

# ====== Cài công cụ cần thiết ======
echo "📦 Cài công cụ..."
sudo apt update -y
sudo apt install -y abootimg cpio gzip wget

# ====== Tạo thư mục làm việc ======
WORKDIR="boot_unpack"
rm -rf "$WORKDIR"
mkdir "$WORKDIR"
cd "$WORKDIR"

# ====== Giải nén boot.img ======
echo "🔍 Giải nén boot.img..."
abootimg -x "../$BOOT_IMG"

# ====== Giải nén ramdisk Android ======
mkdir ramdisk
cd ramdisk
gzip -dc ../initrd.img | cpio -idmv

# ====== Xóa ramdisk cũ và thêm Arch ======
echo "🗑 Xóa ramdisk Android..."
rm -rf ./*

echo "⬇️ Tải Arch Linux ARM..."
wget -O arch.tar.gz "$ARCH_URL"

echo "📂 Giải nén Arch vào ramdisk..."
mkdir -p mnt/root
tar -xzf arch.tar.gz -C mnt/root
rm arch.tar.gz

# ====== Tạo init script ======
cat > init <<'EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t tmpfs tmpfs /tmp
mount -o remount,rw /
echo "Booting Arch Linux ARM..."
exec switch_root /mnt/root /sbin/init
EOF
chmod +x init

# ====== Đóng gói lại ramdisk ======
echo "📦 Đóng gói ramdisk mới..."
find . | cpio --create --format='newc' | gzip > ../initrd-new.img
cd ..

# ====== Đóng gói lại boot.img ======
echo "📦 Đóng gói boot.img mới..."
abootimg --create boot-arch.img -f bootimg.cfg -k zImage -r initrd-new.img

# ====== Xuất kết quả ======
cd ..
mkdir -p output
cp "$WORKDIR/boot-arch.img" output/

echo "✅ Hoàn tất! File output/boot-arch.img sẵn sàng để flash."
echo "💡 Flash qua TWRP: Install → Install Image → Chọn boot-arch.img → Boot partition."
