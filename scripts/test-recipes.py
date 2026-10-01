#!/usr/bin/env python3
"""Small safety/contract check for the build recipe, without network or auth."""
import ast
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
pins = json.loads((root / 'pins.json').read_text())
assert subprocess.check_output(['git', '-C', str(root / 'vendor/alpenglow'), 'rev-parse', 'HEAD'], text=True).strip() == pins['alpenglow']
for path in [*root.glob('scripts/*.sh'), *root.glob('overlay/usr/local/bin/*')]:
    subprocess.run(['sh', '-n', str(path)], check=True)
for path in root.glob('scripts/*.py'):
    ast.parse(path.read_text())
packages = (root / 'packages.txt').read_text().splitlines()
for essential in ('linux-lts', 'linux-firmware', 'btrfs-progs', 'cryptsetup', 'lvm2', 'mdadm', 'ddrescue', 'testdisk', 'iwd', 'tmux'):
    assert essential in packages, essential
build = (root / 'scripts/build-hybrid.sh').read_text()
assert '--cpus=2' in build and '--privileged' not in build
assert '41943040' in build
assert 'build-fast-base.sh' in (root / 'scripts/build.sh').read_text()
subprocess.run(['python3', str(root / 'scripts/prepare-fast-base.py'), '--check'], check=True)
pack = (root / 'scripts/pack.sh').read_text()
assert '-T2' in pack and 'bios-install' in pack and '--efi-boot' in pack
print('recipe checks: passed')
