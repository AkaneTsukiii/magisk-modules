#!/bin/bash
# Patch boot.img Android thành Arch Linux ARM nhẹ cho J2 Prime
# Yêu cầu: Ubuntu/Debian + boot.img gốc

set -e

# ====== Cấu hình ======
BOOT_IMG="boot.img" # Đường dẫn boot.img gốc
ARCH_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz"

# ====== Kiểm tra ======
if [ ! -f "$BOOT_IMG" ]; then
    echo "❌ Không tìm thấy $BOOT_IMG. Vui lòng đặt boot.img gốc trong thư mục script."
    exit 1
fi

echo "📦 Cài công cụ cần thiết..."
sudo apt update -y
sudo apt install -y git cpio gzip lz4 lzop wget

# ====== Tải AIK ======
if [ ! -d "Android-Image-Kitchen" ]; then
    git clone https://github.com/osm0sis/Android-Image-Kitchen.git
fi
cd Android-Image-Kitchen
chmod +x unpackimg.sh repackimg.sh

# ====== Giải nén boot.img ======
echo "🔍 Giải nén boot.img..."
./unpackimg.sh "../$BOOT_IMG"

# ====== Tạo ramdisk Linux ======
cd ramdisk
echo "🗑 Xóa ramdisk Android..."
rm -rf ./*

echo "⬇️ Tải Arch Linux ARM rootfs..."
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

cd ..

# ====== Đóng gói lại ======
echo "📦 Đóng gói boot.img mới..."
./repackimg.sh

# ====== Kết quả ======
cd ..
mkdir -p output
cp Android-Image-Kitchen/image-new.img output/boot-arch.img

echo "✅ Hoàn tất! File boot-arch.img nằm trong thư mục output/"
echo "💡 Flash qua TWRP: Install → Install Image → Chọn boot-arch.img → Flash vào Boot"
