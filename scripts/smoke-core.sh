#!/bin/sh
# Only help/version launches; safe with a staged read-only root and no devices.
set -eu
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
partial=0
for cmd in tmux lsblk blkid cryptsetup btrfs mdadm lvm chroot ddrescue testdisk smartctl nvme fsarchiver partclone.dd iwctl; do
  command -v "$cmd"
done
cryptsetup --version
btrfs version
ddrescue --version
testdisk /version
smartctl --version
nvme version
mdadm --version
if lvm help; then :; else
  status=$?
  echo "LVM_HELP_STATUS=$status (staged root has no mounted /proc)"
  partial=1
fi
chroot --help
tmux -V
dinit --version
/bin/oksh -c 'echo OKSH_LAUNCH_OK'
if [ "$partial" -eq 0 ]; then echo CORE_CLI_SMOKE_OK; else echo CORE_CLI_SMOKE_PARTIAL; fi
