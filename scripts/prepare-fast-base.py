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
    text = text.replace("sh -c '\n", "sh -c '\n" + container_guard)
    assert '$(nproc)' not in text and '-T0' not in text
    assert '--cpus=2' in text and '31457280' in text
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
    adapted[name] = text

if args.check:
    print('pinned Alpenglow fast recipe adaptation: passed (no files or build created)')
else:
    if shutil.disk_usage(root).free < (31.5 if os.environ.get('ALPENGLOW_BOUNDED_FAST') == '1' else 36) * 1024**3:
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
    (root / 'build/evidence').mkdir(parents=True, exist_ok=True)
    (root / 'build/evidence/fast-recipe-adaptation.json').write_text(json.dumps({
        'source': pins['alpenglow'],
        'purpose': 'upstream fast base validation; rescue integration pending',
        'adapted_file_sha256': {name:hashlib.sha256(text.encode()).hexdigest() for name,text in adapted.items()},
    }, indent=2) + '\n')
    print(dest)
