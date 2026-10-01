#!/bin/sh
# BIOS bootable proof ISO for the native FAST base; no rescue parity claim.
set -eu
cd "$(dirname "$0")/.."
test "${ALPENGLOW_FAST_CONTINUATION:-0}" = 1
test "$(df -Pk . | awk 'END {print $4}')" -ge 22020096
test -s build/fast-source/build/native/vmlinuz
grep -qx 'root:x:0:0:root:/root:/bin/sh' build/fast-source/build/native/rootfs/etc/passwd
test -L build/fast-source/build/native/rootfs/bin/sh
mkdir -p build/ci/limine build/ci/iso-root/boot/limine build/ci/output
image_name=alpenglow-fast-base-x86_64
image_title='Alpenglow FAST BASE PROOF (rescue payload absent)'
test_flags=''
if [ "${ALPENGLOW_RESCUE_INCREMENT:-fast-base}" = storage-1 ]; then
  image_name=alpenglow-rescue-storage-1-x86_64
  image_title='Alpenglow Rescue STORAGE-1 TEST (partial; synthetic fixtures only)'
  test_flags='alpenglow.test-fixtures=1'
  python3 scripts/storage-evidence.py
fi
export ALPENGLOW_IMAGE_NAME="$image_name"
curl -fsSL https://github.com/Limine-Bootloader/Limine/releases/download/v12.4.0/limine-binary.tar.xz -o build/ci/limine.tar.xz
printf '%s\n' '4e788c85c427c3e12c7592938e3b0f49853e7f150fa470b37ac931371e079e8e  build/ci/limine.tar.xz' | sha256sum -c -
tar -xf build/ci/limine.tar.xz -C build/ci/limine --strip-components=1
cp build/fast-source/build/native/vmlinuz build/ci/iso-root/boot/vmlinuz
cp build/ci/limine/limine-bios.sys build/ci/limine/limine-bios-cd.bin build/ci/limine/limine-uefi-cd.bin build/ci/iso-root/boot/limine/
cat > build/ci/iso-root/boot/limine/limine.conf <<EOF
timeout: 0
verbose: no

/$image_title
  protocol: linux
  path: boot():/boot/vmlinuz
  cmdline: quiet console=ttyS0 init=/init $test_flags
EOF
cp README.md LICENSE build/ci/iso-root/
cat > build/ci/iso-root/COMPONENT-LICENSES.txt <<'EOF'
This is a native FAST base boot proof, not a complete rescue distribution.
Project and Alpenglow Zig init: MPL-2.0, pinned source in vendor/alpenglow.
Linux 7.1.3: GPL-2.0-only, https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.3.tar.xz
Toybox 0.8.11: 0BSD, https://landley.net/toybox/downloads/toybox-0.8.11.tar.gz
dinit 0.19.2: Apache-2.0, https://github.com/davmac314/dinit/tree/v0.19.2
Limine 12.4.0: BSD-2-Clause, https://github.com/Limine-Bootloader/Limine/tree/v12.4.0
Exact source hashes and build recipes are retained with the GitHub artifact.
EOF
if [ "${ALPENGLOW_RESCUE_INCREMENT:-fast-base}" = storage-1 ]; then
  printf '\nStorage-1 partial rescue payload: exact package licenses and source recipe commits are in PACKAGE-LICENSES.json. Final source/distribution audit pending. No proprietary clients included.\n' >> build/ci/iso-root/COMPONENT-LICENSES.txt
fi
xorriso -as mkisofs -o "build/ci/output/$image_name.iso" -V ALPENGLOW_BASE -r -J \
  -b boot/limine/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
  --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image --protective-msdos-label build/ci/iso-root
cc -O2 -o build/ci/limine/limine build/ci/limine/limine.c
build/ci/limine/limine bios-install "build/ci/output/$image_name.iso"
python3 - <<'PY'
import hashlib,json,os,subprocess
from pathlib import Path
p=Path('build/ci/output')/(os.environ['ALPENGLOW_IMAGE_NAME']+'.iso')
h=hashlib.sha256(p.read_bytes()).hexdigest()
p.with_suffix('.iso.sha256').write_text(h+'  '+p.name+'\n')
pins=json.loads(Path('pins.json').read_text())
manifest={'scope':'Native FAST base proof only; rescue clients, payload, restored drivers and network readiness absent',
          'project_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
          'alpenglow_commit':pins['alpenglow'],'kernel':pins['fast_native'],
          'image_bytes':p.stat().st_size,'image_sha256':h,'tested_firmware':None,
          'native_artifacts':{}}
if os.environ.get('ALPENGLOW_RESCUE_INCREMENT')=='storage-1':
 manifest['scope']='Native storage-1 partial rescue: built-in storage/filesystems/EFI and signed APK tools; no network/firmware/AI parity claim'
 manifest['kernel_config_sha256']=hashlib.sha256(Path('build/ci/output/kernel.config').read_bytes()).hexdigest()
for name in ['vmlinuz','initramfs.cpio.lz4','alpenglow-init','toybox','dinit']:
 a=Path('build/fast-source/build/native')/name
 manifest['native_artifacts'][name]={'bytes':a.stat().st_size,'sha256':hashlib.sha256(a.read_bytes()).hexdigest()}
Path('build/ci/output/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
