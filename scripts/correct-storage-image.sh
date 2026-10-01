#!/bin/sh
# Small corrective initramfs layered on the exact CI-built native kernel.
# No kernel recompilation or replacement of Alpenglow init/PID 1/core binaries.
set -eu
test "${CI:-}" = true
cd "$(dirname "$0")/.."
test "$(df -Pk . | awk 'END {print $4}')" -ge 25165824
start_kib=$(du -sk build | awk '{print $1}')
mkdir -p build/correction/root/bin build/correction/root/etc build/correction/root/usr/local/bin build/correction/limine
python3 - <<'PY'
import hashlib,json,shutil
from pathlib import Path
p=Path('build/ci/output/alpenglow-rescue-storage-1-x86_64.iso')
m=json.loads(Path('build/ci/output/manifest.json').read_text())
assert p.stat().st_size==m['image_bytes'] and hashlib.sha256(p.read_bytes()).hexdigest()==m['image_sha256']
shutil.copyfile(p,'build/correction/base.iso')
Path('build/correction/base-manifest.json').write_text(json.dumps(m,indent=2)+'\n')
PY
xorriso -osirrox on -indev build/correction/base.iso -extract / build/correction/iso-root
# Obtain only the missing terminal data, exact already-inventoried version,
# through the same signature-verified official package source.
docker run --rm --cpus=2 --memory=128m --pids-limit=128 \
  --label alpenglow-rescue.build=task15-fast-20261001 \
  -v "$PWD/build/correction:/out" \
  alpine@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0 sh -c '
    test "$(df -Pk / | awk "END {print \$4}")" -ge 22020096
    apk add --no-cache --no-scripts ncurses-terminfo-base=6.5_p20251123-r0
    tar -cf /out/terminfo.tar -C /etc terminfo
    test "$(df -Pk / | awk "END {print \$4}")" -ge 22020096
  '
tar -xf build/correction/terminfo.tar -C build/correction/root/etc
ln -s /usr/bin/oksh build/correction/root/bin/sh
printf '%s\n' 'export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' > build/correction/root/etc/profile
cp scripts/smoke-storage.sh build/correction/root/usr/local/bin/rescue-smoke-storage
chmod 755 build/correction/root/usr/local/bin/rescue-smoke-storage
(cd build/correction/root; find . -print | LC_ALL=C sort | cpio -o -H newc -R 0:0 | gzip -n -9) > build/correction/iso-root/boot/storage-correction.cpio.gz
cat > build/correction/iso-root/boot/limine/limine.conf <<'EOF'
timeout: 0
verbose: no

/Alpenglow Rescue STORAGE-1A TEST (partial; corrected shell and terminfo)
  protocol: linux
  path: boot():/boot/vmlinuz
  module_path: boot():/boot/storage-correction.cpio.gz
  cmdline: quiet console=ttyS0 init=/init alpenglow.test-fixtures=1
EOF
printf '\nStorage-1a: supplemental initramfs changes /bin/sh to the already packaged ISC/BSD oksh, adds MIT ncurses terminfo data and the MPL project probe. Native embedded kernel/init/dinit/Toybox unchanged. Exact base, overlay and recipe hashes are in the manifest. Partial candidate; full source/distribution audit pending.\n' >> build/correction/iso-root/COMPONENT-LICENSES.txt
curl -fsSL https://github.com/Limine-Bootloader/Limine/releases/download/v12.4.0/limine-binary.tar.xz -o build/correction/limine.tar.xz
printf '%s\n' '4e788c85c427c3e12c7592938e3b0f49853e7f150fa470b37ac931371e079e8e  build/correction/limine.tar.xz' | sha256sum -c -
tar -xf build/correction/limine.tar.xz -C build/correction/limine --strip-components=1
xorriso -as mkisofs -o build/ci/output/alpenglow-rescue-storage-1-x86_64.iso -V ALPENGLOW_RESCUE -r -J \
  -b boot/limine/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
  --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image --protective-msdos-label build/correction/iso-root
cc -O2 -o build/correction/limine/limine build/correction/limine/limine.c
build/correction/limine/limine bios-install build/ci/output/alpenglow-rescue-storage-1-x86_64.iso
python3 - <<'PY'
import hashlib,json,subprocess
from pathlib import Path
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads(Path('build/correction/base-manifest.json').read_text())
assert sha(Path('build/correction/iso-root/boot/vmlinuz'))==m['native_artifacts']['vmlinuz']['sha256']
m['base_project_commit']=m['project_commit'];m['base_image_sha256']=m['image_sha256']
m['project_commit']=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
m['scope']='Native storage-1a partial rescue; exact embedded native kernel plus small supplemental shell/terminfo/probe initramfs. No networking/firmware/AI/full parity claim.'
p=Path('build/ci/output/alpenglow-rescue-storage-1-x86_64.iso')
m['image_sha256']=sha(p);m['image_bytes']=p.stat().st_size
o=Path('build/correction/iso-root/boot/storage-correction.cpio.gz')
m['supplemental_initramfs']={'bytes':o.stat().st_size,'sha256':sha(o),'shell':'/bin/sh -> /usr/bin/oksh','probe_sha256':sha(Path('scripts/smoke-storage.sh')),'terminfo_package':'ncurses-terminfo-base=6.5_p20251123-r0','terminfo_archive_sha256':sha(Path('build/correction/terminfo.tar'))}
Path('build/ci/output/manifest.json').write_text(json.dumps(m,indent=2)+'\n')
p.with_suffix('.iso.sha256').write_text(m['image_sha256']+'  '+p.name+'\n')
print(json.dumps(m,indent=2))
PY
test "$(df -Pk . | awk 'END {print $4}')" -ge 22020096
end_kib=$(du -sk build | awk '{print $1}')
test "$((end_kib-start_kib))" -le 4194304
printf 'Correction allocated growth: %s KiB; cap 4194304 KiB\n' "$((end_kib-start_kib))"
