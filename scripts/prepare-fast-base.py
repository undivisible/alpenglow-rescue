#!/usr/bin/env python3
"""Adapt pinned fast-build orchestration in a generated copy; leave vendor intact."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

root = Path(__file__).resolve().parents[1]
source = root / 'vendor/alpenglow'
pins = json.loads((root / 'pins.json').read_text())
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true', help='validate edits in memory only')
args = parser.parse_args()
continuation = os.environ.get('ALPENGLOW_FAST_CONTINUATION') == '1'
increment = os.environ.get('ALPENGLOW_RESCUE_INCREMENT', 'fast-base')
assert increment in ('fast-base', 'storage-1')
if increment == 'storage-1':
    assert os.environ.get('CI') == 'true', 'Storage compilation is CI-only while local Docker is below the disk floor'
container_floor_kib = 20971520 if continuation else 31457280
assert subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip() == pins['alpenglow']
paths = ['scripts/boot-native.sh', 'system/backends/appliance/scripts/build-kernel-fast.sh', 'scripts/lib/assemble-rootfs.sh']
adapted = {}
for name in paths:
    text = (source / name).read_text()
    if name == paths[2]:
        text = text.replace('root:x:0:0:root:/root:/bin/toybox sh', 'root:x:0:0:root:/root:/bin/sh')
        assert '/root:/bin/toybox sh' not in text
        subprocess.run(['sh', '-n'], input=text, text=True, check=True)
        adapted[name] = text
        continue
    if name == paths[0]:
        line = next(line for line in text.splitlines() if line.startswith('NPROC='))
        text = text.replace(line, 'NPROC="2"', 1)
        # Same header-order correction used in the measured toybox build.
        text = text.replace('make -j$(nproc) LDFLAGS="-static"', 'CPUS=2 make -j2 CFLAGS="-D_GNU_SOURCE -include string.h" LDFLAGS="-static"')
    text = text.replace('tar -xzf /tmp/toybox.tar.gz -C /tmp', 'sha256sum /tmp/toybox.tar.gz > /out/toybox-source.sha256\n    tar -xzf /tmp/toybox.tar.gz -C /tmp')
    text = text.replace('tar -xf /tmp/dinit.tar.xz -C /tmp', 'sha256sum /tmp/dinit.tar.xz > /out/dinit-source.sha256\n    tar -xf /tmp/dinit.tar.xz -C /tmp')
    if increment == 'storage-1' and name == paths[0]:
        text = text.replace('    tar -xzf /tmp/toybox.tar.gz -C /tmp', '    tar -xzf /tmp/toybox.tar.gz -C /tmp\n    cp /tmp/toybox-*/LICENSE /out/toybox-LICENSE')
        text = text.replace('    tar -xf /tmp/dinit.tar.xz -C /tmp', '    tar -xf /tmp/dinit.tar.xz -C /tmp\n    cp /tmp/dinit-*/LICENSE /out/dinit-LICENSE')
    if name == paths[1]:
        kernel_check = '      echo "' + pins['fast_native']['kernel_sha256'] + '  k.tar.xz" > kernel-download.sha256\n      sha256sum -c kernel-download.sha256\n'
        text = text.replace('      tar -xf k.tar.xz', kernel_check + '      tar -xf k.tar.xz')
    text = text.replace('cpio -o -H newc', 'cpio -o -H newc -R 0:0')
    text = text.replace('$(nproc)', '2').replace('zstd -6 -T0', 'zstd -6 -T2')
    text = text.replace('docker run --rm --platform', 'docker run --rm --cpus=2 --pids-limit=512 --memory=2g --label alpenglow-rescue.build=task15-fast-20261001 --platform')
    text = text.replace('alpine:3.21 sh', 'alpine:3.21@' + pins['fast_toolchain']['alpine_3_21'] + ' sh')
    text = text.replace('debian:bookworm-slim sh', 'debian:bookworm-slim@' + pins['fast_toolchain']['debian_bookworm_slim'] + ' sh')
    # Every container checks both its writable layer and task artifact mount.
    container_guard = r"""    for rescue_path in / /out; do
      [ "$(df -Pk "$rescue_path" | awk "END {print \$4}")" -ge 31457280 ] || exit 1
    done
