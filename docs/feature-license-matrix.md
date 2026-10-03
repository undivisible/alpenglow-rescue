# Candidate capabilities and licenses

Alpenglow: `2214bc159355522bbebc61e8e90ca78933a8e1ac`, MPL-2.0.
Omarchy Rescue README: `ae903cd63a43aa609a7b5493b45647aa53a7cf73`, MIT.
Official baseline: `v2026.09.30.1`, source
`2c52ef26fb2a5b6d2f9605dd61bef96c237e6494`. The release predates the explicit
LICENSE file at current main; its current MIT notice is preserved in `licenses/`.
No upstream helper code is copied. Upstream estimates ~1.8 GB rescue-only and
~6.6 GB installer; the separately verified release measures 1,954,578,432 bytes.

Current image: native storage-1a, 33,806,336 bytes, compiled base source
`a05898d`, correction source `f9ade38`. It is a **partially validated candidate**,
not a functional equivalent. Three BIOS and three UEFI cold boots passed the
strict synthetic storage suite. Earlier green timings from a faulty probe were
revoked. [Current measurements and raw evidence](storage-1a-validated.md).

| Capability | Omarchy Rescue | Current native candidate / evidence | License / remaining work |
| --- | --- | --- | --- |
| Kernel and storage drivers | Arch/Omarchy kernel with broad drivers | Custom Linux 7.1.3; all 106 requested storage/EFI settings compiled; builtin SATA/SCSI/NVMe/VirtIO/USB | GPL-2.0-only; no Alpine kernel; full physical-device coverage unverified |
| Network/GPU drivers and firmware | Broad kernel/firmware | No audited broad network/WiFi/GPU/firmware restoration yet | Per-file firmware licenses need review; essential coverage must be retained before equivalence |
| Init and libc | systemd/glibc | Native Zig init, dinit 0.19.2, musl; PID1 and kernel checked in guest | MPL-2.0 / Apache-2.0 / MIT; native core unchanged by payload |
| Shell and package tools | Omarchy shell/pacman | Toybox 0.8.11, oksh 7.8; interactive BIOS/UEFI command response; signed APK build bootstrap | 0BSD; Alpine oksh metadata Public-Domain; Oil absent, runtime updates unproven |
| Console and tmux | kmscon plus fallback, tmux | Serial console boots; VT/HID compiled; tmux 3.6 starts, lists and closes a guest session in six cold runs | tmux ISC; kmscon/physical VT integration missing |
| Ethernet and WiFi | Automatic Ethernet, iwd/impala | No networking in current candidate tests; no iwd/DHCP integration | Required increment; physical WiFi and firmware cannot be inferred from VM results |
| ext4/Btrfs/XFS/FAT/exFAT/NTFS | Rescue filesystem tools | All six synthetic files passed non-writing checks and read-only mounts in six cold runs; ext4/Btrfs marker content read | e2fsprogs mixed GPL/LGPL/BSD/MIT; Btrfs/exFAT GPL-2.0-or-later; XFS LGPL-2.1-or-later; dosfstools GPL-3.0-or-later; NTFS GPL-2.0-only |
| LUKS, LVM and MD RAID | cryptsetup/lvm2/mdadm | Synthetic LUKS opened and closed read-only in six runs; LVM/RAID tools launch but real recovery is untested | cryptsetup GPL-2.0-or-later with OpenSSL exception; LVM mixed GPL/LGPL/BSD; mdadm GPL-2.0-only |
| Recovery and diagnostics | ddrescue/TestDisk/SMART/NVMe and more | ddrescue 1.29.1, TestDisk 7.2, SMART 7.5, nvme-cli 2.16 staged; version/help launches observed | GPL-3.0-or-later ddrescue; GPL-2.0-or-later others; real recovery untested |
| Partition/module tools | releng tools | util-linux 2.41.6, parted 3.6, gptfdisk/sgdisk 1.0.10, kmod 34.2 staged | Mixed util-linux licenses in exact inventory; parted GPL-3.0-or-later; GPT/kmod GPL-2.0-or-later |
| Chroot and mount workflow | arch-chroot and fstab/subvolume helper | Real Toybox chroot command and read-only fixture mounts pass in six cold runs | Toybox 0BSD; util-linux mixed; automatic mount/subvolume helpers missing |
| Claude Code | Bundled | Absent | Proprietary terms; official musl executable/help test and redistribution review needed; no auth enrollment |
| Codex | Bundled | Absent | Apache-2.0; official native executable launch needed; no auth enrollment |
| OpenCode | Bundled | Absent | MIT; official baseline-musl executable launch needed; no auth enrollment |
| Phone login/root sharing | QR/paste helper and opt-in ttyd | Absent; no remote root service activated | Helper integration and licenses pending; tests require no credentials or activation |
| Installer | Optional full installer | Rescue-only scope; no installer | No installer equivalence claimed |
| Presentation and other tools | Fonts/starship/zoxide/eza/bat and extra TUIs | Mostly absent | kmscon, impala, foremost, clonezilla orchestration, snapper, bcachefs repair, sbctl and guest Limine repair still missing |
| BIOS and UEFI | Both | Three cold strict synthetic storage passes in each mode; BIOS 10.445 s and UEFI 13.126 s median | Limine 12.4.0 BSD-2-Clause; physical machines and full rescue readiness untested |

The signed solver resolved 87 APK package records; exact versions, checksums,
licenses, origin/build commits and source recipe links are in
`evidence/storage-1a-validated-20261003/package-license-inventory.json` and its
lockfile. Package scripts were disabled; Alpine init/auth config was excluded.
Staging installed-size proxies are not exact copied-file or compressed costs.
Core license texts plus package metadata accompany the ISO. Complete
corresponding-source and distribution review are still required before final
release. This was a separate source-review pass by the implementing agent,
not an independent reviewer or legal clearance.

Read-only fixtures use VirtIO, NVMe, USB mass storage and SATA CD transport.
The latter avoids QEMU's refusal of readonly IDE hard-disk backends; it proves
no hard-disk repair. The guest helper refuses without its explicit fixture boot
flag and requires QEMU backend plus guest block-layer read-only state. No host
disks, mounts, actual repair, credentials or remote access are involved.

The earlier 347-package/1,014,913,024-byte Alpine-kernel prototype retained
broad firmware but was not Alpenglow's native FAST image. It remains historical
evidence in [measurement-history.md](measurement-history.md), not current scope.
Its large firmware cost does not authorize omitting required firmware from the
complete native rescue product to meet a target.
