# Native fast rescue capability and disk plan

## Boot architecture audit

This plan was checked against pinned Alpenglow
`2214bc159355522bbebc61e8e90ca78933a8e1ac`, not against the old hybrid name.
The base validation route runs `boot-native.sh` with the potato/FAST settings,
source-built static toybox/dinit, compiled `system/init/init.zig`, LZ4 initramfs,
and custom Linux 7.1.3 with that initramfs embedded by `build-kernel-fast.sh`.
The rootfs compose span, FAST control span and fast kernel trimming span are
checked byte-for-byte against upstream by the adapter's lightweight checks.
Only orchestration limits, toolchain pins, resource guards and the documented
toybox header-order fix differ. Alpine/Debian are toolchains, not a populated
boot root. Source export is 17,767,268 logical tracked-file bytes.

The rescue delta in `kernel/rescue-x86_64.fragment` is **resolved against Linux 7.1.3, not compiled**. It must be merged after upstream's final FAST disables and
resolved with 7.1.3 olddefconfig; applying it only before those disables would
silently lose essential drivers again. Build matching modules from the same
custom kernel. Never copy Alpine LTS `.ko` files into it. Retain the embedded
lean Alpenglow boot root and Zig-to-dinit sequence; integrate an explicit,
read-only rescue payload mount with init/service ordering. Payload integration
is unimplemented. It must not introduce target-disk scanning/mounting or
mandatory persistent state. Both BIOS and UEFI need independent boot tests.

## Minimum usable rescue capability

Costs below are exact **historical APK installed bytes for named direct
packages**, before compression and excluding unlisted/shared dependencies.
They are size proxies, not predictions for a native build. Detailed package
names and costs are in `evidence/rescue-capability-costs.json`. Kernel/module
deltas cannot be assigned exact bytes until the custom kernel is compiled.

| Capability | Required native choices | Direct package bytes / size limit |
| --- | --- | ---: |
| Boot and local console | Embedded LZ4, Zig init, static dinit/toybox; serial plus VT; PS/2 and USB keyboard; oksh/tmux in rescue payload | 2,281,149 proxy; native base size unmeasured |
| Boot medium and block inventory | Built-in PCI, loop, ISO9660, SCSI disk/CD, GPT/MBR; util-linux inventory/partition helpers | 2,376,017 proxy; built-in driver delta unmeasured |
| NVMe/SATA/USB storage | Built-in NVMe, AHCI/PIIX, USB xHCI/EHCI/OHCI/UHCI, mass storage/UAS; VirtIO; common SAS/RAID controller modules | Included tool rows below; matching kernel/module bytes unmeasured |
| LUKS/LVM/MD RAID | Device mapper, dm-crypt/AES/XTS, snapshots/thin volumes, MD linear/RAID0/1/10/456 | 6,556,549 proxy; additional kernel crypto/module bytes unmeasured |
| Filesystem access and checks | ext4 built-in; Btrfs, XFS, FAT, exFAT, NTFS3/FUSE modules and userspace checks; SquashFS/EROFS for read-only payload | 4,671,241 proxy; native modules unmeasured |
| Recovery and hardware diagnostics | ddrescue, TestDisk, SMART, NVMe, fsarchiver, partclone, rsync | 6,854,604 proxy |
| Ethernet/network diagnostics | VirtIO/e1000 built-in, Intel e1000e/igb/igc, Realtek r8169, USB tether/Ethernet modules; DHCP, IPv4/IPv6, DNS/TLS and SSH client | Together with Wi-Fi: 22,969,536 proxy |
| Wi-Fi | cfg80211/mac80211; Intel, Atheros, Broadcom, Realtek, MediaTek families; iwd/iwctl/dbus | Kernel and matching firmware coverage unverified |
| Firmware | Bare base has no firmware; rescue payload inclusion must follow retained x86_64 drivers' firmware references and a device-family audit. All historical firmware remains in the preserved old ISO | 762,089,168 installed bytes; compressed cost unmeasured |
| Backup conveniences | rclone/restic/borg retained in the complete payload for upstream comparison; they need not be early boot services | 155,273,849 proxy; no removal authorized by a size target |
| AI clients and Oil | All three pinned clients and Oil in complete payload; executable/version smoke, no auth | Absent currently; native executable/archive/compile costs unmeasured |
| BIOS/UEFI | Limine packaging, EFI/EFI_STUB restored for rescue; serial/VT on both | Boot files and custom kernel delta unmeasured |

