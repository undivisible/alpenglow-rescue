# Native storage-1a checkpoint — 2026-10-03

This is a **bootable, partially functional rescue candidate**. The whole ISO is
33,806,336 bytes (32.24 MiB), SHA-256
`a21b7b407df7060d04647e88b2d588a5359d1b2ce7ededd3253344da2b0f5908`.
The [CI run](https://github.com/undivisible/alpenglow-rescue/actions/runs/37150320698)
uploaded it as `native-storage-1a-x86_64` and passed three strict cold BIOS
boots and three strict cold UEFI boots. A local copy, independently hashed after
download, is in `build/candidate-37150320698/` (ignored by Git). The CI artifact
expires 2026-10-17. The small raw evidence below is committed to the source
repository.

## Exact source and contents

| Item | Pin or measured value |
| --- | --- |
| Alpenglow submodule | `2214bc159355522bbebc61e8e90ca78933a8e1ac` |
| Native compiled base | Rescue `a05898d435cacd3ea626ee1b94e060ef3077641f`, [run 37148585459](https://github.com/undivisible/alpenglow-rescue/actions/runs/37148585459) |
| Small correction and embedded probe | Rescue `f9ade38107b08fde6f6a427d3574a0f73366cc65` |
| Whole corrected ISO | 33,806,336 bytes; SHA-256 `a21b7b407df7060d04647e88b2d588a5359d1b2ce7ededd3253344da2b0f5908` |
| Embedded native kernel | 29,795,328 bytes; SHA-256 `04c49ab77e00c57f5a3c70e0384c2beb8e4382a2a55e8cd73fcb4db04f9aee5c` |
| Supplemental initramfs | 18,566 bytes; SHA-256 `3b05a6895e3e26ffcf93184bb3c8d0226f3b821a908a7120eed0791c750abfd0` |
| Signed storage packages | 87 Alpine v3.23 package records; 38,939,894 package-reported installed bytes; no missing license metadata |

The corrected ISO reuses the exact native Linux 7.1.3 kernel, embedded LZ4
root, Zig init, static Toybox and dinit from the base build. The extra gzip
initramfs supplies the POSIX oksh shell link, ncurses terminfo and the embedded
storage probe. `sgdisk` is installed as its own signed Alpine package, alongside
`gptfdisk`. The package versions, source-recipe commits and licenses, resolved
kernel config, native-core hashes and manifest are in
[`evidence/storage-1a-validated-20261003/`](../evidence/storage-1a-validated-20261003/).
Package installed bytes are metadata, not the compressed ISO cost or proof of
complete redistribution compliance. A complete corresponding-source and
distribution audit remains necessary before a final binary release.

## Strict cold-boot method and results

The timer starts immediately before each fresh `qemu-system-x86_64` process.
The endpoint is the guest's final `RESCUE_STORAGE_READY_OK` serial marker after
all seven fixture passes, a live tmux session, and `STORAGE_SMOKE_EXIT=0`. A
login prompt or shell response is an earlier, separate milestone. Runs used
Ubuntu 24.04 QEMU 8.2.2, q35 TCG, CPU `max`, one vCPU, 4096 MiB, no NIC,
read-only ISO and seven task-owned regular-file block fixtures attached
read-only. UEFI got a fresh variable file per process. No host block device or
actual repair was involved. Firmware, exact command lines, logs and QMP screen
captures are retained in the raw evidence.

| Firmware | Cold run | Interactive base command | Strict storage readiness |
| --- | ---: | ---: | ---: |
| BIOS | 1 | 4.469 s | 10.445 s |
| BIOS | 2 | 4.344 s | 10.461 s |
| BIOS | 3 | 4.367 s | 10.357 s |
| UEFI | 1 | 7.118 s | 13.098 s |
| UEFI | 2 | 7.067 s | 13.126 s |
| UEFI | 3 | 7.138 s | 13.129 s |

Median strict readiness: **10.445 s BIOS; 13.126 s UEFI**. All six raw serial
logs contain exact PASS lines for ext4, Btrfs, XFS, FAT, exFAT, NTFS and LUKS;
tmux PASS, READY and exit 0. The probe checks the native kernel/PID 1, performs
a real Toybox chroot, launches rescue CLIs, checks the guest block-device
read-only state, performs non-writing filesystem diagnostics and read-only
mounts, reads known ext4/Btrfs content, and opens/closes the public synthetic
LUKS fixture read-only. It does not demonstrate real repair or hardware access.

The preceding [external-probe run](https://github.com/undivisible/alpenglow-rescue/actions/runs/37150112020)
passed the same six strict runs against the native base ISO and recorded the
probe SHA-256 `74b28b63ff97eebeea2b609a201c50db24c0603bb8d39e029a8823823d6a6882`.
The later embedded result above is the accepted image measurement. Previous
failed attempts remain in CI: a missing `sgdisk` package, an invalid synthetic
Btrfs free-space tree, and an obsolete standalone `nologreplay` mount option
were corrected without suppressing any fixture check. The Btrfs fixture is
now made and checked with the pinned Alpine toolchain before each VM run.

## Resource and comparison limits

The one-job native base build took 914.75 s. Its retained monitor reported
minimum free host/Docker bytes of 88,121,405,440 / 88,038,674,432 and maximum
additional allocation of 3,207,556,441 bytes, below its 4 GiB cap. The small
ISO correction allocated 72,268 KiB, below its 4 GiB cap. The corrected ISO
was uploaded and independently SHA-256 checked after download.

The checksum-verified official Omarchy Rescue `v2026.09.30.1` release is
1,954,578,432 bytes, SHA-256
`b812a848e93bc5526094a8165fba8564e9211a7e86859faba2fd525b6bcd82f1`.
Its README's roughly 1.8 GB rescue-only and 6.6 GB installer figures are
estimates, separate from those release bytes. This partial candidate is under
500 MB; **a functionally equivalent under-500-MB rescue image has not been
demonstrated**. There are no three matched upstream rescue-readiness runs under
the same CPU, memory, firmware, storage and endpoint, so no fourfold boot claim
is supported. cp.local's ARM-host emulation results are a different platform.

Network and WiFi readiness, firmware and physical driver coverage, graphical
console/kmscon, Oil, Claude Code/Codex/OpenCode executable launch, phone login
helpers, full chroot/mount workflow and real recovery remain open gates. No
authentication enrollment, remote root shell, USB flashing, binary release or
social post is part of this checkpoint. See the
[feature/license matrix](feature-license-matrix.md) for the honest comparison.
