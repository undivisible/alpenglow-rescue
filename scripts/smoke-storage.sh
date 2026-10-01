#!/bin/sh
# Explicit test only: refuses to touch disks unless the fixture VM flag exists.
set -eu
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin TERM=vt100
case " $(cat /proc/cmdline) " in *' alpenglow.test-fixtures=1 '*) ;; *) echo 'Synthetic fixture VM required' >&2; exit 1;; esac
test "$(uname -r)" = 7.1.3
test "$(cat /proc/1/comm)" = dinit
for tool in lsblk blkid mount umount chroot e2fsck btrfs xfs_repair fsck.fat fsck.exfat ntfsfix \
  cryptsetup lvm mdadm parted sgdisk modprobe ddrescue testdisk smartctl nvme tmux oksh; do
  command -v "$tool" >/dev/null
done
lsblk --version
cryptsetup --version
lvm version
mdadm --version
ddrescue --version
testdisk /version
smartctl --version
nvme version
tmux -V
# Exercise tmux on a guest PTY; nothing listens on the network.
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts
tmux -L rescue-smoke new-session -d 'sleep 30'
tmux -L rescue-smoke list-sessions
tmux -L rescue-smoke kill-server
mkdir -p /mnt/fixture
for entry in 'EXT4 ext4' 'BTRFS btrfs' 'XFS xfs' 'FAT vfat' 'EXFAT exfat' 'NTFS ntfs3'; do
  set -- $entry; label="AR_$1"; fs=$2
  dev=$(blkid -L "$label")
  test -b "$dev"
  # NVMe/ATA emulation may not advertise the read-only backend to Linux. Set
  # the guest block-layer flag too; this ioctl changes no fixture bytes.
  blockdev --setro "$dev"
  # QEMU backend and guest device must both be read-only before diagnostics.
  test "$(blockdev --getro "$dev")" = 1
  case "$fs" in
    ext4) e2fsck -f -n "$dev"; opts=ro,noload ;;
    btrfs) btrfs check --readonly "$dev"; opts=ro,nologreplay ;;
    xfs) xfs_repair -n "$dev"; opts=ro,norecovery ;;
    vfat) fsck.fat -n "$dev"; opts=ro ;;
    exfat) fsck.exfat -n "$dev"; opts=ro ;;
    ntfs3) ntfsfix -n "$dev"; opts=ro ;;
  esac
  mount -t "$fs" -o "$opts" "$dev" /mnt/fixture
  case "$fs" in ext4|btrfs) grep -qx ALPENGLOW_SYNTHETIC_RESCUE_CONTENT /mnt/fixture/marker.txt;; esac
  umount /mnt/fixture
  printf 'RESCUE_FIXTURE_PASS %s %s\n' "$label" "$dev"
done
dev=$(blkid -L AR_LUKS)
test "$(blockdev --getro "$dev")" = 1
cryptsetup luksDump "$dev"
cryptsetup open --readonly --disable-keyring --key-file /usr/share/alpenglow-rescue/fixture.key "$dev" rescue-fixture
test "$(blockdev --getro /dev/mapper/rescue-fixture)" = 1
cryptsetup close rescue-fixture
printf 'RESCUE_FIXTURE_PASS AR_LUKS %s\n' "$dev"
printf '%s%s\n' RESCUE_STORAGE_ READY_OK
