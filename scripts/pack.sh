#!/bin/sh
# Reuse Alpenglow's Limine + xorriso release layout, without disk mounts or installer.
set -eu
mkdir -p build/iso-root/boot/limine build/limine build/evidence
if [ ! -f build/limine/limine-bios-cd.bin ]; then
  curl -fL https://github.com/limine-bootloader/limine/releases/download/v12.4.0/limine-binary.tar.xz -o build/downloads/limine-12.4.0.tar.xz
  sha256sum build/downloads/limine-12.4.0.tar.xz > build/evidence/limine-source.sha256
  tar -xJf build/downloads/limine-12.4.0.tar.xz -C build/limine --strip-components=1
fi
cp build/native/vmlinuz build/iso-root/boot/vmlinuz
# Sorted cpio, reproducible owners/mtime. Compression uses at most two threads.
find build/rootfs -exec touch -h -d @1790812800 {} +
(cd build/rootfs; find . -print0 | sort -z | cpio --null -o -H newc --reproducible --owner=0:0 2>/dev/null | zstd -6 -T2 -o ../initramfs.cpio.zst -f)
cp build/initramfs.cpio.zst build/iso-root/boot/
cp build/limine/limine-bios.sys build/limine/limine-bios-cd.bin build/limine/limine-uefi-cd.bin build/iso-root/boot/limine/
cat > build/iso-root/boot/limine/limine.conf <<'EOF'
timeout: 0
verbose: no

/Alpenglow Rescue (basic console)
  protocol: linux
  path: boot():/boot/vmlinuz
  cmdline: console=tty0 console=ttyS0 init=/init alpenglow.rescue=1
  module_path: boot():/boot/initramfs.cpio.zst
EOF
xorriso -as mkisofs -o build/alpenglow-rescue-x86_64.iso -V ALPENGLOW_RESCUE -r -J \
  -b boot/limine/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
  --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image --protective-msdos-label \
  build/iso-root
cc -O2 -o build/limine/limine build/limine/limine.c
build/limine/limine bios-install build/alpenglow-rescue-x86_64.iso
sha256sum build/alpenglow-rescue-x86_64.iso build/initramfs.cpio.zst build/native/vmlinuz > build/evidence/SHA256SUMS
stat -c '%n %s' build/alpenglow-rescue-x86_64.iso build/initramfs.cpio.zst build/native/vmlinuz > build/evidence/artifact-bytes.txt
du -sk build/rootfs/lib/firmware build/rootfs/lib/modules build/rootfs/opt/* > build/evidence/component-kib.txt