"""
    container_guard = container_guard.replace('31457280', str(container_floor_kib))
    text = text.replace("sh -c '\n", "sh -c '\n" + container_guard)
    assert '$(nproc)' not in text and '-T0' not in text
    assert '--cpus=2' in text and str(container_floor_kib) in text
    subprocess.run(['sh', '-n'], input=text, text=True, check=True)
    original = (source / name).read_text()
    if name == paths[0]:
        for begin, end in [('if [ "${FAST}" = "1" ]; then', 'for arg in "$@"; do'), ('# Compose rootfs', '# Oil (native package manager)')]:
            assert original[original.index(begin):original.index(end)] == text[text.index(begin):text.index(end)]
        assert 'KERNEL_PROFILE=fast sh' in text
        assert 'ZIG_INIT=1' in text
        assert 'lz4 -l -9 -c' in text
    else:
        assert 'CONFIG_INITRAMFS_SOURCE "/out/initramfs.cpio.lz4"' in text
        assert 'INITRAMFS_COMPRESSION_LZ4' in text
        begin = '# Profile-specific trimming'
        end = 'make ARCH=x86_64 olddefconfig'
        assert original[original.index(begin):original.index(end, original.index(begin))] == text[text.index(begin):text.index(end, text.index(begin))]
    # Add the rescue delta only after checking preservation of upstream FAST
    # architecture and its original trimming span above.
    if increment == 'storage-1' and name == paths[0]:
        anchor = '# Build initramfs\n'
        assert text.count(anchor) == 1
        hook = '''# First rescue payload, before the native embedded-LZ4 build.
docker run --rm --cpus=2 --pids-limit=512 --memory=2g \\
  --label alpenglow-rescue.build=task15-fast-20261001 --platform linux/amd64 \\
  -v "${OUT_DIR}:/out" -v "${ROOT_DIR}/rescue-recipe:/recipe:ro" \\
  ''' + pins['alpine_image'] + ''' sh /recipe/scripts/add-storage-payload.sh
'''
        text = text.replace(anchor, hook + anchor)
    if increment == 'storage-1' and name == paths[1]:
        anchor = '    echo "→ compiling bzImage (this can take several minutes)..."'
        assert text.count(anchor) == 1
        hook = '''    # Restore storage/UEFI after every FAST-only disable, then resolve.
    ./scripts/kconfig/merge_config.sh -m .config /kcfg/storage-x86_64.fragment
    make -j2 ARCH=x86_64 olddefconfig >/dev/null
    while IFS= read -r rescue_setting; do
      case "$rescue_setting" in CONFIG_*=*) grep -qx "$rescue_setting" .config || { echo "Unresolved: $rescue_setting"; exit 1; };; esac
    done < /kcfg/storage-x86_64.fragment
    cp .config /out/storage-evidence/kernel.config
'''
        text = text.replace(anchor, hook + anchor)
    subprocess.run(['sh', '-n'], input=text, text=True, check=True)
    adapted[name] = text

if args.check:
    print('pinned Alpenglow fast recipe adaptation: passed (no files or build created)')
else:
    minimum_gib = 21 if continuation else (31.5 if os.environ.get('ALPENGLOW_BOUNDED_FAST') == '1' else 36)
    if shutil.disk_usage(root).free < minimum_gib * 1024**3:
        raise SystemExit('Stop: need 30 GiB floor plus 6 GiB build allowance')
    dest = root / 'build/fast-source'
    # Reuse only our own source export; never delete another checkout or WIP.
    if dest.exists():
        assert (dest / '.source-pin').read_text().strip() == pins['alpenglow']
    else:
        dest.mkdir(parents=True)
        process = subprocess.Popen(['git', '-C', str(source), 'archive', pins['alpenglow']], stdout=subprocess.PIPE)
        with tarfile.open(fileobj=process.stdout, mode='r|') as archive:
            archive.extractall(dest, filter='data')
        if process.wait() != 0:
            raise SystemExit('source export failed')
    (dest / '.source-pin').write_text(pins['alpenglow'] + '\n')
    for name, text in adapted.items():
        (dest / name).write_text(text)
    if increment == 'storage-1':
        recipe = dest / 'rescue-recipe'
        (recipe / 'scripts').mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / 'packages-storage.txt', recipe / 'packages-storage.txt')
        for name in ('add-storage-payload.sh', 'smoke-storage.sh'):
            shutil.copyfile(root / 'scripts' / name, recipe / 'scripts' / name)
        shutil.copyfile(root / 'kernel/storage-x86_64.fragment', dest / 'system/backends/appliance/kernel/storage-x86_64.fragment')
    (root / 'build/evidence').mkdir(parents=True, exist_ok=True)
    (root / 'build/evidence/fast-recipe-adaptation.json').write_text(json.dumps({
        'source': pins['alpenglow'],
        'purpose': increment,
        'container_floor_kib': container_floor_kib,
        'adapted_file_sha256': {name:hashlib.sha256(text.encode()).hexdigest() for name,text in adapted.items()},
    }, indent=2) + '\n')
    print(dest)
