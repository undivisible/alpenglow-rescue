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
# The Ubuntu-generated CI fixture failed the guest's Alpine 6.17 free-space-tree
# check. Use the same signed Alpine release as the payload,
# and reject an invalid regular-file fixture before booting any guest.
alpine_ref=alpine@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0
docker pull --platform linux/amd64 "$alpine_ref" >/dev/null
docker run --rm --pull=never --platform linux/amd64 --cpus=1 --memory=512m --pids-limit=128 \
  --mount "type=bind,source=$PWD/build/fixtures,target=/fixtures" -w /fixtures \
  "$alpine_ref" sh -ec '
    apk add --no-cache btrfs-progs >/dev/null
    btrfs --version
    mkfs.btrfs -q -f -L AR_BTRFS -r data btrfs.img
    btrfs check --readonly btrfs.img
  '
truncate -s 384M build/fixtures/xfs.img
# QEMU ide-hd rejects read-only backends. A SATA CD fixture preserves the
# read-only invariant; its filesystem sector size must match CD sectors.
mkfs.xfs -q -f -s size=2048 -L AR_XFS build/fixtures/xfs.img
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
luajit scripts/image-evidence.lua fixtures
