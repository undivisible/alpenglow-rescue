# Native storage increment 1

This bounded increment preserves Alpenglow at
`2214bc159355522bbebc61e8e90ca78933a8e1ac`: Linux 7.1.3 with embedded LZ4,
Zig init, static Toybox and dinit. Signed Alpine 3.23 packages add storage
tools before compression. The kernel fragment restores built-in SATA, SCSI,
NVMe, VirtIO and USB controllers; ext4/Btrfs/XFS/FAT/exFAT/NTFS3/FUSE;
MD/device mapper/cryptography, VT/HID and EFI stub support. Every requested
setting must survive actual Kconfig resolution. No Alpine kernel is imported.

The manual GitHub workflow selects `storage-1`, uses two build jobs/CPUs and
retains the existing 20 GiB floor/21 GiB early stop/4 GiB allocation cap.
Local heavy jobs remain stopped. Only ordinary workspace files enter containers
or QEMU; no host block devices, privileged containers, target host mounts,
USB flashing, credentials, auth services or remote shells are involved.
Default boot services remain the local serial getty and filesystem mounts.

Acceptance is a fresh QEMU process reaching an interactive shell, then passing
`rescue-smoke-storage`: tools available; native PID 1/kernel; tmux session;
read-only inspection/check/mount of six filesystem fixtures; known marker
content read from ext4/Btrfs; and a read-only LUKS mapping using a clearly public
synthetic fixture key. It refuses unless the fixture test boot flag is present.
All fixture block backends are read-only, and guest block-device read-only
status must also pass. LVM/RAID recovery and actual repair are not established
by CLI version checks. This is partial storage test completion, not complete
rescue or network readiness. BIOS and UEFI are measured separately, three cold
processes each. CI x86 TCG results do not share the ARM host baseline conditions.

The previous proof ISO is independently hash-checked and retested under CI UEFI
with serial logs and QMP screens. Its prior UEFI failure remains evidence;
restoring EFI support alone is not claimed to prove the earlier failure cause.

Recipe/license review: this uses the existing packaging pipeline and package
dependency solver; it does not replace Alpenglow architecture to meet size.
The exact APK database, versions, checksums, licenses, origin/build commits,
source recipe links and resolved kernel config accompany the artifact. Native
license texts and package metadata are included in the ISO. Package scripts
are disabled and Alpine init/auth configuration is excluded. Original Alpenglow
working copies/submodule remain untouched. Official versioned indexes are
resolved at build time; source archiving and complete distribution review
remain requirements before a final public release. No proprietary AI client
is included in this increment.

Remaining required increments include networking and WiFi with audited firmware,
broader physical hardware/console coverage, Oil, AI client launch checks,
chroot/mount and phone helpers, and recovery/diagnostic gaps in the feature
matrix. No complete-equivalence, under-500-MB or four-times-faster claim follows
from the size or timing of this partial image.