The bare fast base is a boot validation step, not this usable rescue feature
set. The fragment does not prove broad hardware coverage: vendor/device
selection still needs an effective-config/module audit. Apple T2 and other
Omarchy kernel patches are not present in the mainline fast source; do not
claim that hardware coverage. bcachefs repair tools, clonezilla orchestration,
foremost, sbctl, snapper, kmscon/impala and upstream helper workflows remain
explicit gaps. No rescue capability was removed in the host disk cleanup.
No under-500-MB or quarter-time result can be inferred from these costs.

## Temporary space allowances

These are conservative **planning budgets**, not observed complete-build peaks.
The specifically authorized native fast-base run is now in progress with a
30 GiB hard floor, 31.5 GiB early stop and a 6 GiB total budget. The full
rescue build is not authorized by this exception. An existing unrelated Linux 7.1.0 tree was read
only to calibrate scale: 2,134,892 KiB allocated, including 279,953,408 bytes
of regular object/build metadata. It was not reused or modified and is not
the pinned 7.1.3 source. The official [kernel archive listing](https://cdn.kernel.org/pub/linux/kernel/v7.x/)
reports the 7.1.3 xz download as about 151 MB. The exact 158,335,040-byte
archive was downloaded and verified against the separately fetched official
SHA-256 list. See `evidence/rescue-config-7.1.3.json`. All 141 requested
settings now resolve after adding BLK_DEV and MISC_FILESYSTEMS menu switches.
This validates configuration dependencies, not compile or hardware operation.

Fast-base incremental allowance:

| Peak component | MiB allowance |
| --- | ---: |
| Extracted Linux source | 2,304 |
| Kernel objects and intermediates | 1,280 |
| Container toolchains and writable layers | 1,536 |
| Pinned source export and small tool sources | 256 |
| Download archives | 256 |
| Kernel and LZ4 root artifacts | 64 |
| Contingency | 448 |
| **Total** | **6,144 (6 GiB)** |

A complete rescue build gets a separate **16 GiB** allowance: the 6 GiB base
plus 2 GiB rescue staging, 1 GiB client/package archives, 2.5 GiB Oil Cargo
registry/target, 2 GiB immutable payload/ISO outputs, and 2.5 GiB overlap and
contingency. Native driver modules and the actual client sizes remain uncertain;
measure each phase before spending the next phase's allowance. Existing ISOs
and evidence are already included in current volume usage and stay preserved.

The original fast-base entry plan was 46 GiB. For this explicitly authorized
run, initial entry is **36 GiB available**: 30 GiB floor plus 6 GiB allowance.
Subsequent phases use the same monitored total budget, not fresh allowances. Complete rescue planning requires **56 GiB**.
Host and container free-space checks are required, with two jobs/CPUs maximum.
A future build also needs ongoing monitoring during compilation: stop on
unexpected growth before continuing phases. No unbounded build is authorized
merely because the entry gate passes. Do not enlarge or clean unrelated Docker
storage or borrow Twenify's reserve.

Exact availability and additional bytes needed at this checkpoint are in
`evidence/disk-budget.json`. At its measurement, available space was
43,417,600,000 bytes; the fast-base allowance required **5,974,523,904 more
bytes (5.56 GiB)**, and complete rescue required **16,711,942,144 more bytes
(15.56 GiB)**. Free space fluctuates with shared volume activity, so re-read it
before work. Those original 40 GiB-reserve numbers are historical. The later 30 GiB-floor
exception allows only the bounded native fast-base build and its boot proof.
Oil/client downloads and the complete rescue staging/packaging remain deferred.

## Published README and needed action

The GitHub README at `48d7e10c069e0d23a38fb6ef78ca025f53aa99e4` was fetched and
matched to the local committed file. It correctly states partial core size,
AI/Oil absence, unestablished readiness, APK bootstrap and unachieved targets.
It does not explicitly distinguish Alpine LTS/shell init from custom FAST
kernel/Zig init; the local correction does. See
`evidence/published-readme-check.json`.

The user later directly approved corrected source upload and public visibility.
History/source preflight found no secret-pattern matches or binaries; commit
author metadata matches the already-public pinned Alpenglow commit. An
unnecessary absolute workspace path was removed from unpublished history.
Source publication does not include ISOs or a benchmark announcement.
