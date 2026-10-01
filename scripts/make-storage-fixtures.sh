#!/bin/sh
# CI regular files only. No host block devices, loop mappings or mounts.
set -eu
test "${CI:-}" = true
cd "$(dirname "$0")/.."
mkdir -p build/fixtures/data
printf '%s\n' ALPENGLOW_SYNTHETIC_RESCUE_CONTENT > build/fixtures/data/marker.txt
truncate -s 32M build/fixtures/ext4.img
mkfs.ext4 -q -F -L AR_EXT4 build/fixtures/ext4.img
debugfs -w -R 'write build/fixtures/data/marker.txt marker.txt' build/fixtures/ext4.img
truncate -s 256M build/fixtures/btrfs.img
mkfs.btrfs -q -f -L AR_BTRFS -r build/fixtures/data build/fixtures/btrfs.img
truncate -s 384M build/fixtures/xfs.img
mkfs.xfs -q -f -L AR_XFS build/fixtures/xfs.img
truncate -s 32M build/fixtures/fat.img
mkfs.fat -F 16 -n AR_FAT build/fixtures/fat.img
truncate -s 32M build/fixtures/exfat.img
mkfs.exfat -L AR_EXFAT build/fixtures/exfat.img
truncate -s 64M build/fixtures/ntfs.img
mkfs.ntfs -q -F -L AR_NTFS build/fixtures/ntfs.img
truncate -s 64M build/fixtures/luks.img
printf '%s\n' PUBLIC_SYNTHETIC_FIXTURE_KEY_NOT_A_SECRET > build/fixtures/fixture.key
cryptsetup luksFormat --batch-mode --type luks2 --pbkdf pbkdf2 --iter-time 100 \
  --label AR_LUKS --key-file build/fixtures/fixture.key build/fixtures/luks.img
python3 - <<'PY'
import hashlib,json
from pathlib import Path
files={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in Path('build/fixtures').glob('*.img')}
Path('build/evidence/fixture-manifest.json').write_text(json.dumps({'scope':'synthetic regular CI files; no host mounts; QEMU backend read-only','files':files},indent=2)+'\n')
PY
