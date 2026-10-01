#!/bin/sh
set -eu
headroom() {
  for path in / /project; do
    free_kb=$(df -Pk "$path" | awk 'END {print $4}')
    echo "headroom $path: $free_kb KiB"
    [ "$free_kb" -ge 20971520 ] || { echo 'Stop: less than 20 GiB headroom' >&2; exit 1; }
  done
}
headroom
apk add --no-cache build-base bash curl xz cpio lz4 zstd xorriso python3 git
mkdir -p build/native build/downloads build/rootfs build/evidence
if [ ! -f build/native/toybox ]; then
  curl -fL https://github.com/landley/toybox/archive/refs/tags/0.8.11.tar.gz -o build/downloads/toybox-0.8.11.tar.gz
  sha256sum build/downloads/toybox-0.8.11.tar.gz > build/evidence/toybox-source.sha256
  tar -xzf build/downloads/toybox-0.8.11.tar.gz -C build
  echo 'Build toybox with scripts/build-toybox.sh (Alpenglow Alpine 3.21 toolchain)' >&2
  exit 1
fi
headroom
# Oil's current rootfs bootstrap does not resolve dependencies for system add
# and assumes a different Alpine branch. Use APK signature verification and
# its dependency solver for the candidate; retain Oil from the pinned source.
apk --root /project/build/rootfs --arch x86_64 --initdb \
  --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories \
  add --no-cache $(sed '/^#/d;/^$/d' packages.txt)
if [ -f build/rootfs/boot/vmlinuz-lts ]; then
  cp build/rootfs/boot/vmlinuz-lts build/native/vmlinuz
else
  test -f build/native/vmlinuz
fi
dinit_bin=$(find build/rootfs -type f -name dinit | head -1)
cp "$dinit_bin" build/native/dinit
cp build/native/toybox build/rootfs/bin/toybox
mkdir -p build/rootfs/etc/dinit.d build/rootfs/root build/rootfs/dev build/rootfs/proc build/rootfs/sys build/rootfs/run build/rootfs/tmp
ROOT_DIR=/project/vendor/alpenglow
BACKEND_DIR=$ROOT_DIR/system/backends/appliance
ROOTFS_DIR=/project/build/rootfs OUT_DIR=/project/build/native
BUILD_PROFILE=minimal FAST=0 ALPENGLOW_MODULE=/nonexistent ZIG_INIT=0
toybox_has() { /project/build/native/toybox "$1" --help >/dev/null 2>&1; }
. "$ROOT_DIR/scripts/lib/assemble-rootfs.sh"
assemble_rootfs_config
printf 'root:x:0:0:root:/root:/bin/oksh\n' > build/rootfs/etc/passwd
ln -sf /usr/bin/oksh build/rootfs/bin/oksh
ln -sf "${dinit_bin#build/rootfs}" build/rootfs/sbin/dinit
cp -a overlay/. build/rootfs/
chmod 755 build/rootfs/init build/rootfs/usr/local/bin/* build/rootfs/usr/share/udhcpc/default.script
cat > build/rootfs/etc/os-release <<'EOF'
NAME="Alpenglow Rescue"
ID=alpenglow
VERSION_ID=0.1.0-dev
PRETTY_NAME="Alpenglow Rescue development candidate"
EOF
headroom
python3 scripts/install-clients.py
headroom
# Build Oil without changing core Rust sources or flags. Targets stay local.
apk add --no-cache cargo rust
CARGO_TARGET_DIR=/project/build/oil-target CARGO_BUILD_JOBS=2 \
  cargo build --release --locked --manifest-path vendor/alpenglow/system/oil/Cargo.toml
cp build/oil-target/release/oil build/rootfs/usr/local/bin/oil
mkdir -p build/rootfs/usr/share/alpenglow-rescue/fixtures
truncate -s 16M build/rootfs/usr/share/alpenglow-rescue/fixtures/ext4.img
chroot /project/build/rootfs /sbin/mkfs.ext4 -q -F /usr/share/alpenglow-rescue/fixtures/ext4.img
truncate -s 128M build/rootfs/usr/share/alpenglow-rescue/fixtures/btrfs.img
chroot /project/build/rootfs /sbin/mkfs.btrfs -q -f /usr/share/alpenglow-rescue/fixtures/btrfs.img
cp scripts/smoke.sh build/rootfs/usr/local/bin/rescue-smoke
chmod 755 build/rootfs/usr/local/bin/rescue-smoke
chroot /project/build/rootfs /usr/local/bin/rescue-smoke > build/evidence/smoke-container.txt 2>&1
apk --root build/rootfs info -vv > build/evidence/packages.txt
cp build/rootfs/lib/apk/db/installed build/evidence/apk-installed.txt
find build/rootfs/lib/firmware -type f | wc -l > build/evidence/firmware-file-count.txt
cp build/rootfs/boot/config-*-lts build/evidence/kernel.config
headroom
sh scripts/pack.sh
