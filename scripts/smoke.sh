#!/bin/sh
# Run only in an ephemeral container/VM, never against host disks.
set -eu
for cmd in tmux lsblk blkid cryptsetup btrfs mdadm lvm chroot ddrescue testdisk smartctl nvme fsarchiver partclone.dd iwctl; do
  command -v "$cmd"
done
cryptsetup --version
btrfs version
ddrescue --version | head -1
testdisk /version
smartctl --version | head -1
nvme version
mdadm --version
lvm help >/dev/null
chroot --help | head -1
tmux -V
oil --version
claude --version
codex --version
opencode --version
blkid -p /usr/share/alpenglow-rescue/fixtures/ext4.img
e2fsck -fn /usr/share/alpenglow-rescue/fixtures/ext4.img
btrfs check --readonly /usr/share/alpenglow-rescue/fixtures/btrfs.img
printf 'SMOKE_OK\n'
