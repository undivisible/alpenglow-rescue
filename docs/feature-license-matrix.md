# Candidate scope and licenses

Alpenglow source: `tschk/alpenglow` at
`2214bc159355522bbebc61e8e90ca78933a8e1ac`, MPL-2.0.
Comparison source: `crmne/omarchy-rescue` main at
`ae903cd63a43aa609a7b5493b45647aa53a7cf73`, MIT (notice in `licenses/`).
Baseline: official `v2026.09.30.1`, source tag commit
`2c52ef26fb2a5b6d2f9605dd61bef96c237e6494`.
Upstream README estimates rescue-only ~1.8 GB, full installer ~6.6 GB.
Those are upstream estimates, not this project's measurements.

| Capability | Upstream | Candidate plan | License / limitation |
| --- | --- | --- | --- |
| Linux kernel, broad storage/network/GPU drivers | Omarchy/Arch kernel | Signed Alpine linux-lts and all linux-firmware APKs | GPL-2.0 kernel; firmware retains per-file redistribution licenses |
| PID 1 and libc | systemd/glibc | Alpenglow dinit/musl initramfs | dinit Apache-2.0; musl MIT |
| Shell and package manager | Omarchy shell/pacman | toybox, oksh, Oil built from pinned Alpenglow | toybox 0BSD; oksh ISC/BSD; Oil MPL-2.0; bootstrap fallback must be disclosed |
| Terminal + tmux | kmscon + kernel fallback | kernel VT/serial + tmux | tmux ISC; kmscon styling initially missing |
| Ethernet and Wi-Fi | automatic Ethernet, impala/iwd | DHCP, iwd/iwctl | GPL/LGPL components; physical Wi-Fi not verified in VM; no impala UI |
| Filesystems, LUKS, RAID, LVM | releng rescue tools | btrfs/cryptsetup/mdadm/lvm2, ext/XFS/FAT/NTFS/exFAT | GPL/LGPL packages; no real repair tests |
| Recovery and hardware diagnostics | ddrescue, testdisk, SMART, NVMe, cloning, forensics | same core tools via signed APK packages | Each package's own license, recorded in package inventory |
| Chroot/mount workflow | arch-chroot + fstab-driven Omarchy helper | util-linux chroot/mount, read-only inventory by default | Automated Omarchy subvolume/fstab mount helper initially missing |
| Claude Code | bundled | pin official linux-x64-musl package, help/version only | Proprietary Anthropic terms; local build only, distribution unresolved |
| Codex | bundled | pin official Linux x64 native package | Apache-2.0; no auth enrollment |
| OpenCode | bundled | pin official x64 baseline-musl package | MIT; no auth enrollment |
| Phone login / root-shell sharing | QR paste helper + opt-in ttyd root session | qrencode/ttyd executables available, never started during tests | GPL components; helper integration initially missing |
| Updates | online pacman | Oil present; APK bootstrap inventory | Oil's registry compatibility must be checked before promising runtime updates |
| Presentation / convenience | starship, zoxide, eza, bat, fonts, extra TUIs | initially absent | Cosmetic and convenience gaps still prevent claiming complete parity |
| Installer | optional full Omarchy installer | rescue only | No installer equivalent claimed |
| BIOS / UEFI | both | Limine ISO packaging reused from Alpenglow | BSD-2-Clause; test separately |

This is a development candidate, not a validated equivalent. `build/` retains
the package database and exact version/license inventory. Every missing package
or failed smoke command must be listed in the measurement report. No binaries
or releases are published without distribution review and verified claims.
